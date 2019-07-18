//
//  ZEPhotographManager.h
//  
//
//  Created by Layne on 2019/7/13.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef AVCaptureSession *(^CaptureSession)(void);
typedef AVCaptureDevice *(^CaptureDevice)(void);
typedef AVCaptureVideoDataOutput *(^CaptureOutput)(void);
typedef void(^PhotographComplete)(UIImage * _Nullable image);

@interface ZEPhotographManager : NSObject
@property (nonatomic, assign,getter=isFlashOn)BOOL flashOn;

@property (nonatomic, strong)UIImage *photographedImage;
@property (nonatomic, strong)NSDictionary *editedData;//图片编辑数据

- (instancetype)initWithCaptureSession:(CaptureSession)session captureDevice:(CaptureDevice)device captureOutput:(CaptureOutput)output photographComplete:(PhotographComplete)complete;

- (void)updateFlashStatus;

- (void)photograph;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
