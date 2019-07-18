//
//  ZEPhotographManager.m
//  
//
//  Created by Layne on 2019/7/13.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZEPhotographManager.h"
#import "ZEEditView.h"
#import "ZEPhotographViewController.h"

char * const ZEPhotographOutputQueueName = "ZEPhotographOutputQueueName";

@interface ZEPhotographManager ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, copy)CaptureSession captureSession;
@property (nonatomic, copy)CaptureDevice captureDevice;
@property (nonatomic, copy)CaptureOutput captureOutput;
@property (nonatomic, copy)PhotographComplete photographComplete;

@property (nonatomic, strong)dispatch_queue_t captureOutputQueue;

@property (nonatomic, assign)BOOL photographed;//点击了拍照按钮

@end

@implementation ZEPhotographManager

- (instancetype)initWithCaptureSession:(CaptureSession)session captureDevice:(CaptureDevice)device captureOutput:(CaptureOutput)output photographComplete:(PhotographComplete)complete{
    if(self = [super init]){
        self.captureSession = session;
        self.captureDevice = device;
        self.captureOutput = output;
        self.photographComplete = complete;
        [self setupSettings];
    }
    return self;
    
}

- (void)setupSettings{
    self.captureOutputQueue = dispatch_queue_create(ZEPhotographOutputQueueName, DISPATCH_QUEUE_SERIAL);
    
    self.flashOn = NO;
    [self reset];
    
    [self addObserver:self forKeyPath:@"photographedImage" options:NSKeyValueObservingOptionNew context:nil];
    
}

- (void)updateFlashStatus{
    self.flashOn = !self.flashOn;
}

- (void)reset{
    self.photographed = NO;
    
    self.photographedImage = nil;
    self.editedData = nil;

    sEditMosaicBlurImage = nil;//清除马赛克使用的模糊图片
}

- (void)photograph{
    [self.captureOutput() setSampleBufferDelegate:self queue:self.captureOutputQueue];
    [self flash];
}

/* 闪光灯  AVCaptureVideoDataOutput不支持flash，因此使用torch模拟*/
- (void)flash{
    //仅后置镜头时打开torch
    if(self.isFlashOn && [self.captureDevice() hasTorch] && self.captureDevice().position == AVCaptureDevicePositionBack){
        [self.captureDevice() lockForConfiguration:nil];
        [self.captureDevice() setTorchMode:AVCaptureTorchModeOn];
        [self.captureDevice() unlockForConfiguration];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.photographed = YES;
        });
    }else{
        self.photographed = YES;
    }
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([object isKindOfClass:[self class]] && [keyPath isEqualToString:@"photographedImage"]){
        if(self.photographComplete){
            self.photographComplete(self.photographedImage);
        }
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if(self.photographed){
        [self.captureSession() stopRunning];
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
        dispatch_async(dispatch_get_main_queue(), ^{
            AVCaptureVideoOrientation orientation = connection.videoOrientation;
            BOOL mirrored = NO;
            if(self.captureDevice().position == AVCaptureDevicePositionFront){//前置镜头做镜像处理
                mirrored = YES;
                if(orientation == AVCaptureVideoOrientationLandscapeLeft){
                    orientation = AVCaptureVideoOrientationLandscapeRight;
                }else if(orientation == AVCaptureVideoOrientationLandscapeLeft){
                    orientation = AVCaptureVideoOrientationLandscapeLeft;
                }
            }
            self.photographedImage = [self rotateImageToPortrait:image fromOrientation:orientation mirrored:mirrored];
        });
    }
}

#pragma mark - support
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return image;
}

/* 旋转为竖屏模式 */
- (UIImage *)rotateImageToPortrait:(UIImage *)original fromOrientation:(AVCaptureVideoOrientation)orientation mirrored:(BOOL)mirrored{
    if(orientation == AVCaptureVideoOrientationPortrait) return original;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch(orientation){
        case AVCaptureVideoOrientationPortrait:{
            if(mirrored){
                transform = CGAffineTransformScale(transform, -1, 1);
                transform = CGAffineTransformTranslate(transform, -original.size.width, 0);
            }
            break;
        }
        case AVCaptureVideoOrientationPortraitUpsideDown:{
            transform = CGAffineTransformRotate(transform, -M_PI);
            if(mirrored){
                transform = CGAffineTransformScale(transform, -1, 1);
                transform = CGAffineTransformTranslate(transform, 0, -original.size.height);
            }else{
                transform = CGAffineTransformTranslate(transform, -original.size.width, -original.size.height);
            }
            break;
        }
        case AVCaptureVideoOrientationLandscapeLeft:{
            transform = CGAffineTransformRotate(transform, M_PI_2);
            if(mirrored){
                transform = CGAffineTransformScale(transform, 1, -1);
            }else{
               transform = CGAffineTransformTranslate(transform, 0, -original.size.height);
            }
            break;
        }
        case AVCaptureVideoOrientationLandscapeRight:{
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            if(mirrored){
                transform = CGAffineTransformScale(transform, 1, -1);
                transform = CGAffineTransformTranslate(transform, -original.size.width, -original.size.height);
            }else{
                transform = CGAffineTransformTranslate(transform, -original.size.width, 0);
            }
            break;
        }
        
    }

    CGRect rect = CGRectMake(0, 0, MIN(original.size.width,original.size.height), MAX(original.size.width,original.size.height));
    
    //自己创建的ctx是以左下角作为原点。
    //使用UIGraphicsBeginImageContext则使用的是左上角为原点。
    //故自己创建context
    CGContextRef ctx = CGBitmapContextCreate(NULL, rect.size.width, rect.size.height,
                                             CGImageGetBitsPerComponent(original.CGImage), 0,
                                             CGImageGetColorSpace(original.CGImage),
                                             CGImageGetBitmapInfo(original.CGImage));
    //做CTM变换
    CGContextConcatCTM(ctx, transform);

    //绘制图片
    CGContextDrawImage(ctx, CGRectMake(0, 0, original.size.width, original.size.height), original.CGImage);
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *resultPic = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    
    return resultPic;
}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"photographedImage"];
}

@end
