//
//  ZEEditDraw.h
//  
//
//  Created by layne on 2019/7/3.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZEEditDrawLine.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZEEditDraw : NSObject
@property (nonatomic, strong)NSMutableArray *totalLines;//历史绘制的所有线的集合
@property (nonatomic, strong)ZEEditDrawLine *currentLine;//当前绘制的线

- (NSInteger)count;

/* 将currentLine合并到totalLines中 */
- (void)mergeCurrentLineToTotal;

/* 撤销 */
- (void)backout;

@end

NS_ASSUME_NONNULL_END
