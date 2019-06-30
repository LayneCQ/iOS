//
//  ZEPhotoPreviewViewController.h
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
extern NSInteger const ZEPhotoPreviewStartIndex;

@class PHAsset;
@interface ZEPhotoPreviewViewController : UIViewController
@property (nonatomic, copy)void(^updateViewsBlock)(void);//用于更新AssetCollectionVC的UI回调
@property (nonatomic, copy)CGRect(^postionForAsset)(PHAsset *asset);//计算当前asset在collectionView中的位置
@property (nonatomic, copy)void(^completeSelectionBlock)(NSArray<PHAsset *> *selected);//完成回调

- (instancetype)initWithAssets:(NSArray<PHAsset *> *)allAssets selectedAssets:(NSMutableArray<PHAsset *> *)selectedAssets startIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
