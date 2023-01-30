//
//  NSURL.m
//  PeachIdentityProvider
//
//  Created by Rayan Arnaout on 13.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import "include/NSURL+Peach.h"

@implementation NSURL (Peach)

+(NSDictionary<NSString *, NSString *>*)queryParamsFromURL:(NSURL*)url
{
    NSURLComponents* urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

    NSMutableDictionary<NSString *, NSString *>* queryParams = [NSMutableDictionary<NSString *, NSString *> new];
    for (NSURLQueryItem* queryItem in [urlComponents queryItems])
    {
        if (queryItem.value == nil)
        {
            continue;
        }
        [queryParams setObject:queryItem.value forKey:queryItem.name];
    }
    return queryParams;
}

@end
