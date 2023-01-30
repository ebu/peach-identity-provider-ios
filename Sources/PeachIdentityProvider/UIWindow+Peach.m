//
//  UIWindow+PeachIdentity.m
//  PeachIdentity
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import "UIWindow+Peach.h"

@implementation UIWindow (Peach)

- (UIViewController *)peachTopViewController
{
    UIViewController *topViewController = self.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

@end
