//
//  UIImage+Color.h
//  
//
//  Created by layne on 2019/6/21.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (Color)

/* 创建纯色图片 */
+ (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size;

/* 绘制纯数字图片 */
+ (UIImage *)imageWithNumber:(NSInteger)number;

/* 调整图片朝向 */
- (UIImage *)fixOrentation;

@end

NS_ASSUME_NONNULL_END
