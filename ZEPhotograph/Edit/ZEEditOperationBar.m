//
//  ZEEditOperationBar.m
//  
//
//  Created by layne on 2019/7/2.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZEEditOperationBar.h"

NSInteger const ZEEditOperationBarItemWidth = 44;

@interface ZEEditOperationBar ()
@property (nonatomic, strong)UIButton *drawButton;//涂鸦
@property (nonatomic, strong)UIButton *mosaicButton;//马赛克
@property (nonatomic, strong)UIButton *textButton;//文字
@property (nonatomic, assign)ZEEditOperationType currentType;

@property (nonatomic, strong)UIView *additionalView;//附属view显示撤销按钮
@property (nonatomic, strong)UIButton *undoButton;//撤销

@end

@implementation ZEEditOperationBar

- (instancetype)initWithFrame:(CGRect)frame{
    if(self = [super initWithFrame:frame]){
        [self customSettings];
    }
    return self;
}

- (void)customSettings{
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    
    //辅助view
    self.additionalView = [[UIView alloc] initWithFrame:CGRectMake(0, -ZEEditOperationBarItemWidth, self.frame.size.width, ZEEditOperationBarItemWidth)];
    self.additionalView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    [self addSubview:self.additionalView];
    self.additionalView.hidden = YES;
    //撤销
    self.undoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.undoButton setFrame:CGRectMake(16, 0, ZEEditOperationBarItemWidth, ZEEditOperationBarItemWidth)];
    [self.undoButton setImage:[UIImage imageNamed:@"edit_undo_enable_icon"] forState:UIControlStateNormal];
    [self.undoButton setImage:[UIImage imageNamed:@"edit_undo_disable_icon"] forState:UIControlStateDisabled];
    [self.undoButton addTarget:self action:@selector(undoButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.additionalView addSubview:self.undoButton];
    
    //draw
    self.drawButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.drawButton.tag = ZEEditOperationTypeDraw;
    [self.drawButton setImage:[UIImage imageNamed:@"edit_draw_normal_icon"] forState:UIControlStateNormal];
    [self.drawButton addTarget:self action:@selector(operationButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.drawButton];
    //mosaic
    self.mosaicButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.mosaicButton.tag = ZEEditOperationTypeMosaic;
    [self.mosaicButton setImage:[UIImage imageNamed:@"edit_mosaic_normal_icon"] forState:UIControlStateNormal];
    [self.mosaicButton addTarget:self action:@selector(operationButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.mosaicButton];
    //textButton
//    self.textButton = [UIButton buttonWithType:UIButtonTypeCustom];
//    self.textButton.tag = ZEEditOperationTypeText;
//    [self.textButton setFrame:CGRectMake(self.frame.size.width-16-ZEEditOperationBarItemWidth, 0, ZEEditOperationBarItemWidth, ZEEditOperationBarItemWidth)];
//    [self.textButton setImage:[UIImage imageNamed:@"edit_text_normal_icon"] forState:UIControlStateNormal];
//    [self.textButton addTarget:self action:@selector(operationButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
//    [self addSubview:self.textButton];
    
    [self setupConstraints];
    
    self.currentType = ZEEditOperationTypeNone;
}

- (void)setupConstraints{
    self.drawButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.mosaicButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.drawButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:ZEEditOperationBarItemWidth]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.drawButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:ZEEditOperationBarItemWidth]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.drawButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:0.5 constant:0.0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.drawButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]];
    
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.mosaicButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:ZEEditOperationBarItemWidth]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.mosaicButton attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:ZEEditOperationBarItemWidth]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.mosaicButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.5 constant:0.0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.mosaicButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]];
    
    [NSLayoutConstraint activateConstraints:constraints];
    
    
}

- (void)configAdditionalView{
    switch(self.currentType){
        case ZEEditOperationTypeNone:{
            self.additionalView.hidden = YES;
            break;
        }
        case ZEEditOperationTypeDraw:{
            self.additionalView.hidden = NO;
            
            break;
        }
        case ZEEditOperationTypeMosaic:{
            self.additionalView.hidden = NO;
            break;
        }
        case ZEEditOperationTypeText:{
            self.additionalView.hidden = YES;
            break;
        }
    }
    [self updateUndoStatus];
}

- (void)updateUndoStatus{
    if(self.undoAction){
        NSInteger count = self.undoAction(self.currentType);
        self.undoButton.enabled = count>0;
    }
}

#pragma mark - button event
- (void)operationButtonClicked:(UIButton *)sender{
    [self.drawButton setImage:[UIImage imageNamed:@"edit_draw_normal_icon"] forState:UIControlStateNormal];
    [self.mosaicButton setImage:[UIImage imageNamed:@"edit_mosaic_normal_icon"] forState:UIControlStateNormal];
    [self.textButton setImage:[UIImage imageNamed:@"edit_text_normal_icon"] forState:UIControlStateNormal];
    
    if(self.currentType == sender.tag){//取消选中
        self.currentType = ZEEditOperationTypeNone;
    }else{
        self.currentType = sender.tag;
        switch(self.currentType){
            case ZEEditOperationTypeDraw:{
                [self.drawButton setImage:[UIImage imageNamed:@"edit_draw_selected_icon"] forState:UIControlStateNormal];
                break;
            }
            case ZEEditOperationTypeMosaic:{
                [self.mosaicButton setImage:[UIImage imageNamed:@"edit_mosaic_selected_icon"] forState:UIControlStateNormal];
                break;
            }
            case ZEEditOperationTypeText:{
                [self.textButton setImage:[UIImage imageNamed:@"edit_text_selected_icon"] forState:UIControlStateNormal];
                break;
            }
            default:break;
        }
    }
    
    //配置辅助视图
    [self configAdditionalView];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(operationBar:didSelectType:)]){
        [self.delegate operationBar:self didSelectType:self.currentType];
    }
}

/* 撤销 */
- (void)undoButtonClicked:(UIButton *)sender{
    if(self.delegate && [self.delegate respondsToSelector:@selector(operationBar:undoForType:)]){
        [self.delegate operationBar:self undoForType:self.currentType];
    }
    
    [self updateUndoStatus];
}

#pragma mark - override
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    if(self.additionalView.hidden == NO){
        CGRect undoButtonRect = [self.additionalView convertRect:self.undoButton.frame toView:self];
        if(CGRectContainsPoint(undoButtonRect, point)){
             return self.undoButton;   
        }
    }
    return [super hitTest:point withEvent:event];
}


@end
