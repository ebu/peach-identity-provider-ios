//
//  PeachIdentityDataFormat.m
//  PeachIdentity
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import "PeachIdentityDataFormat.h"

NSString * const PeachUserDidLoginNotification = @"PeachUserDidLoginNotification";
NSString * const PeachUserDidCancelLoginNotification = @"PeachUserDidCancelLoginNotification";
NSString * const PeachUserDidLogoutNotification = @"PeachUserDidLogoutNotification";
NSString * const PeachDidUpdateProfileNotification = @"PeachDidUpdateAccountNotification";

NSString * const PeachProfileKey = @"PeachProfile";
NSString * const PeachPreviousProfileKey = @"PeachPreviousAccount";

NSString * const PeachUnauthorizedKey = @"PeachUnauthorized";
NSString * const PeachDeletedKey = @"PeachDeleted";

NSString * const PeachServiceUnauthorizedKey = @"PeachServiceUnauthorizedKey";
NSString * const PeachServiceDeletedKey = @"PeachServiceDeletedKey";

NSErrorDomain const PeachSignupErrorDomain = @"PeachSignupErrorDomain";
NSErrorDomain const PeachLoginErrorDomain = @"PeachLoginErrorDomain";

NSInteger const PeachSignupBadDataCode = 9990;
NSInteger const PeachSignupFailedCode = 9991;
NSInteger const PeachLoginIcorrectCode = 9992;
NSInteger const PeachLoginFailedCode = 9993;
