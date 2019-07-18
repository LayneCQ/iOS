//
//  ZEEditDrawLine.h
//  
//
//  Created by layne on 2019/7/3.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZEEditDrawLine : NSObject
@property (nonatomic, strong)NSMutableArray *points;

- (void)addPoint:(CGPoint)point;

/* 清除所有点 */
- (void)reset;

@end

NS_ASSUME_NONNULL_END
