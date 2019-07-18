//
//  ZEEditOperationBar.h
//  
//
//  Created by layne on 2019/7/2.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ZEEditOperationType){
    ZEEditOperationTypeNone = 10000,//default
    ZEEditOperationTypeDraw,//涂鸦
    ZEEditOperationTypeMosaic,//马赛克
    ZEEditOperationTypeText//文字
};

NS_ASSUME_NONNULL_BEGIN
@class ZEEditOperationBar;
@protocol ZEEditOperationBarDelegate<NSObject>
- (void)operationBar:(ZEEditOperationBar *)bar didSelectType:(ZEEditOperationType)type;

- (void)operationBar:(ZEEditOperationBar *)bar undoForType:(ZEEditOperationType)type;
@end


@interface ZEEditOperationBar : UIView
@property (nonatomic, weak)id<ZEEditOperationBarDelegate> delegate;
@property (nonatomic, copy)NSInteger (^undoAction)(ZEEditOperationType type);

- (void)updateUndoStatus;

@end

NS_ASSUME_NONNULL_END
