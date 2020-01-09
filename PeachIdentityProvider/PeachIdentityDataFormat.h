//
//  PeachIdentityDataFormat.h
//  PeachIdentity
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Notification sent when a user successfully logged in.
 */
OBJC_EXPORT NSString * const PeachUserDidLoginNotification;

/**
 *  Notification sent when a user cancelled a login attempt.
 */
OBJC_EXPORT NSString * const PeachUserDidCancelLoginNotification;

/**
 *  Notification sent when a user logged out.
 */
OBJC_EXPORT NSString * const PeachUserDidLogoutNotification;

/**
 *  Notification sent when account information has been updated. Use the keys available below to retrieve information from
 *  the notification `userInfo` dictionary.
 */
OBJC_EXPORT NSString * const PeachDidUpdateProfileNotification;

/**
 *  Information available for `PeachDidUpdateProfileNotification`.
 */
OBJC_EXPORT NSString * const PeachProfileKey;              // Updated account information, as an `PeachProfile` object.
OBJC_EXPORT NSString * const PeachPreviousProfileKey;      // Previous account information, as an `PeachProfile` object.

/**
 *  Information available for `PeachUserDidLogoutNotification`.
 */
OBJC_EXPORT NSString * const PeachServiceUnauthorizedKey;   // Key to an `NSNumber` wrapping a boolean, set to `YES` iff the user was unauthorized.
OBJC_EXPORT NSString * const PeachServiceDeletedKey;        // Key to an `NSNumber` wrapping a boolean, set to `YES` iff the user deleted his/her account.


NS_ASSUME_NONNULL_END
