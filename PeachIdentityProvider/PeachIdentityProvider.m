//
//  PeachIdentityProvider.m
//  PeachIdentityProvider
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import "PeachIdentityProvider.h"
#import "UIWindow+Peach.h"
#import "PeachIdentityProviderNavigationController.h"
#import "PeachIdentityProviderWebViewController.h"

#import <objc/runtime.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <libextobjc/libextobjc.h>
#import <FXReachability/FXReachability.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SafariServices/SafariServices.h>

@import UIKit;


static PeachIdentityProvider *_defaultIdentityProvider;
static BOOL _loggingIn;

static NSMutableDictionary<NSString *, NSValue *> *_identityProviders;
static NSDictionary<NSValue *, NSValue *> *_originalImplementations;

static NSString * const PeachIdentityProviderQueryItemName = @"identity_provider";

static NSString *PeachEmailStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".email"];
}

static NSString *PeachSessionTokenStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".sessionToken"];
}

static NSString *PeachProfileStoreKey(void)
{
    return [NSBundle.mainBundle.bundleIdentifier stringByAppendingString:@".account"];
}

static BOOL swizzled_application_openURL_options(id self, SEL _cmd, UIApplication *application, NSURL *URL, NSDictionary<UIApplicationOpenURLOptionsKey,id> *options);

@interface NSObject (PeachIdentityProviderApplicationDelegateHooks)

- (BOOL)peach_default_application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

@interface PeachIdentityProvider() <SFSafariViewControllerDelegate, ASWebAuthenticationPresentationContextProviding>

@property (nonatomic, copy) NSString *identifier;

@property (nonatomic) NSURL *webserviceURL;
@property (nonatomic) NSURL *websiteURL;
@property (nonatomic) PeachIdentityProviderLoginMethod loginMethod;

@property (nonatomic) UICKeyChainStore *keyChainStore;

@property (nonatomic) id authenticationSession; // Must be strong to avoid cancellation. Contains ASWebAuthenticationSession or SFAuthenticationSession (have compatible APIs)

@property (nonatomic, weak) NSURLSessionDataTask *profileRetrievalTask;
@property (nonatomic, weak) UIViewController *profileNavigationController;

@end


__attribute__((constructor)) static void PeachIdentityProviderInit(void)
{
    NSMutableDictionary<NSValue *, NSValue *> *originalImplementations = [NSMutableDictionary dictionary];
    
    // The `-application:openURL:options:` application delegate method must be available at the time the application is
    // instantiated, see https://stackoverflow.com/questions/14696078/runtime-added-applicationopenurl-not-fires.
    unsigned int numberOfClasses = 0;
    Class *classList = objc_copyClassList(&numberOfClasses);
    for (unsigned int i = 0; i < numberOfClasses; ++i) {
        Class cls = classList[i];
        if (class_conformsToProtocol(cls, @protocol(UIApplicationDelegate))) {
            Method method = class_getInstanceMethod(cls, @selector(application:openURL:options:));
            if (! method) {
                method = class_getInstanceMethod(cls, @selector(peach_default_application:openURL:options:));
                class_addMethod(cls, @selector(application:openURL:options:), method_getImplementation(method), method_getTypeEncoding(method));
            }
          
            NSValue *key = [NSValue valueWithNonretainedObject:cls];
            originalImplementations[key] = [NSValue valueWithPointer:method_getImplementation(method)];
            
            class_replaceMethod(cls, @selector(application:openURL:options:), (IMP)swizzled_application_openURL_options, method_getTypeEncoding(method));
        }
    }
    free(classList);
    
    _originalImplementations = [originalImplementations copy];
}




@implementation PeachIdentityProvider


#pragma mark - Versions

+ (NSString *)version
{
    NSBundle *bundle = [NSBundle bundleForClass:[PeachIdentityProvider class]];
    NSString *buildNumber = [bundle objectForInfoDictionaryKey:(__bridge NSString*)kCFBundleVersionKey];
    NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return [NSString stringWithFormat:@"%@-%@", version, buildNumber];
}


#pragma mark Class methods

+ (PeachIdentityProvider *)defaultProvider
{
    return _defaultIdentityProvider;
}

+ (void)setDefaultProvider:(PeachIdentityProvider *)identityProvider
{
    _defaultIdentityProvider = identityProvider;
}

