//
//  ZEAssetCollectionCell.m
//  
//
//  Created by layne on 2019/6/21.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZEAssetCollectionCell.h"
#import <Photos/Photos.h>
#import "UIImage+Color.h"


CGFloat const ZEAssetCollectionCellSelectionAreaWidth = 40.0f;//选择按钮可点击的范围
NSInteger const ZEAssetCollectionCellUnselectedOrder = -1;//cell未选中的默认序号
NSString *ZEAssetCollectionCellChangeBlurNotification = @"ZEAssetCollectionCellChangeBlurNotification";

@interface ZEAssetCollectionCell ()
@property (nonatomic, strong)UIImageView *photoView;
@property (nonatomic, strong)UIButton *statusButton;
@property (nonatomic, strong)UIButton *videoButton;//视频图标
@end

@implementation ZEAssetCollectionCell

- (instancetype)initWithFrame:(CGRect)frame{
    if(self = [super initWithFrame:frame]){
        [self customSettings];
    }
    return self;
}

- (void)customSettings{
    //图片
    self.photoView = [[UIImageView alloc] init];
    [self.photoView setContentMode:UIViewContentModeScaleAspectFill];
    self.photoView.clipsToBounds = YES;
    self.photoView.userInteractionEnabled = YES;
    self.photoView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.photoView];
    //图片选择状态
    self.statusButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.statusButton setImage:[UIImage imageNamed:@"unselected_icon"] forState:UIControlStateNormal];
    self.statusButton.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
    self.statusButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [self.statusButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.statusButton addTarget:self action:@selector(statusButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.statusButton];
    //视频icon
    self.videoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.videoButton setImage:[UIImage imageNamed:@"video_icon"] forState:UIControlStateNormal];
    self.videoButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.videoButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 5, 0, -5)];
    [self.videoButton.titleLabel setFont:[UIFont systemFontOfSize:13.0f]];
    self.videoButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.videoButton.userInteractionEnabled = NO;
    [self.videoButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.contentView addSubview:self.videoButton];
    
    [self setupConstraints];//设置约束
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(changeBlurStatus:) name:ZEAssetCollectionCellChangeBlurNotification object:nil];
}

- (void)statusButtonClicked:(UIButton *)sender{
    if(self.selection){
        NSInteger order = self.selection();
        UIImage *icon = nil;
        if(order == ZEAssetCollectionCellUnselectedOrder){
            icon = [UIImage imageNamed:@"unselected_icon"];
            [self.statusButton setImage:icon forState:UIControlStateNormal];
        }else{
            icon = [UIImage imageWithNumber:order];
            [self.statusButton setImage:icon forState:UIControlStateNormal];
            //动画
            CGRect rect = self.statusButton.imageView.bounds;
            CGRect rect1 = rect;
            rect1.size = CGSizeZero;
            [self.statusButton.imageView setBounds:rect1];
            [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.3 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                [self.statusButton.imageView setBounds:rect];
            } completion:nil];
        }
    }
}

- (void)updateWithImage:(UIImage *)image selectedOrder:(NSInteger)order isBlur:(BOOL)blur videoDuration:(int)seconds{
    [self.photoView setImage:image];
    UIImage *icon = nil;
    if(order == ZEAssetCollectionCellUnselectedOrder){
        icon = [UIImage imageNamed:@"unselected_icon"];
    }else{
        icon = [UIImage imageWithNumber:order];
    }
    [self.statusButton setImage:icon forState:UIControlStateNormal];
    
    self.alpha = blur?0.5:1;
    
    [self.videoButton setTitle:[self formatVideoDuration:seconds] forState:UIControlStateNormal];
    self.videoButton.hidden = seconds < 0;
    
}

- (NSString *)formatVideoDuration:(int)duration{
    if(duration < 0){
        return @"";
    }
    int minutes = duration / 60;
    int seconds = duration % 60;
    return [NSString stringWithFormat:@"%d:%.2d",minutes,seconds];
}

#pragma mark - Notification
- (void)changeBlurStatus:(NSNotification *)notification{
    NSArray *selectedAssets = [notification object];
    self.alpha = (selectedAssets == nil || [selectedAssets containsObject:@(self.indexPathRow)])?1:0.5;
}

#pragma mark - override
- (void)setupConstraints{
    NSMutableArray *constraints = [NSMutableArray array];
    //photoview
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.photoView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0f constant:1.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.photoView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0f constant:1.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.photoView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0f constant:-1.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.photoView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0f constant:-1.0f]];
    //statusButton
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0f constant:2.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0f constant:-2.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:ZEAssetCollectionCellSelectionAreaWidth]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.statusButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:ZEAssetCollectionCellSelectionAreaWidth]];
    //videoButton
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.videoButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0f constant:5.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.videoButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0f constant:-5.0f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.videoButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0f constant:-5.0f]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)dealloc{
    self.photoView.image = nil;
    [self.photoView removeFromSuperview];
    self.photoView = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
