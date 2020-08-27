//
//  ViewController.m
//  Demo
//
//  Created by Rayan Arnaout on 18.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import "ViewController.h"
#import <PeachIdentityProvider/PeachIdentityProvider.h>

static NSString * const LastLoggedInEmailAddress = @"LastLoggedInEmailAddress";

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UILabel *displayNameLabel;
@property (nonatomic, weak) IBOutlet UIButton *accountButton;

@property (nonatomic, weak) IBOutlet UIView *nativeLoginView;
@property (nonatomic, weak) IBOutlet UITextField *emailTextField;
@property (nonatomic, weak) IBOutlet UITextField *passwordTextField;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation ViewController

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDidLogin:)
                                                 name:PeachUserDidLoginNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didUpdateAccount:)
                                                 name:PeachDidUpdateProfileNotification
                                               object:nil];
    
    [self reloadData];
}

#pragma mark Getters and setters

- (NSString *)title
{
    return @"Peach IDP demo";
}

#pragma mark UI

- (void)reloadData
{
    PeachIdentityProvider *identityProvider = PeachIdentityProvider.defaultProvider;
    
    self.activityIndicator.hidden = YES;
    
    if (identityProvider.loggedIn) {
        self.nativeLoginView.alpha = 0;
        self.displayNameLabel.text = identityProvider.profile.displayName ?: identityProvider.emailAddress ?: @"-";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logout:)];
    }
    else {
        self.nativeLoginView.alpha = 1;
        self.displayNameLabel.text = @"Not logged in";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Login", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(login:)];
    }
    
    self.accountButton.hidden = ! identityProvider.loggedIn;
}

#pragma mark Actions

- (IBAction)showAccount:(id)sender
{
    [PeachIdentityProvider.defaultProvider showProfileViewWithTitle:@"My Profile"];
}

- (IBAction)nativeLogin:(id)sender
{
    self.activityIndicator.hidden = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.nativeLoginView.alpha = 0;
    }];
    
    PeachIdentityProvider *identityProvider = PeachIdentityProvider.defaultProvider;
    [identityProvider loginWithEmailAddress:self.emailTextField.text password:self.passwordTextField.text completionBlock:^(NSError * _Nullable error) {
        NSLog(@"error = %@", error.domain);
        if ([error.domain isEqualToString:PeachLoginErrorDomain]){
            dispatch_async(dispatch_get_main_queue(), ^{
               self.nativeLoginView.alpha = 1;
               self.activityIndicator.hidden = YES;
            });
            NSLog(@"json = %@", error.userInfo);
        }
    }];
}

- (void)login:(id)sender
{
    NSString *lastEmailAddress = [NSUserDefaults.standardUserDefaults stringForKey:LastLoggedInEmailAddress];
    [PeachIdentityProvider.defaultProvider loginWithEmailAddress:lastEmailAddress];
}

- (void)logout:(id)sender
{
    [PeachIdentityProvider.defaultProvider logout];
}

#pragma mark Notifications

- (void)userDidLogin:(NSNotification *)notification
{
    [self reloadData];
}

- (void)didUpdateAccount:(NSNotification *)notification
{
    [self reloadData];
    
    NSString *emailAddress = PeachIdentityProvider.defaultProvider.emailAddress;;
    if (emailAddress) {
        [NSUserDefaults.standardUserDefaults setObject:emailAddress forKey:LastLoggedInEmailAddress];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}


@end
