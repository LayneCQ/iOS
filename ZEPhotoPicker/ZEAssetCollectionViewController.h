//
//  ZEAssetCollectionViewController.h
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZEPhotoPickerViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class PHAssetCollection;
@interface ZEAssetCollectionViewController : UIViewController

- (instancetype)initWithAssetCollection:(PHAssetCollection *)assetCollection mediaType:(ZEPhotoPickerMediaType)type;

@end

NS_ASSUME_NONNULL_END
