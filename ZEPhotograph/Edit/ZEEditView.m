//
//  ZEEditView.m
//  
//
//  Created by layne on 2019/7/2.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZEEditView.h"
#import "ZEEditOperationBar.h"
#import "ZEEditDraw.h"
#import "ZEEditMosaic.h"
#import <Accelerate/Accelerate.h>

UIImage * sEditMosaicBlurImage = nil;

NSString * const ZEOperationTypeDrawDataKey = @"DrawData";
NSString * const ZEOperationTypeMosaicDataKey = @"MosaicData";
NSString * const ZEOperationTypeTextDataKey = @"TextData";

NSInteger const ZEEditDrawLineWidth = 5.0f;
NSInteger const ZEEditMosaicLineWidth = 30.0f;

@interface ZEEditView () <UIScrollViewDelegate, UIGestureRecognizerDelegate,ZEEditOperationBarDelegate>
@property (nonatomic, strong)UIImage *originalImage;

@property (nonatomic, strong)UIButton *cancelButton;
@property (nonatomic, strong)UIButton *completeButton;
@property (nonatomic, strong)UIScrollView *imageViewContainer;
@property (nonatomic, strong)ZEEditOperationBar *operationBar;

@property (nonatomic, assign)ZEEditOperationType operationType;

@property (nonatomic, assign)CGFloat realRatio;//图片放大比例
@property (nonatomic, assign)CGFloat ratio;//使用的图片放大比例，编辑过程中一直为1，编辑完成之后会使用realRatio

@property (nonatomic, strong)UITapGestureRecognizer *tapRecognizer;

/* Draw */
@property (nonatomic, copy)ZEEditDraw *drawData;
@property (nonatomic, strong)CAShapeLayer *shapeLayer;
@property (nonatomic, strong)UIPanGestureRecognizer *drawPanRecognizer;//绘制手势

/* Mosaic */
@property (nonatomic, copy)ZEEditMosaic *mosaicData;
@property (nonatomic, strong)CAShapeLayer *mosaicShapeLayer;
@property (nonatomic, strong)UIImage *realTileImage;
@property (nonatomic, strong)UIImage *tileImage;


@end

@implementation ZEEditView

- (instancetype)initWithFrame:(CGRect)frame imageToEdit:(UIImage *)image editedData:(NSDictionary *)data{
    if(self = [super initWithFrame:[UIScreen mainScreen].bounds]){
        self.originalImage = image;
        self.operationType = ZEEditOperationTypeNone;
        
        self.drawData = [[ZEEditDraw alloc] init];
        self.mosaicData = [[ZEEditMosaic alloc] init];
        if(data){
           if([data.allKeys containsObject:ZEOperationTypeDrawDataKey]){
               self.drawData = [data objectForKey:ZEOperationTypeDrawDataKey];
           }
            if([data.allKeys containsObject:ZEOperationTypeMosaicDataKey]){
                self.mosaicData = [data objectForKey:ZEOperationTypeMosaicDataKey];
            }
        }
        [self setupSettings];
    }
    return self;
}

