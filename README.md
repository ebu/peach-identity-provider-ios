

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

# About

The **Peach Identity Provider** framework for iOS provides simple functionalities to facilitate the single sign on process of a user and visualization of the profile.
This framework is a fork of the [SRGIdentity framework](https://github.com/SRGSSR/srgidentity-apple)

# Compatibility

The library is suitable for applications running on iOS 11 and above. The project is meant to be opened with the latest Xcode version (currently Xcode 11).

# Installation

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate PeachIdentityProvider into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "ebu/peach-identity-provider-ios"
```

Run `carthage update` to build the framework and drag the built `PeachCollector.framework` into your Xcode project.

### Dependencies
The library requires the following frameworks to be added to any target requiring it:
-   `FXReachability`: A reachability framework.
-   `libextobjc`: An utility framework.
-   `MAKVONotificationCenter`: A safe KVO framework.
-   `UICKeyChainStore`: The framework used to manage the keychain.

### Dynamic framework integration

1.  Run `carthage update` to update the dependencies (which is equivalent to `carthage update --configuration Release`).
2.  Add the frameworks listed above and generated in the `Carthage/Build/iOS` folder to your target _Embedded binaries_.
3.  Add a _Run script_ build phase to your target, with `/usr/local/bin/carthage copy-frameworks` as command.
4.  Add each of the required frameworks above as input file `$(SRCROOT)/Carthage/Build/iOS/FrameworkName.framework`.

# Usage

When you want to use classes or functions provided by the library in your code, you must import it from your source files first.
In order to properly work, the application integrating the framework needs to define a **URL Scheme**. 
This URL Scheme should also be configured as an authorized URL Scheme on the Identity Provider you will be linking to.

## Framework integration
Import the global header file in any view controller which needs to interact with the identity provider:
#### Objective-C
```objectivec
@import PeachIdentityProvider;
```
#### Swift
```swift
import PeachIdentityProvider
```

## Getting started
### Initializing an identity provider
A identity provider needs to be initialized with a **web service URL** and a **website URL**.

```objectivec
PeachIdentityProvider *identityProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:[NSURL URLWithString:@"https://peach-staging.ebu.io/idp/api"] websiteURL:[NSURL URLWithString:@"https://peach-staging.ebu.io/idp"]]; 
```
You can have several identity providers in an application, though most applications should require only one. To make it easier to access the main identity service of an application, the `PeachIdentityProvider` class provides a class property to set and retrieved it as a shared instance:

```objectivec
PeachIdentityProvider.defaultProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:webserviceURL websiteURL:websiteURL]; 
```

For simplicity, this getting started guide assumes that a shared service has been set. If you cannot use the shared instance, store the services you instantiated somewhere and provide access to them in some way.

### Login

To allow for a user to login, call the `-loginWithEmailAddress:` instance method:
```objectivec
[PeachIdentityProvider.defaultProvider loginWithEmailAddress:nil];
```
This presents a browser, in which the user can supply her credentials or open an account.
A user remains logged in until manually logging out.

##### Remark

On iOS, login occurs within a simple Safari in-app browser by default. Starting with iOS 11, you might prefer using an authentication session, which lets user credentials be shared between your app and Safari, providing automatic login for apps associated with the same identity provider. Before the user can enter her credentials, a system alert will be displayed to inform her about credential sharing.

To enable this feature, use the corresponding login method when creating the service:
```objectivec
PeachIdentityProvider.defaultProvider = [[PeachIdentityProvider alloc] initWithWebserviceURL:webserviceURL websiteURL:websiteURL loginMethod:PeachIdentityProviderLoginMethodAuthenticationSession];
```
On iOS 10 devices and older, the default Safari in-app browser will be used instead.

### Token

Once a user has successfully logged in, a corresponding session token is available in the keychain. Use the `PeachIdentityProvider.defaultProvider.sessionToken` property when you need to retrieve it.

### Profile

Once a user has successfully logged in, a corresponding PeachProfile object will be filled. Use the `PeachIdentityProvider.defaultProvider.profile` property when you need to retrieve information regarding the user.

### Account page

When a user is logged in, its account information can be displayed and edited within your application through a dedicated web page. To display this page, call `-showAccountView`:
```objectivec
[PeachIdentityProvider.defaultProvider showAccountView];
```

### Logout

To logout the current user, simply call `-logout`;
```objectivec
[PeachIdentityProvider.defaultProvider logout];
```

