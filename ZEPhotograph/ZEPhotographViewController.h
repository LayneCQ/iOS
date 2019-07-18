//
//  ZEPhotographViewController.h
//
//
//  Created by Layne on 2019/6/30.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ZEPhotographViewController;
@protocol ZEPhotographViewControllerDelegate<NSObject>
- (void)photograph:(ZEPhotographViewController *)photographController didFinishPhotographing:(id)result;
- (void)photographCancel:(ZEPhotographViewController *)photographController;
@end

@interface ZEPhotographViewController : UIViewController
- (instancetype)initWithDelegate:(id<ZEPhotographViewControllerDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
