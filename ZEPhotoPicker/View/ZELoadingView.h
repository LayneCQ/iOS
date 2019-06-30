//
//  ZELoadingView.h
//  
//
//  Created by Layne on 2019/6/29.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZELoadingView : UIView

+ (ZELoadingView *)showToView:(UIView *)view withText:(NSString *)message;

+ (void)hideFromView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