+ (NSString *)applicationURLScheme
{
    static NSString *URLScheme;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        NSArray *bundleURLTypes = NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"];
        NSArray<NSString *> *bundleURLSchemes = bundleURLTypes.firstObject[@"CFBundleURLSchemes"];
        URLScheme = bundleURLSchemes.firstObject;
        if (! URLScheme) {
            NSAssert(!URLScheme, @"No URL scheme declared in your application Info.plist file under the 'CFBundleURLTypes' key. The application must at least contain one item with one scheme to allow a correct authentication workflow.");
        }
    });
    return URLScheme;
}





#pragma mark Object lifecycle

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL loginMethod:(PeachIdentityProviderLoginMethod)loginMethod
{
    if (self = [super init]) {
        self.identifier = NSUUID.UUID.UUIDString;
        
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            _identityProviders = [NSMutableDictionary dictionary];
        });
        _identityProviders[self.identifier] = [NSValue valueWithNonretainedObject:self];
        
        self.webserviceURL = webserviceURL;
        self.websiteURL = websiteURL;
        self.loginMethod = loginMethod;
        
        UICKeyChainStoreProtocolType keyChainStoreProtocolType = [websiteURL.scheme.lowercaseString isEqualToString:@"https"] ? UICKeyChainStoreProtocolTypeHTTPS : UICKeyChainStoreProtocolTypeHTTP;
        self.keyChainStore = [UICKeyChainStore keyChainStoreWithServer:websiteURL protocolType:keyChainStoreProtocolType];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(reachabilityDidChange:)
                                                   name:FXReachabilityStatusDidChangeNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillEnterForeground:)
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];
        
        [self updateAccount];
    }
    return self;
}

- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL
{
    return [self initWithWebserviceURL:webserviceURL websiteURL:websiteURL loginMethod:PeachIdentityProviderLoginMethodDefault];
}

- (void)dealloc
{
    _identityProviders[self.identifier] = nil;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return [self initWithWebserviceURL:[NSURL new] websiteURL:[NSURL new]];
}


#pragma clang diagnostic pop





#pragma mark Callback URL handling

- (BOOL)handleCallbackURL:(NSURL *)callbackURL
{
    if (! [self shouldHandleCallbackURL:callbackURL]) {
        return NO;
    }
    
    BOOL wasLoggedIn = self.loggedIn;
    
    NSString *action = [self queryItemValueFromURL:callbackURL withName:@"action"];
    if ([action isEqualToString:@"unauthorized"]) {
        [self.profileRetrievalTask cancel];
        [self cleanup];
        [self dismissProfileView];
        
        if (wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLogoutNotification
                                                                object:self
                                                              userInfo:@{ PeachServiceUnauthorizedKey : @YES }];
        }
        return YES;
    }
    else if ([action isEqualToString:@"log_out"]) {
        [self.profileRetrievalTask cancel];
        [self cleanup];
        [self dismissProfileView];
        
        if (wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLogoutNotification
                                                                object:self
                                                              userInfo:nil];
        }
        return YES;
    }
    else if ([action isEqualToString:@"account_deleted"]) {
        [self.profileRetrievalTask cancel];
        [self cleanup];
        [self dismissProfileView];
        
        if (wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLogoutNotification
                                                                object:self
                                                              userInfo:@{ PeachServiceDeletedKey : @YES }];
        }
        return YES;
    }
    
    NSString *sessionToken = [self queryItemValueFromURL:callbackURL withName:@"token"];
    if (sessionToken) {
        self.sessionToken = sessionToken;
        
        if (! wasLoggedIn) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLoginNotification
                                                                object:self
                                                              userInfo:nil];
        }
        [self updateAccount];
        
        if (self.authenticationSession) {
            self.authenticationSession = nil;
        }
        else {
            UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.peachTopViewController;
            [topViewController dismissViewControllerAnimated:YES completion:^{
                _loggingIn = NO;
            }];
        }
        return YES;
    }
    
    return NO;
}




#pragma mark Getters and setters

- (BOOL)isLoggedIn
{
    return (self.sessionToken != nil);
}

- (NSString *)emailAddress
{
    return [self.keyChainStore stringForKey:PeachEmailStoreKey()];
}

- (void)setEmailAddress:(NSString *)emailAddress
{
    [self.keyChainStore setString:emailAddress forKey:PeachEmailStoreKey()];
}

