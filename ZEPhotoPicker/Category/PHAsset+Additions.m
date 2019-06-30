//
//  PHAsset+Additions.m
//  
//
//  Created by layne on 2019/6/21.
//  Copyright © 2019 layne. All rights reserved.
//

#import "PHAsset+Additions.h"
#import <objc/runtime.h>

@implementation PHAsset (Additions)
- (UIImage *)cachedThumbnailImage{
    return objc_getAssociatedObject(self, @"cachedThumbnailImage");
}

- (void)setCachedThumbnailImage:(UIImage *)cachedThumbnailImage{
    objc_setAssociatedObject(self, @"cachedThumbnailImage", cachedThumbnailImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end