- (void)setupSettings{
    /* Basic UI */
    self.backgroundColor = [UIColor blackColor];
    //imageView
    self.imageViewContainer = [[UIScrollView alloc] initWithFrame:self.frame];
    self.imageViewContainer.backgroundColor = [UIColor blackColor];
    self.imageViewContainer.maximumZoomScale = 3.0f;
    self.imageViewContainer.minimumZoomScale  =1.0f;
    self.imageViewContainer.delegate = self;
    [self addSubview:self.imageViewContainer];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [imageView setContentMode:UIViewContentModeScaleAspectFill];
    imageView.image = self.originalImage;
    imageView.tag = 8888;
    imageView.userInteractionEnabled = YES;
    [self.imageViewContainer addSubview:imageView];
    
    self.drawPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];//手势
    self.drawPanRecognizer.maximumNumberOfTouches = 1;
    self.drawPanRecognizer.minimumNumberOfTouches = 1;
    self.drawPanRecognizer.enabled = NO;
    self.drawPanRecognizer.delegate = self;
    [self.imageViewContainer addGestureRecognizer:self.drawPanRecognizer];
    
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];//手势
    [self.imageViewContainer addGestureRecognizer:self.tapRecognizer];
    
    //cancel
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.cancelButton setFrame:CGRectMake(0, 0, 60, 30)];
    self.cancelButton.layer.cornerRadius = 5;
    self.cancelButton.layer.borderColor = [UIColor grayColor].CGColor;
    self.cancelButton.layer.borderWidth = 1;
    self.cancelButton.backgroundColor = [UIColor whiteColor];
    [self.cancelButton addTarget:self action:@selector(cancelButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.cancelButton];
    //complete
    self.completeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.completeButton setTitle:@"完成" forState:UIControlStateNormal];
    [self.completeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.completeButton setFrame:CGRectMake(0, 0, 60, 30)];
    self.completeButton.layer.cornerRadius = 5;
    self.cancelButton.layer.borderColor = [UIColor grayColor].CGColor;
    self.cancelButton.layer.borderWidth = 1;
    self.completeButton.backgroundColor = [UIColor greenColor];
    [self.completeButton addTarget:self action:@selector(completeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.completeButton];
    if([self hasNotch]){
        [self.cancelButton setFrame:CGRectMake(16, 64, 60, 30)];
        [self.completeButton setFrame:CGRectMake(self.frame.size.width-16-60, self.cancelButton.frame.origin.y, 60, 30)];
        //operation bar
        self.operationBar = [[ZEEditOperationBar alloc] initWithFrame:CGRectMake(0, self.frame.size.height-44-34, self.frame.size.width, 44+34)];
    }else{
        [self.cancelButton setFrame:CGRectMake(16, 40, 60, 30)];
        [self.completeButton setFrame:CGRectMake(self.frame.size.width-16-60, self.cancelButton.frame.origin.y, 60, 30)];

        self.operationBar = [[ZEEditOperationBar alloc] initWithFrame:CGRectMake(0, self.frame.size.height-44, self.frame.size.width, 44)];
    }
    self.operationBar.delegate = self;
    __weak typeof(self) weakself = self;
    self.operationBar.undoAction = ^NSInteger(ZEEditOperationType type) {
        switch(type){
            case ZEEditOperationTypeDraw:{
                return weakself.drawData.count;
            }
            case ZEEditOperationTypeMosaic:{
                return weakself.mosaicData.count;
            }
            case ZEEditOperationTypeText:{
                
                break;
            }
            case ZEEditOperationTypeNone:{
                break;
            }
        }
        return 0;
    };
    [self addSubview:self.operationBar];
    
    
    //设置倍率
    self.ratio = 1.0f;
    self.realRatio = self.originalImage.size.width/self.bounds.size.width;
    
/***************/
    //1.涂鸦
    self.shapeLayer = [CAShapeLayer layer];
    self.shapeLayer.strokeColor = [UIColor redColor].CGColor;
    self.shapeLayer.lineWidth = ZEEditDrawLineWidth;
    self.shapeLayer.fillColor = [UIColor clearColor].CGColor;
    self.shapeLayer.lineCap = kCALineCapRound;
    self.shapeLayer.lineJoin = kCALineJoinRound;
    [imageView.layer addSublayer:self.shapeLayer];
    [self updateDrawPath];
    
    //2.马赛克
    self.tileImage = [self mosaicBlurImage];
    self.realTileImage = [self createRealTileImage];
    self.mosaicShapeLayer = [CAShapeLayer layer];
    self.mosaicShapeLayer.strokeColor = [UIColor colorWithPatternImage:self.tileImage].CGColor;
    self.mosaicShapeLayer.lineWidth = ZEEditMosaicLineWidth;
    self.mosaicShapeLayer.fillColor = [UIColor clearColor].CGColor;
    self.mosaicShapeLayer.lineCap = kCALineCapRound;
    self.mosaicShapeLayer.lineJoin = kCALineJoinRound;
    [imageView.layer addSublayer:self.mosaicShapeLayer];
    [self updateMosaicPath];
}

/* 为不同的编辑做准备 */
- (void)prepareOperation{
    switch(self.operationType){
        case ZEEditOperationTypeNone:{
            self.imageViewContainer.panGestureRecognizer.enabled = YES;
            self.drawPanRecognizer.enabled = NO;
            break;
        }
        case ZEEditOperationTypeDraw:
        case ZEEditOperationTypeMosaic:{
            self.imageViewContainer.panGestureRecognizer.enabled = NO;
            self.drawPanRecognizer.enabled = YES;
            break;
        }
        case ZEEditOperationTypeText:{
            self.imageViewContainer.panGestureRecognizer.enabled = YES;
            self.drawPanRecognizer.enabled = NO;
            break;
        }
    }
}