- (PeachProfile *)profile
{
    NSData *profileData = [self.keyChainStore dataForKey:PeachProfileStoreKey()];
    return profileData ? [NSKeyedUnarchiver unarchiveObjectWithData:profileData] : nil;
}

- (void)setProfile:(PeachProfile *)profile
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[PeachPreviousProfileKey] = self.profile;
    
    NSData *profileData = profile ? [NSKeyedArchiver archivedDataWithRootObject:profile] : nil;
    [self.keyChainStore setData:profileData forKey:PeachProfileStoreKey()];
    userInfo[PeachProfileKey] = profile;
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
        [[NSNotificationCenter defaultCenter] postNotificationName:PeachDidUpdateProfileNotification
                                                            object:self
                                                          userInfo:[userInfo copy]];
    });
}

- (NSString *)sessionToken
{
    return [self.keyChainStore stringForKey:PeachSessionTokenStoreKey()];
}

- (void)setSessionToken:(NSString *)sessionToken
{
    [self.keyChainStore setString:sessionToken forKey:PeachSessionTokenStoreKey()];
}






#pragma mark URL handling

- (NSURL *)redirectURL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.webserviceURL resolvingAgainstBaseURL:NO];
    URLComponents.scheme = [PeachIdentityProvider applicationURLScheme];
    URLComponents.queryItems = @[ [[NSURLQueryItem alloc] initWithName:PeachIdentityProviderQueryItemName value:self.identifier] ];
    return URLComponents.URL;
}

- (NSURL *)loginRequestURLWithEmailAddress:(NSString *)emailAddress
{
    NSURL *redirectURL = [self redirectURL];
    
    NSURL *URL = [self.websiteURL URLByAppendingPathComponent:@"login"];
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = @[ [[NSURLQueryItem alloc] initWithName:@"redirect" value:redirectURL.absoluteString], [[NSURLQueryItem alloc] initWithName:@"withcode" value:@"true"] ];
    if (emailAddress) {
        NSURLQueryItem *emailQueryItem = [[NSURLQueryItem alloc] initWithName:@"email" value:emailAddress];
        queryItems = [queryItems arrayByAddingObject:emailQueryItem];
    }
    URLComponents.queryItems = queryItems;
    return URLComponents.URL;
}

- (BOOL)shouldHandleCallbackURL:(NSURL *)URL
{
    NSString *queryItemValue = [self queryItemValueFromURL:URL withName:PeachIdentityProviderQueryItemName resolvingAgainstBaseURL:YES];
    NSURL *standardizedURL = URL.standardizedURL;
    NSURL *standardizedRedirectURL = [self redirectURL].standardizedURL;
    
    return [standardizedURL.scheme isEqualToString:standardizedRedirectURL.scheme]
        && [standardizedURL.host isEqualToString:standardizedRedirectURL.host]
        && [standardizedURL.path isEqual:standardizedRedirectURL.path]
        && [self.identifier isEqualToString:queryItemValue];
}

- (NSString *)queryItemValueFromURL:(NSURL *)URL withName:(NSString *)queryName
{
    return [self queryItemValueFromURL:URL withName:queryName resolvingAgainstBaseURL:NO];
}

- (NSString *)queryItemValueFromURL:(NSURL *)URL withName:(NSString *)queryName resolvingAgainstBaseURL:(BOOL)againstBaseURL
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:againstBaseURL];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), queryName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    return queryItem.value;
}







#pragma mark Login / logout

