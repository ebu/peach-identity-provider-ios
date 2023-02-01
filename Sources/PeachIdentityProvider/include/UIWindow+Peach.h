//
//  UIWindow+PeachIdentity.h
//  PeachIdentity
//
//  Created by Rayan Arnaout on 12.12.19.
//  Copyright © 2019 European Broadcasting Union. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIWindow (Peach)

/**
 *  Return the topmost view controller (either root view controller or presented modally).
 */
@property (nonatomic, readonly, nullable) __kindof UIViewController *peachTopViewController;

@end

NS_ASSUME_NONNULL_END
