//
//  PeachProfile.h
//  PeachIdentity
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 SRG SSR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Genders.
 */
typedef NS_ENUM(NSInteger, PeachGender) {
    PeachGenderNone = 0,
    PeachGenderFemale,
    PeachGenderMale,
    PeachGenderOther
};


@interface PeachProfile : NSObject <NSCoding>

- (id)initWithJsonData:(NSData *)data;
- (NSData *)jsonRepresentation;
/**
 *  The unique account identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *uid;

/**
 *  The unique public account identifier.
 */
@property (nonatomic, readonly, copy, nullable) NSString *publicUid;

/**
 *  The account display name.
 */
@property (nonatomic, readonly, copy, nullable) NSString *displayName;

/**
 *  The email address associated with the account.
 */
@property (nonatomic, readonly, copy, nullable) NSString *emailAddress;

/**
 *  The user first name.
 */
@property (nonatomic, readonly, copy, nullable) NSString *firstName;

/**
 *  The user last name.
 */
@property (nonatomic, readonly, copy, nullable) NSString *lastName;

/**
 *  The user gender.
 */
@property (nonatomic, readonly) PeachGender gender;

/**
 *  The user birthdate.
 */
@property (nonatomic, readonly, nullable) NSDate *birthdate;

/**
 *  `YES` iff the account has been verified.
 */
@property (nonatomic, readonly, getter=isVerified) BOOL verified;

@end

NS_ASSUME_NONNULL_END