- (BOOL)loginWithEmailAddress:(NSString *)emailAddress
{
    if (_loggingIn || self.loggedIn) {
        return NO;
    }
    
    @weakify(self)
    void (^completionHandler)(NSURL * _Nullable, NSError * _Nullable) = ^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
        void (^notifyCancel)(void) = ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidCancelLoginNotification
                                                                object:self
                                                              userInfo:nil];
        };
        
        _loggingIn = NO;
        
        @strongify(self)
        if (callbackURL) {
            [self handleCallbackURL:callbackURL];
        }
        else if (@available(iOS 12, *)) {
            if ([error.domain isEqualToString:ASWebAuthenticationSessionErrorDomain] && error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin) {
                notifyCancel();
            }
        }
        else if (@available(iOS 11, *)) {
            if ([error.domain isEqualToString:SFAuthenticationErrorDomain] && error.code == SFAuthenticationErrorCanceledLogin) {
                notifyCancel();
            }
        }
    };
    
    NSURL *requestURL = [self loginRequestURLWithEmailAddress:emailAddress];
    
    void (^loginWithSafari)(void) = ^{
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:requestURL];
        safariViewController.delegate = self;
        UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.peachTopViewController;
        [topViewController presentViewController:safariViewController animated:YES completion:nil];
    };
    
    if (self.loginMethod == PeachIdentityProviderLoginMethodAuthenticationSession) {
        // iOS 12 and later, use `ASWebAuthenticationSession`
        if (@available(iOS 12, *)) {
            ASWebAuthenticationSession *authenticationSession = [[ASWebAuthenticationSession alloc] initWithURL:requestURL
                                                                                              callbackURLScheme:[PeachIdentityProvider applicationURLScheme]
                                                                                              completionHandler:completionHandler];
            if (@available(iOS 13, *)) {
                authenticationSession.presentationContextProvider = self;
            }
            self.authenticationSession = authenticationSession;
            if (! [authenticationSession start]) {
                return NO;
            }
        }
        // iOS 11, use `SFAuthenticationSession`
        else if (@available(iOS 11, *)) {
            SFAuthenticationSession *authenticationSession = [[SFAuthenticationSession alloc] initWithURL:requestURL
                                                                                        callbackURLScheme:[PeachIdentityProvider applicationURLScheme]
                                                                                        completionHandler:completionHandler];
            self.authenticationSession = authenticationSession;
            if (! [authenticationSession start]) {
                return NO;
            }
        }
        // iOS 9 and 10, use `SFSafariViewController`
        else {
            loginWithSafari();
        }
    }
    else {
        loginWithSafari();
    }
    
    _loggingIn = YES;
    return YES;
}

- (BOOL)logout
{
    if (_loggingIn) {
        return NO;
    }
    
    [self.profileRetrievalTask cancel];
    
    NSString *sessionToken = self.sessionToken;
    if (! sessionToken) {
        return NO;
    }
    
    [self cleanup];
    [self dismissProfileView];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLogoutNotification
                                                        object:self
                                                      userInfo:nil];
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v2/session/logout"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"DELETE";
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"The logout request failed with error %@", [error localizedDescription]);
        }
    }] resume];
    
    return YES;
}


- (void)signupWithEmailAddress:(NSString *)email password:(NSString *)password completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    if (_loggingIn) {
        return;
    }
    
    _loggingIn = YES;
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v2/session/signup"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    NSString *encodedEmail = [email stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    NSString *encodedPassword = [password stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    
    NSString *bodyString = [NSString stringWithFormat:@"email=%@&password=%@", encodedEmail, encodedPassword];
    NSData *body = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@(body.length).stringValue forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = body;
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        _loggingIn = NO;
        if (error) {
            completionBlock(error);
            return;
        }
        else {
            NSString *sessionToken = nil;
            if ([response isKindOfClass:NSHTTPURLResponse.class]) {
                NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
                
                if (HTTPResponse.statusCode >= 400) {
                    NSError *jsonError = nil;
                    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    if (jsonError == nil && jsonResponse != nil) {
                        if ([jsonResponse objectForKey:@"error"] != nil) {
                            NSDictionary *errorDictionary = [jsonResponse objectForKey:@"error"];
                            if (errorDictionary != nil && [errorDictionary objectForKey:@"code"] != nil) {
                                NSString *errorCode = [errorDictionary objectForKey:@"code"];
                                if ([errorCode isEqualToString:@"BAD_DATA"]) {
                                    NSError *signupError = [NSError errorWithDomain:PeachSignupErrorDomain code:PeachSignupBadDataCode userInfo:errorDictionary];
                                    completionBlock(signupError);
                                    return;
                                }
                            }
                        }
                    }
                }
                
                
                NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:HTTPResponse.allHeaderFields forURL:HTTPResponse.URL];
                for (NSHTTPCookie *cookie in cookies) {
                    if ([cookie.name isEqualToString:@"identity.provider.sid"]) {
                        sessionToken = cookie.value;
                    }
                }
            }
            
            if (sessionToken) {
                self.sessionToken = sessionToken;
                [self updateAccount];
                completionBlock(nil);
            }
            else {
                NSError *signupError = [NSError errorWithDomain:PeachSignupErrorDomain code:PeachSignupFailedCode userInfo:nil];
                completionBlock(signupError);
            }
            
        }
        
    }] resume];
}

