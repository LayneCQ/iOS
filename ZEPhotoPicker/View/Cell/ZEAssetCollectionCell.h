//
//  ZEAssetCollectionCell.h
//  
//
//  Created by layne on 2019/6/21.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
extern NSInteger const ZEAssetCollectionCellUnselectedOrder;//cell未选中的默认序号
extern NSString *ZEAssetCollectionCellChangeBlurNotification;//更改模糊效果的通知

typedef NSInteger (^ZEAssetSelectionBlock)(void);

@class PHAsset;
@interface ZEAssetCollectionCell : UICollectionViewCell
@property (nonatomic, copy)ZEAssetSelectionBlock selection;
@property (nonatomic, assign)NSInteger indexPathRow;//cell在collection中的rownumber

/**
 更新cell UI
 @param image 显示的图片
 @param order 图片右上角角标：数字-当前图片被选中的序号；ZEAssetCollectionCellUnselectedOrder-未被选中，显示为对勾
 @param blur 当前Cell是否显示模糊效果。
 @param seconds 视频时长。若asset为图片，则该参数传-1
 */
- (void)updateWithImage:(UIImage *)image selectedOrder:(NSInteger)order isBlur:(BOOL)blur videoDuration:(int)seconds;

@end

NS_ASSUME_NONNULL_END
