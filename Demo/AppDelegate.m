//
//  AppDelegate.m
//  Demo
//
//  Created by Rayan Arnaout on 18.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import "AppDelegate.h"
#import <PeachIdentityProvider/PeachIdentityProvider.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //PeachIdentityProvider.defaultProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://peach-staging.ebu.io/idp/api"] websiteURL:[NSURL URLWithString:@"https://peach-staging.ebu.io/idp"] loginMethod:PeachIdentityProviderLoginMethodAuthenticationSession];
    
    PeachIdentityProvider.defaultProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://sso-sr-demo.ebu.io/api"] websiteURL:[NSURL URLWithString:@"https://sso-sr-demo.ebu.io"] loginMethod:PeachIdentityProviderLoginMethodAuthenticationSession];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(userDidLogout:)
                                               name:PeachUserDidLogoutNotification
                                             object:PeachIdentityProvider.defaultProvider];
    
    return YES;
}

#pragma mark Notifications

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



@end
