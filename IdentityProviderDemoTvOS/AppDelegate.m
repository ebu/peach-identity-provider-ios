//
//  AppDelegate.m
//  IdentityProviderDemoTvOS
//
//  Created by Rayan Arnaout on 27.08.20.
//  Copyright © 2020 European Broadcasting Union. All rights reserved.
//

#import "AppDelegate.h"
#import <PeachIdentityProvider/PeachIdentityProvider.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    PeachIdentityProvider.defaultProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://peach-staging.ebu.io/idp/api"] websiteURL:[NSURL URLWithString:@"https://peach-staging.ebu.io/idp"] loginMethod:PeachIdentityProviderLoginMethodDefault];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userDidLogout:)
                                               name:PeachUserDidLogoutNotification
                                             object:PeachIdentityProvider.defaultProvider];
    
    return YES;
}

- (void)userDidLogout:(NSNotification *)notification
{
    if ([notification.userInfo[PeachServiceUnauthorizedKey] boolValue]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Information", nil)
                                                                                 message:NSLocalizedString(@"You have been logged out. Please login again to synchronize your data.", nil)
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}



- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


@end
