//
//  PeachIdentityProvider.h
//  PeachIdentityProvider
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import <PeachIdentityProvider/PeachProfile.h>
#import <PeachIdentityProvider/PeachIdentityDataFormat.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN




/**
 *  Available login methods.
 */
typedef NS_ENUM(NSInteger, PeachIdentityProviderLoginMethod) {
    /**
     *  The default recommended method.
     */
    PeachIdentityProviderLoginMethodDefault = 0,
    /**
     *  Login is displayed in a dedicated Safari web view.
     */
    PeachIdentityProviderLoginMethodSafari = PeachIdentityProviderLoginMethodDefault,
    /**
     *  Use an authentication session when available (for iOS 11 and later). User credentials can be shared between your
     *  app and Safari. This makes it possible for a user to automatically authenticate in another app associated with
     *  the same identity provider (if credentials are still available). Note that a system alert will inform the user
     *  about credentials sharing first.
     */
    PeachIdentityProviderLoginMethodAuthenticationSession
};



@interface PeachIdentityProvider : NSObject

/**
 *  PeachIdentityProvider marketing version followed by build number (for example: "1.1.1-25")
 */
+ (NSString *)version;

/**
 *  The identity service currently set as default, if any.
 */
@property (class, nonatomic, nullable) PeachIdentityProvider *defaultProvider;


/**
 *  Instantiate an identity service. A login method can be selected.
 *
 *  @param webserviceURL The URL of the identity webservices.
 *  @param websiteURL    The URL of the identity web portal.
 *  @param loginMethod   The login method to use if possible.
 */
- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL loginMethod:(PeachIdentityProviderLoginMethod)loginMethod NS_DESIGNATED_INITIALIZER;

/**
 *  Same as `-initWithWebserviceURL:websiteURL:loginMethod:`, using the default recommended login method.
 */
- (instancetype)initWithWebserviceURL:(NSURL *)webserviceURL websiteURL:(NSURL *)websiteURL;

/**
 *  Initiate a login procedure. Calling this method opens the service login / signup form with Safari. After successful
 *  login, an `SRGIdentityServiceUserDidLoginNotification` notification is emitted.
 *
 *  @param emailAddress An optional email address, with which the form is filled initially. If not specified, the form starts empty.
 *
 *  @return `YES` if the form could be opened. The method might return `NO` if another attempt is already being made
 *          or if a user is already logged in.
 */
- (BOOL)loginWithEmailAddress:(nullable NSString *)emailAddress;

/**
 * Manually sign up a user by sending an email and a password. Completion block is called when the request is finished, with an error if it failed.
 * When the sign up is finished, an update profile task is launched to retrieve the newly created user profile. Retrieval of the profile will trigger the usual notification
 */
- (void)signupWithEmailAddress:(NSString *)email password:(NSString *)password completionBlock:(void (^)(NSError * _Nullable error))completionBlock;

/**
 * Manually log in a user by sending an email and a password. Completion block is called when the request is finished, with an error if it failed.
 * When the log in is finished, an update profile task is launched to retrieve the user profile. Retrieval of the profile will trigger the usual notification
*/
- (void)loginWithEmailAddress:(NSString *)email password:(NSString *)password completionBlock:(void (^)(NSError * _Nullable error))completionBlock;

/**
 *  Logout the current user, if any.
 *
 *  @return `YES` if a user was logged out. If no user was logged in before calling this method, `NO` is returned.
 */
- (BOOL)logout;

/**
 *  The identity provider URL.
 */
@property (nonatomic, readonly) NSURL *providerURL;

/**
 *  `YES` iff a user is logged.
 */
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;

/**
 *  The email address (username) of the logged in user, if available.
 *
 *  @discussion This property must be used for informative purposes. If you want to find out whether a user is logged
 *              in, check the `loggedIn` property instead.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  Detailed profile information, if available.
 *
 *  @discussion This property must be used for informative purposes. If you want to find out whether a user is logged
 *              in, check the `loggedIn` property instead.
 */
@property (nonatomic, readonly, nullable) PeachProfile *profile;

/**
 *  The session token which has been retrieved, if any.
 */
@property (nonatomic, readonly, copy, nullable) NSString *sessionToken;

/**
 *  Show the account view. The account view has a similar look & feel as the login view, and cannot be customized
 *  through `UIAppearance`.
 *
 *  @discussion This method must be called from the main thread. If no user is logged in, calling the method does nothing.
 *              Note that only one account view can be presented at any given time.
 */
- (void)showProfileViewWithTitle:(NSString *)title;

/**
 *  If an unauthorized error is received when using a third-party service on behalf of the current identity, call this
 *  method to ask the identity service to check whether the apparent situation is confirmed. The service will in all
 *  cases update account information to check whether the reported unauthorization is actually true.
 *
 *  A user is confirmed to be unauthorized is automatically logged out. The `SRGIdentityServiceUserDidLogoutNotification`
 *  notification is sent with `SRGIdentityServiceUnauthorizedKey` set to `@YES` in its `userInfo` dictionary.
 *
 *  If the user is still authorized, though, only account information gets updated, but no logout is made. This means that
 *  the third-party service for which the issue was reported is wrong, probably because it could not correctly validate the
 *  session token.
 *
 *  @discussion The method does nothing if called while a unauthorization check is already being made, or if no user
 *              is currently logged in.
 */
- (void)reportUnauthorization;



@end

@interface PeachIdentityProvider (Unavailable)

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
