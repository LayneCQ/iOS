//
//  ZEAssetListCell.m
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZEAssetListCell.h"
#import <Photos/Photos.h>

CGFloat const ZEAssetListCellHeight = 60.f;

@interface ZEAssetListCell ()
@property (nonatomic, strong)UIImageView *thumbnailView;
@property (nonatomic, strong)UILabel *nameLabel;
@property (nonatomic, strong)UILabel *countLabel;
@end

@implementation ZEAssetListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]){
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        /* 缩略图 */
        self.thumbnailView = [[UIImageView alloc] init];
        [self.thumbnailView setContentMode:UIViewContentModeScaleAspectFill];
        self.thumbnailView.clipsToBounds = YES;
        self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.thumbnailView];
        
        /* 相册名 */
        self.nameLabel = [[UILabel alloc] init];
        [self.nameLabel setFont:[UIFont boldSystemFontOfSize:18.f]];
        self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.nameLabel];
        
        /* 相册图片个数 */
        self.countLabel = [[UILabel alloc] init];
        [self.countLabel setFont:[UIFont systemFontOfSize:18.f]];
        [self.countLabel setTextColor:[UIColor colorWithWhite:0 alpha:0.5]];
        self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.countLabel];
        
        [self setupConstraints];//设置约束
        
    }
    return self;
}

- (void)updateWithImage:(UIImage *)image collectionName:(NSString *)name assetCount:(NSInteger)count{
    [self.thumbnailView setImage:image?:[UIImage imageNamed:@"album_placeholder"]];
    [self.nameLabel setText:name];
    [self.countLabel setText:[NSString stringWithFormat:@"(%ld)",(long)count]];
}

#pragma mark - override
- (void)drawRect:(CGRect)rect{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 0.5);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:0 alpha:0.2].CGColor);
    CGContextMoveToPoint(context, 0, rect.size.height-0.5);
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height-0.5);
    
    CGContextStrokePath(context);
}

- (void)setupConstraints{
    //缩略图
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.thumbnailView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.f constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.thumbnailView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.f constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.thumbnailView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.thumbnailView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.thumbnailView attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];
    //相册姓名
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.nameLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.thumbnailView attribute:NSLayoutAttributeRight multiplier:1.f constant:5.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.nameLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.f constant:0.f]];
    //统计个数
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.countLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.nameLabel attribute:NSLayoutAttributeRight multiplier:1.f constant:5.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.countLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.f constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.countLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationLessThanOrEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.f constant:-30.f]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)dealloc{
    self.thumbnailView.image = nil;
    [self.thumbnailView removeFromSuperview];
    self.thumbnailView = nil;
}



@end
