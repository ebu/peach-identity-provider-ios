//
//  PeachIdentityProviderTests.m
//  PeachIdentityProviderTests
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import <PeachIdentityProvider/PeachIdentityProvider.h>
#import <XCTest/XCTest.h>
#import <libextobjc/libextobjc.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

#import "IdentityBaseTestCase.h"

@interface PeachIdentityProviderTests : IdentityBaseTestCase

@property (nonatomic) PeachIdentityProvider *identityProvider;

@end


static NSString *TestValidToken = @"0123456789";

@interface PeachIdentityProvider (Private)

- (BOOL)handleCallbackURL:(NSURL *)callbackURL;

@property (nonatomic, readonly, copy) NSString *identifier;

@end

static NSURL *TestWebserviceURL(void)
{
    return [NSURL URLWithString:@"https://api.ebu.local"];
}

static NSURL *TestWebsiteURL(void)
{
    return [NSURL URLWithString:@"https://www.ebu.local"];
}

static NSURL *TestLoginCallbackURL(PeachIdentityProvider *identityProvider, NSString *token)
{
    NSString *URLString = [NSString stringWithFormat:@"peachidp-tests://%@?identity_provider=%@&token=%@", TestWebserviceURL().host, identityProvider.identifier, token];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestLogoutCallbackURL(PeachIdentityProvider *identityProvider)
{
    NSString *URLString = [NSString stringWithFormat:@"peachidp-tests://%@?identity_provider=%@&action=log_out", TestWebserviceURL().host, identityProvider.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestAccountDeletedCallbackURL(PeachIdentityProvider *identityProvider)
{
    NSString *URLString = [NSString stringWithFormat:@"peachidp-tests://%@?identity_provider=%@&action=account_deleted", TestWebserviceURL().host, identityProvider.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestUnauthorizedCallbackURL(PeachIdentityProvider *identityProvider)
{
    NSString *URLString = [NSString stringWithFormat:@"peachidp-tests://%@?identity_provider=%@&action=unauthorized", TestWebserviceURL().host, identityProvider.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored1CallbackURL(PeachIdentityProvider *identityProvider)
{
    NSString *URLString = [NSString stringWithFormat:@"peachidp-tests://%@?identity_provider=%@&action=unknown", TestWebserviceURL().host, identityProvider.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored2CallbackURL(PeachIdentityProvider *identityProvider)
{
    NSString *URLString = [NSString stringWithFormat:@"myapp://%@?identity_provider=%@", TestWebserviceURL().host, identityProvider.identifier];
    return [NSURL URLWithString:URLString];
}

static NSURL *TestIgnored3CallbackURL()
{
    NSString *URLString = [NSString stringWithFormat:@"https://www.ebu.ch"];
    return [NSURL URLWithString:URLString];
}


@implementation PeachIdentityProviderTests

#pragma mark Setup and teardown

- (void)setUp
{
    self.identityProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:TestWebserviceURL() websiteURL:TestWebsiteURL()];
    [self.identityProvider logout];
    
    [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
        return [request.URL.host isEqual:TestWebserviceURL().host];
    } withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        if ([request.URL.host isEqualToString:TestWebsiteURL().host]) {
            if ([request.URL.path containsString:@"login"]) {
                NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithURL:request.URL resolvingAgainstBaseURL:NO];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", @keypath(NSURLQueryItem.new, name), @"redirect"];
                NSURLQueryItem *queryItem = [URLComponents.queryItems filteredArrayUsingPredicate:predicate].firstObject;
                
                NSURL *redirectURL = [NSURL URLWithString:queryItem.value];
                NSURLComponents *redirectURLComponents = [[NSURLComponents alloc] initWithURL:redirectURL resolvingAgainstBaseURL:NO];
                NSArray<NSURLQueryItem *> *queryItems = redirectURLComponents.queryItems ?: @[];
                queryItems = [queryItems arrayByAddingObject:[[NSURLQueryItem alloc] initWithName:@"token" value:TestValidToken]];
                redirectURLComponents.queryItems = queryItems;
                
                return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                   statusCode:302
                                                      headers:@{ @"Location" : redirectURLComponents.URL.absoluteString }] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
        }
        else if ([request.URL.host isEqualToString:TestWebserviceURL().host]) {
            if ([request.URL.path containsString:@"logout"]) {
                return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                   statusCode:204
                                                      headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
            }
            else if ([request.URL.path containsString:@"profile"]) {
                NSString *validAuthorizationHeader = [NSString stringWithFormat:@"sessionToken %@", TestValidToken];
                if ([[request valueForHTTPHeaderField:@"Authorization"] isEqualToString:validAuthorizationHeader]) {
                    NSDictionary<NSString *, id> *account = @{@"user": @{ @"id" : @"1234",
                                                               @"public_uid" : @"4321",
                                                               @"login" : @"test@ebu.ch",
                                                               @"display_name": @"Play SRG",
                                                               @"firstname": @"Play",
                                                               @"lastname": @"SRG",
                                                               @"gender": @"other",
                                                                          @"date_of_birth": @"2001-01-01" }};
                    return [[OHHTTPStubsResponse responseWithData:[NSJSONSerialization dataWithJSONObject:account options:0 error:NULL]
                                                       statusCode:200
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
                else {
                    return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                                       statusCode:401
                                                          headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
                }
            }
        }
        
        // No match, return 404
        return [[OHHTTPStubsResponse responseWithData:[NSData data]
                                           statusCode:404
                                              headers:nil] requestTime:1. responseTime:OHHTTPStubsDownloadSpeedWifi];
    }];
}

- (void)tearDown
{
    [self.identityProvider logout];
    self.identityProvider = nil;
    
    [OHHTTPStubs removeAllStubs];
}

#pragma mark Tests

- (void)testLoginHandleCallbackURL
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertTrue(self.identityProvider.loggedIn);
}

- (void)testLogoutHandleCallbackURL
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:PeachUserDidLogoutNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityProvider handleCallbackURL:TestLogoutCallbackURL(self.identityProvider)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
}

- (void)testAccountDeletedHandleCallbackURL
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:PeachUserDidLogoutNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]);
        XCTAssertTrue([notification.userInfo[PeachServiceDeletedKey] boolValue]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityProvider handleCallbackURL:TestAccountDeletedCallbackURL(self.identityProvider)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
}

- (void)testUnauthorizedHandleCallbackURL
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:PeachUserDidLogoutNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertTrue([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    BOOL hasHandledCallbackURL = [self.identityProvider handleCallbackURL:TestUnauthorizedCallbackURL(self.identityProvider)];
    XCTAssertTrue(hasHandledCallbackURL);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
}

- (void)testIgnoredHandleCallbackURL
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:PeachUserDidLogoutNotification object:self.identityProvider queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    BOOL hasHandledCallbackURL1 = [self.identityProvider handleCallbackURL:TestIgnored1CallbackURL(self.identityProvider)];
    XCTAssertFalse(hasHandledCallbackURL1);
    BOOL hasHandledCallbackURL2 = [self.identityProvider handleCallbackURL:TestIgnored2CallbackURL(self.identityProvider)];
    XCTAssertFalse(hasHandledCallbackURL2);
    BOOL hasHandledCallbackURL3 = [self.identityProvider handleCallbackURL:TestIgnored3CallbackURL()];
    XCTAssertFalse(hasHandledCallbackURL3);
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
}

- (void)testLogout
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    [self expectationForSingleNotification:PeachUserDidLogoutNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    XCTAssertTrue([self.identityProvider logout]);
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertFalse([self.identityProvider logout]);
}

- (void)testAccountUpdate
{
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachDidUpdateProfileNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNotNil(notification.userInfo[PeachProfileKey]);
        XCTAssertNil(notification.userInfo[PeachPreviousProfileKey]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNotNil(self.identityProvider.emailAddress);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    XCTAssertNotNil(self.identityProvider.profile);
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    
    [self expectationForSingleNotification:PeachUserDidLogoutNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertFalse([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    [self expectationForSingleNotification:PeachDidUpdateProfileNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([NSThread isMainThread]);
        XCTAssertNil(notification.userInfo[PeachProfileKey]);
        XCTAssertNotNil(notification.userInfo[PeachPreviousProfileKey]);
        return YES;
    }];
    
    XCTAssertTrue([self.identityProvider logout]);
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
}

- (void)testAutomaticLogoutWhenUnauthorized
{
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, @"invalid_token")];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, @"invalid_token");
    
    // Wait until account information is requested. The token is invalid, the user unauthorized and therefore logged out automatically
    [self expectationForSingleNotification:PeachUserDidLogoutNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        XCTAssertTrue([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]);
        return YES;
    }];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertNil(self.identityProvider.emailAddress);
    XCTAssertNil(self.identityProvider.sessionToken);
    XCTAssertNil(self.identityProvider.profile);
    
    XCTAssertFalse(self.identityProvider.loggedIn);
}

- (void)testUnverifiedReportedUnauthorization
{
    [self expectationForSingleNotification:PeachUserDidLoginNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:PeachUserDidLogoutNotification object:self.identityProvider queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    [self expectationForSingleNotification:PeachDidUpdateProfileNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.identityProvider reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
}

- (void)testMultipleUnverifiedReportedUnauthorizations
{
    // A first account update is performed after login. Wait for it
    [self expectationForSingleNotification:PeachDidUpdateProfileNotification object:self.identityProvider handler:^BOOL(NSNotification * _Nonnull notification) {
        return YES;
    }];
    
    [self.identityProvider handleCallbackURL:TestLoginCallbackURL(self.identityProvider, TestValidToken)];
    
    [self waitForExpectationsWithTimeout:5. handler:nil];
    
    XCTAssertTrue(self.identityProvider.loggedIn);
    XCTAssertEqualObjects(self.identityProvider.sessionToken, TestValidToken);
    
    __block NSInteger numberOfUpdates = 0;
    id accountUpdateObserver = [NSNotificationCenter.defaultCenter addObserverForName:PeachDidUpdateProfileNotification object:self.identityProvider queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        ++numberOfUpdates;
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    // Unverified reported unauthorizations lead to an account update. Expect at most 1
    [self.identityProvider reportUnauthorization];
    [self.identityProvider reportUnauthorization];
    [self.identityProvider reportUnauthorization];
    [self.identityProvider reportUnauthorization];
    [self.identityProvider reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:accountUpdateObserver];
    }];
    
    XCTAssertEqual(numberOfUpdates, 1);
}

- (void)testReportedUnauthorizationWhenLoggedOut
{
    XCTAssertFalse(self.identityProvider.loggedIn);
    XCTAssertNil(self.identityProvider.sessionToken);
    
    id loginObserver = [NSNotificationCenter.defaultCenter addObserverForName:PeachUserDidLoginNotification object:self.identityProvider queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No login is expected");
    }];
    id accountUpdateObserver = [NSNotificationCenter.defaultCenter addObserverForName:PeachDidUpdateProfileNotification object:self.identityProvider queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No account update is expected");
    }];
    id logoutObserver = [NSNotificationCenter.defaultCenter addObserverForName:PeachUserDidLogoutNotification object:self.identityProvider queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        XCTFail(@"No logout is expected");
    }];
    
    [self expectationForElapsedTimeInterval:4. withHandler:nil];
    
    [self.identityProvider reportUnauthorization];
    
    [self waitForExpectationsWithTimeout:5. handler:^(NSError * _Nullable error) {
        [NSNotificationCenter.defaultCenter removeObserver:loginObserver];
        [NSNotificationCenter.defaultCenter removeObserver:accountUpdateObserver];
        [NSNotificationCenter.defaultCenter removeObserver:logoutObserver];
    }];
    
    XCTAssertFalse(self.identityProvider.loggedIn);
    XCTAssertNil(self.identityProvider.sessionToken);
}

@end