- (void)loginWithEmailAddress:(NSString *)email password:(NSString *)password completionBlock:(void (^)(NSError * _Nullable error))completionBlock
{
    if (_loggingIn) {
        return;
    }
    
    _loggingIn = YES;
    
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v2/session/login"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    NSString *encodedEmail = [email stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    NSString *encodedPassword = [password stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    
    NSString *bodyString = [NSString stringWithFormat:@"email=%@&password=%@", encodedEmail, encodedPassword];
    NSData *body = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@(body.length).stringValue forHTTPHeaderField:@"Content-Length"];
    request.HTTPBody = body;
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        _loggingIn = NO;
        if (error) {
            completionBlock(error);
            return;
        }
        else {
            NSString *sessionToken = nil;
            if ([response isKindOfClass:NSHTTPURLResponse.class]) {
                NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
                
                if (HTTPResponse.statusCode >= 400) {
                    NSError *jsonError = nil;
                    NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    if (jsonError == nil && jsonResponse != nil) {
                        if ([jsonResponse objectForKey:@"error"] != nil) {
                            NSDictionary *errorDictionary = [jsonResponse objectForKey:@"error"];
                            if (errorDictionary != nil && [errorDictionary objectForKey:@"code"] != nil) {
                                NSString *errorCode = [errorDictionary objectForKey:@"code"];
                                if ([errorCode isEqualToString:@"INCORRECT_LOGIN_OR_PASSWORD"]) {
                                    NSError *loginError = [NSError errorWithDomain:PeachLoginErrorDomain code:PeachLoginIcorrectCode userInfo:errorDictionary];
                                    completionBlock(loginError);
                                    return;
                                }
                            }
                        }
                    }
                }
                
                
                NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:HTTPResponse.allHeaderFields forURL:HTTPResponse.URL];
                for (NSHTTPCookie *cookie in cookies) {
                    if ([cookie.name isEqualToString:@"identity.provider.sid"]) {
                        sessionToken = cookie.value;
                    }
                }
            }
            
            if (sessionToken) {
                self.sessionToken = sessionToken;
                [self updateAccount];
                completionBlock(nil);
            }
            else {
                NSError *loginError = [NSError errorWithDomain:PeachLoginErrorDomain code:PeachLoginFailedCode userInfo:nil];
                completionBlock(loginError);
            }
            
        }
        
    }] resume];
}



- (void)cleanup
{
    [self.profileRetrievalTask cancel];
    self.emailAddress = nil;
    self.sessionToken = nil;
    [self setProfile:nil];
}








#pragma mark Account information

- (void)updateAccount
{
    if (self.profileRetrievalTask) {
        return;
    }
    
    NSString *sessionToken = [self.keyChainStore stringForKey:PeachSessionTokenStoreKey()];
    if (! sessionToken) {
        return;
    }
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *URL = [self.webserviceURL URLByAppendingPathComponent:@"v2/session/user/profile"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", sessionToken] forHTTPHeaderField:@"Authorization"];
        
    // Create the NSURLSessionDataTask post task object.
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        self.profileRetrievalTask = nil;
        if (error) {
            if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
                return;
            }
            else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self cleanup];
                    [self dismissProfileView];
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLogoutNotification
                                                                        object:self
                                                                      userInfo:@{ PeachServiceUnauthorizedKey : @YES }];
                });
            }
            
            return;
        }
        
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
            NSInteger HTTPStatusCode = HTTPURLResponse.statusCode;
            
            if (HTTPStatusCode >= 400) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self cleanup];
                    [self dismissProfileView];
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidLogoutNotification
                                                                        object:self
                                                                      userInfo:@{ PeachServiceUnauthorizedKey : @YES }];
                });
                return;
            }
        }
        
        
        PeachProfile *retrievedProfile = [[PeachProfile alloc] initWithJsonData:data];
        
        if (!retrievedProfile) {
            return;
        }
        
        self.emailAddress = retrievedProfile.emailAddress;
        [self setProfile:retrievedProfile];
    }];
    
    // Execute the task
    [task resume];
    
    self.profileRetrievalTask = task;
}




#pragma mark Profile view

