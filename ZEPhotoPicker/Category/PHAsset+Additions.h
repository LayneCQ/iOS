//
//  PHAsset+Additions.h
//  
//
//  Created by layne on 2019/6/21.
//  Copyright © 2019 layne. All rights reserved.
//

#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHAsset (Additions)
@property (nonatomic, strong)UIImage *cachedThumbnailImage;
@end

NS_ASSUME_NONNULL_END
