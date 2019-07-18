//
//  ZEEditDrawLine.m
//  
//
//  Created by layne on 2019/7/3.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZEEditDrawLine.h"

@implementation ZEEditDrawLine

- (instancetype)init{
    if(self = [super init]){
        self.points = [NSMutableArray array];
    }
    return self;
}

- (void)addPoint:(CGPoint)point{
    [self.points addObject:@(point)];
}

- (void)reset{
    [self.points removeAllObjects];
}

#pragma mark - override
- (id)copyWithZone:(NSZone *)zone{
    ZEEditDrawLine *line  = [[ZEEditDrawLine alloc] init];
    line.points = [self.points mutableCopy];
    return line;
}

- (BOOL)isEqual:(id)object{
    ZEEditDrawLine *line = (ZEEditDrawLine *)object;
    if(self.points.count != line.points.count){
        return NO;
    }
    for(int i = 0;i<self.points.count;++i){
        if(!CGPointEqualToPoint([self.points[i] CGPointValue], [line.points[i] CGPointValue])){
            return NO;
        }
    }
    return YES;
}

@end