- (void)showProfileViewWithTitle:(NSString *)title
{
    NSAssert(NSThread.isMainThread, @"Must be called from the main thread");
    
    NSURLRequest *request = [self profilePresentationRequest];
    if (! request) {
        return;
    }
    
    if (self.profileNavigationController) {
        return;
    }
    
    PeachIdentityProviderWebViewController *profileViewController = [[PeachIdentityProviderWebViewController alloc] initWithRequest:request decisionHandler:^WKNavigationActionPolicy(NSURL * _Nonnull URL) {
        return [self handleCallbackURL:URL] ? WKNavigationActionPolicyCancel : WKNavigationActionPolicyAllow;
    }];
    profileViewController.title = title;
    profileViewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                                                              style:UIBarButtonItemStyleDone
                                                                                             target:self
                                                                                             action:@selector(dismissProfileView:)];
    PeachIdentityProviderNavigationController *profileNavigationController = [[PeachIdentityProviderNavigationController alloc] initWithRootViewController:profileViewController];
    profileNavigationController.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *topViewController = UIApplication.sharedApplication.keyWindow.peachTopViewController;
    [topViewController presentViewController:profileNavigationController animated:YES completion:nil];
    
    self.profileNavigationController = profileNavigationController;
}

- (void)dismissProfileView
{
    if (! self.profileNavigationController) {
        return;
    }
    
    [self updateAccount];
    [self.profileNavigationController dismissViewControllerAnimated:YES completion:nil];
}

- (NSURLRequest *)profilePresentationRequest
{
    if (! self.sessionToken) {
        return nil;
    }
    
    NSURL *redirectURL = [self redirectURL];
    
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:self.websiteURL resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = @[ [[NSURLQueryItem alloc] initWithName:@"redirect" value:redirectURL.absoluteString], [[NSURLQueryItem alloc] initWithName:@"withcode" value:@"true"] ];
    URLComponents.queryItems = queryItems;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URLComponents.URL];
    [request setValue:[NSString stringWithFormat:@"sessionToken %@", self.sessionToken] forHTTPHeaderField:@"Authorization"];
    return [request copy];
}

#pragma mark Unauthorization reporting

- (void)reportUnauthorization
{
    [self updateAccount];
}



#pragma mark ASWebAuthenticationPresentationContextProviding protocol

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session API_AVAILABLE(ios(13.0)) API_UNAVAILABLE(tvos)
{
    return UIApplication.sharedApplication.keyWindow;
}




#pragma mark SFSafariViewControllerDelegate delegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    _loggingIn = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PeachUserDidCancelLoginNotification
                                                        object:self
                                                      userInfo:nil];
}

#pragma mark Actions

- (void)dismissProfileView:(id)sender
{
    [self dismissProfileView];
}

#pragma mark Notifications

- (void)reachabilityDidChange:(NSNotification *)notification
{
    if ([FXReachability sharedInstance].reachable) {
        [self updateAccount];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self updateAccount];
}

#pragma mark Description

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; keyChainStore = %@>", [self class], self, self.keyChainStore];
}

@end


@implementation NSObject (PeachIdentityProviderApplicationDelegateHooks)

- (BOOL)peach_default_application:(UIApplication *)application openURL:(NSURL *)URL options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return NO;
}

@end

static BOOL swizzled_application_openURL_options(id self, SEL _cmd, UIApplication *application, NSURL *URL, NSDictionary<UIApplicationOpenURLOptionsKey,id> *options)
{
    NSURLComponents *URLComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), PeachIdentityProviderQueryItemName];
    NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
    if (queryItem.value) {
        PeachIdentityProvider *identityProvider = [_identityProviders[queryItem.value] nonretainedObjectValue];
        if ([identityProvider handleCallbackURL:URL]) {
            return YES;
        }
    }
    
    // Find a proper match along the class hierarchy. This also ensures correct behavior if the app delegate is dynamically
    // subclassed, either with a lie (e.g. KVO, for which [self class] lies about the true class nature) or not.
    Class cls = object_getClass(self);
    while (cls != Nil) {
        NSValue *key = [NSValue valueWithNonretainedObject:cls];
        BOOL (*originalImplementation)(id, SEL, id, id, id) = [_originalImplementations[key] pointerValue];
        if (originalImplementation) {
            return originalImplementation(self, _cmd, application, URL, options);
            break;
        }
        else {
            cls = class_getSuperclass(cls);
        }
    }
    
    NSAssert(YES, @"Could not call open URL app delegate original implementation for %@", self);
    return NO;
}