/* 点击完成执行的预备操作 */
- (void)prepareCompletion{
    self.ratio = self.realRatio;
    self.tileImage = self.realTileImage;
    [self updateDrawPath];
    [self updateMosaicPath];
    
    //界面还原和原图一样大小，用于后续截图
    UIImageView *imageView = [self.imageViewContainer viewWithTag:8888];
    imageView.transform = CGAffineTransformIdentity;//imageView可能已经被放大，这里还原
    CGRect rect = imageView.frame;
    rect.origin = CGPointZero;
    rect.size = CGSizeMake(self.originalImage.size.width, self.originalImage.size.height);
    [imageView setFrame:rect];

}

/* 创建马赛克功能使用的模糊图片 */
- (UIImage *)mosaicBlurImage{
    if(sEditMosaicBlurImage){
        return [self adjustMosaicBlurImage];
    }
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    [blurEffectView setFrame:self.bounds];
    
    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *vibrancyEffectView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    [vibrancyEffectView setFrame:self.bounds];
    [blurEffectView.contentView addSubview:vibrancyEffectView];
    
    [self addSubview:blurEffectView];
    
    self.cancelButton.hidden = YES;
    self.completeButton.hidden = YES;
    self.operationBar.hidden = YES;
    
    UIGraphicsBeginImageContextWithOptions(self.frame.size, NO, 0);
    [self drawViewHierarchyInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [blurEffectView removeFromSuperview];
    self.cancelButton.hidden = NO;
    self.completeButton.hidden = NO;
    self.operationBar.hidden = NO;
    
    sEditMosaicBlurImage = image;
    
    return [self adjustMosaicBlurImage];
}

/* 由于strokeColor绘制的图片是镜像图片，因此这里先对原图片进行一次镜像，然后绘制的马赛克模糊图片就是正常的了 */
- (UIImage *)adjustMosaicBlurImage{
    CGContextRef ctx = CGBitmapContextCreate(NULL, sEditMosaicBlurImage.size.width, sEditMosaicBlurImage.size.height,
                                             CGImageGetBitsPerComponent(sEditMosaicBlurImage.CGImage), 0,
                                             CGImageGetColorSpace(sEditMosaicBlurImage.CGImage),
                                             CGImageGetBitmapInfo(sEditMosaicBlurImage.CGImage));
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformRotate(transform, M_PI);
    transform = CGAffineTransformScale(transform, -1, 1);
    transform = CGAffineTransformTranslate(transform, 0, -sEditMosaicBlurImage.size.height);
    
    CGContextConcatCTM(ctx, transform);
    CGContextDrawImage(ctx, CGRectMake(0, 0, sEditMosaicBlurImage.size.width, sEditMosaicBlurImage.size.height), sEditMosaicBlurImage.CGImage);
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *result = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    
    return result;
}

#pragma mark - Operation-Draw
- (void)updateDrawPath{
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    self.shapeLayer.lineWidth = self.shapeLayer.lineWidth * self.ratio;
    for(int i = 0;i<self.drawData.totalLines.count;++i){//绘制历史线条
        ZEEditDrawLine *line = self.drawData.totalLines[i];
        [self drawLine:line.points forPath:&bezierPath];
        
    }
    //当前线条
    [self drawLine:self.drawData.currentLine.points forPath:&bezierPath];
    
    self.shapeLayer.path = bezierPath.CGPath;
}

- (void)drawLine:(NSArray *)points forPath:(UIBezierPath **)path{
    if(points.count>1){
        CGPoint point = [points.firstObject CGPointValue];
        CGPoint startPoint = CGPointMake(point.x*self.ratio, point.y*self.ratio);
        [*path moveToPoint:startPoint];
        for(int i=1;i<points.count;++i){
            CGPoint currentPoint = CGPointMake([points[i] CGPointValue].x*self.ratio, [points[i] CGPointValue].y*self.ratio);
            CGPoint previousPoint = CGPointMake([points[i-1] CGPointValue].x*self.ratio, [points[i-1] CGPointValue].y*self.ratio);
            CGPoint midPoint = CGPointMake((currentPoint.x+previousPoint.x)/2.0f, (currentPoint.y+previousPoint.y)/2.0f);
            [*path addQuadCurveToPoint:currentPoint controlPoint:midPoint];
        }
    }
}

#pragma mark - Operation-Mosaic
- (void)updateMosaicPath{
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    self.mosaicShapeLayer.strokeColor = [UIColor colorWithPatternImage:self.tileImage].CGColor;
    self.mosaicShapeLayer.lineWidth = self.mosaicShapeLayer.lineWidth * self.ratio;
    for(int i = 0;i<self.mosaicData.totalLines.count;++i){//绘制历史路径
        ZEEditMosaicLine *path = self.mosaicData.totalLines[i];
        [self drawLine:path.points forPath:&bezierPath];
    }
    //绘制当前路径
    [self drawLine:self.mosaicData.currentLine.points forPath:&bezierPath];
    
    self.mosaicShapeLayer.path = bezierPath.CGPath;
}

#pragma mark - support
- (BOOL)hasNotch{
    if(@available(iOS 11.0, *)){
        return [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom > 0.0f;
    }
    return NO;
}

/* 创建马赛克icon */
- (UIImage *)createRealTileImage{
    UIImage *tileImage = sEditMosaicBlurImage;
    
    CGRect targetRect = CGRectMake(0, 0, tileImage.size.width * self.realRatio, tileImage.size.height * self.realRatio);
    CGSize targetSize = targetRect.size;
    UIGraphicsBeginImageContext(targetSize);
    [tileImage drawInRect:targetRect];
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resultImage?resultImage:tileImage;

}

#pragma mark - Gesture
- (void)pan:(UIPanGestureRecognizer *)pan{
    switch(pan.state){
        case UIGestureRecognizerStateBegan:{
            CGPoint currentPoint = [pan locationInView:[self.imageViewContainer viewWithTag:8888]];
            if(self.operationType == ZEEditOperationTypeDraw){
                [self.drawData.currentLine reset];
                [self.drawData.currentLine addPoint:currentPoint];
            }else if(self.operationType == ZEEditOperationTypeMosaic){
                [self.mosaicData.currentLine reset];
                [self.mosaicData.currentLine addPoint:currentPoint];
            }
            
            break;
        }
        case UIGestureRecognizerStateChanged:{
            CGPoint currentPoint = [pan locationInView:[self.imageViewContainer viewWithTag:8888]];
            if(self.operationType == ZEEditOperationTypeDraw){
                [self.drawData.currentLine addPoint:currentPoint];
                [self updateDrawPath];
            }else{
                [self.mosaicData.currentLine addPoint:currentPoint];
                [self updateMosaicPath];
            }
            
            break;
        }
        case UIGestureRecognizerStateEnded:{
            CGPoint currentPoint = [pan locationInView:[self.imageViewContainer viewWithTag:8888]];
            if(self.operationType == ZEEditOperationTypeDraw){
                [self.drawData.currentLine addPoint:currentPoint];
                [self.drawData mergeCurrentLineToTotal];
                [self updateDrawPath];
            }else{
                [self.mosaicData.currentLine addPoint:currentPoint];
                [self.mosaicData mergeCurrentLineToTotal];
                [self updateMosaicPath];
            }
            [self.operationBar updateUndoStatus];
            break;
        }
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:{

            break;
        }
    }
}

- (void)tap:(UITapGestureRecognizer *)tap{
    self.cancelButton.hidden = !self.cancelButton.hidden;
    self.completeButton.hidden = !self.completeButton.hidden;
    self.operationBar.hidden = !self.operationBar.hidden;
}

#pragma mark - button event
- (void)cancelButtonClicked:(UIButton *)sender{
    [self removeFromSuperview];
}

- (void)completeButtonClicked:(UIButton *)sender{
    
    [self prepareCompletion];
    
    UIImageView *imageView = [self.imageViewContainer viewWithTag:8888];
    UIGraphicsBeginImageContext(self.originalImage.size);
    [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if(self.editComplete){
        self.editComplete(image,@{ZEOperationTypeDrawDataKey:self.drawData,
                                  ZEOperationTypeMosaicDataKey:self.mosaicData
                                  });
    }
    [self removeFromSuperview];
}

#pragma mark - UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{
    return [scrollView viewWithTag:8888];
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    if(gestureRecognizer.numberOfTouches == 0){
        return YES;
    }
    return NO;
}

#pragma mark - ZEEditOperationBarDelegate
- (void)operationBar:(ZEEditOperationBar *)bar didSelectType:(ZEEditOperationType)type{
    self.operationType = type;
    [self prepareOperation];
}

- (void)operationBar:(ZEEditOperationBar *)bar undoForType:(ZEEditOperationType)type{
    switch(type){
        case ZEEditOperationTypeDraw:{
            [self.drawData backout];
            [self updateDrawPath];
            break;
        }
        case ZEEditOperationTypeMosaic:{
            [self.mosaicData backout];
            [self updateMosaicPath];
            break;
        }
        case ZEEditOperationTypeText:{
            
            break;
        }
        case ZEEditOperationTypeNone:{
            break;
        }
    }
}

- (void)dealloc{
    [self.imageViewContainer removeGestureRecognizer:self.drawPanRecognizer];
    [self.imageViewContainer removeGestureRecognizer:self.tapRecognizer];
}


@end
