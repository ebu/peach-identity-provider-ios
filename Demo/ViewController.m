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
    
    if (identityProvider.loggedIn) {
        self.displayNameLabel.text = identityProvider.profile.displayName ?: identityProvider.emailAddress ?: @"-";
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(logout:)];
    }
    else {
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
