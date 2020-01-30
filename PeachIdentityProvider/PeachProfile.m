//
//  PeachProfile.m
//  PeachIdentity
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 SRG SSR. All rights reserved.
//

#import "PeachProfile.h"

@interface PeachProfile()

@property (nonatomic, copy, nullable) NSString *uid;
@property (nonatomic, copy, nullable) NSString *publicUid;
@property (nonatomic, copy, nullable) NSString *login;
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *emailAddress;
@property (nonatomic, copy, nullable) NSString *firstName;
@property (nonatomic, copy, nullable) NSString *lastName;
@property (nonatomic) PeachGender gender;
@property (nonatomic, nullable) NSDate *birthdate;
@property (nonatomic, copy, nullable) NSString *language;

@property (nonatomic, getter=isVerified) BOOL verified;

@end

@implementation PeachProfile


- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super init]) {
        self.uid = [decoder decodeObjectForKey:@"uid"];
        self.publicUid = [decoder decodeObjectForKey:@"publicUid"];
        self.displayName = [decoder decodeObjectForKey:@"displayName"];
        self.emailAddress = [decoder decodeObjectForKey:@"login"];
        self.firstName = [decoder decodeObjectForKey:@"firstName"];
        self.lastName = [decoder decodeObjectForKey:@"lastName"];
        [self parseGender:[decoder decodeObjectForKey:@"gender"]];
        [self parseBirthdate:[decoder decodeObjectForKey:@"birthdate"]];
        self.verified = [decoder decodeBoolForKey:@"verified"];
        self.language = [decoder decodeObjectForKey:@"language"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.uid forKey:@"uid"];
    [encoder encodeObject:self.publicUid forKey:@"publicUid"];
    [encoder encodeObject:self.displayName forKey:@"displayName"];
    [encoder encodeObject:self.login forKey:@"login"];
    [encoder encodeObject:self.emailAddress forKey:@"email"];
    [encoder encodeObject:self.firstName forKey:@"firstName"];
    [encoder encodeObject:self.lastName forKey:@"lastName"];
    [encoder encodeObject:self.genderString forKey:@"gender"];
    [encoder encodeObject:self.birthdayString forKey:@"birthdate"];
    [encoder encodeBool:self.verified forKey:@"verified"];
    [encoder encodeObject:self.language forKey:@"language"];
}


- (id)initWithJsonData:(NSData *)data
{
    self = [super init];
    
    if (self) {
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        if (error) { /* JSON was malformed, act appropriately here */
            return nil;
        }

        if ([object isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *result = object;
            NSDictionary *user = [result objectForKey:@"user"];
            
            self.uid = [user valueForKey:@"id"];
            self.publicUid = [user valueForKey:@"public_uid"];
            self.displayName = [user valueForKey:@"display_name"];
            self.emailAddress = [user valueForKey:@"email"];
            self.login = [user valueForKey:@"login"];
            self.firstName = [self parseString:[user valueForKey:@"firstname"]];
            self.lastName = [self parseString:[user valueForKey:@"lastname"]];
            [self parseGender: [self parseString:[user valueForKey:@"gender"]]];
            [self parseBirthdate: [self parseString:[user valueForKey:@"date_of_birth"]]];
            NSNumber *verifiedNumber = [user valueForKey:@"email_verified"];
            if (verifiedNumber && verifiedNumber != (NSNumber *)[NSNull null]) self.verified = [verifiedNumber boolValue];
            self.language = [self parseString:[user valueForKey:@"language"]];
        }
        
    }
    return self;
}

- (NSString *)parseString:(NSString *)value
{
    if (value == (NSString *)[NSNull null] || [value isEqualToString:@"<null>"] || [value isEqualToString:@""]) {
        return nil;
    }
    return value;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [dict setObject:self.uid forKey:@"uid"];
    [dict setObject:self.publicUid forKey:@"publicUid"];
    if (self.displayName != nil) [dict setObject:self.displayName forKey:@"displayName"];
    if (self.login != nil) [dict setObject:self.login forKey:@"login"];
    if (self.emailAddress != nil) [dict setObject:self.login forKey:@"email"];
    if (self.firstName != nil) [dict setObject:self.firstName forKey:@"firstName"];
    if (self.lastName != nil) [dict setObject:self.lastName forKey:@"lastName"];
    NSString *genderString = [self genderString];
    if (genderString != nil) [dict setObject:genderString forKey:@"gender"];
    [dict setObject:self.birthdayString forKey:@"birthdate"];
    [dict setObject:@(self.verified) forKey:@"verified"];
    if (self.language != nil) [dict setObject:self.language forKey:@"language"];
    return [dict copy];
}

- (NSData *)jsonRepresentation{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.dictionaryRepresentation options:0 error:&error];
    if (error) {
        return nil;
    }
    return jsonData;
}

- (NSString *)genderString{
    if (self.gender == PeachGenderOther) return @"other";
    if (self.gender == PeachGenderFemale) return @"female";
    if (self.gender == PeachGenderMale) return @"male";
    return nil;
}

- (void)parseGender:(NSString *)genderString
{
    if (genderString) {
        if ([genderString isEqualToString:@"other"]) self.gender = PeachGenderOther;
        else if ([genderString isEqualToString:@"female"]) self.gender = PeachGenderFemale;
        else self.gender = PeachGenderMale;
    }
    self.gender = PeachGenderNone;
}

- (void)parseBirthdate:(NSString *)dateString
{
    if (dateString) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        self.birthdate = [dateFormatter dateFromString:dateString];
    }
}

- (NSString *)birthdayString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    return [dateFormatter stringFromDate:self.birthdate];
}

#pragma mark Equality

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    PeachProfile *otherProfile = object;
    return [self.uid isEqualToString:otherProfile.uid];
}

- (NSUInteger)hash
{
    return self.uid.hash;
}


@end
