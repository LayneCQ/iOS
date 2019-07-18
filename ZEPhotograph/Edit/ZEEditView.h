//
//  ZEEditView.h
//  
//
//  Created by layne on 2019/7/2.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <UIKit/UIKit.h>

extern UIImage * sEditMosaicBlurImage;//用于马赛克的模糊图片

NS_ASSUME_NONNULL_BEGIN

@interface ZEEditView : UIView
@property (nonatomic, copy)void(^editComplete)(UIImage *editedImage, NSDictionary *editedData);

- (instancetype)initWithFrame:(CGRect)frame imageToEdit:(UIImage *)image editedData:(NSDictionary *)data;

@end

NS_ASSUME_NONNULL_END
