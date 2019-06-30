//
//  ZEAssetListCell.h
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>

extern CGFloat const ZEAssetListCellHeight;

NS_ASSUME_NONNULL_BEGIN

@class PHAssetCollection;
@interface ZEAssetListCell : UITableViewCell

- (void)updateWithImage:(UIImage *)image collectionName:(NSString *)name assetCount:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
