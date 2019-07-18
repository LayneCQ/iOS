//
//  ZEEditDraw.m
//  
//
//  Created by layne on 2019/7/3.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZEEditDraw.h"

@interface ZEEditDraw ()
@end

@implementation ZEEditDraw

- (instancetype)init{
    if(self = [super init]){
        self.totalLines = [NSMutableArray array];
        self.currentLine = [[ZEEditDrawLine alloc] init];
    }
    return self;
}

- (NSInteger)count{
    return self.totalLines.count;
}

- (void)mergeCurrentLineToTotal{
    if(![self.totalLines containsObject:self.currentLine]){
        [self.totalLines addObject:[self.currentLine copy]];
    }
    [self.currentLine reset];
}

- (void)backout{
    if(self.totalLines.count>0){
        [self.totalLines removeLastObject];
    }
}

#pragma mark - override
- (id)copyWithZone:(NSZone *)zone{
    ZEEditDraw *draw  = [[ZEEditDraw alloc] init];
    draw.totalLines = [self.totalLines mutableCopy];
    draw.currentLine = [self.currentLine copy];
    return draw;
}

@end
