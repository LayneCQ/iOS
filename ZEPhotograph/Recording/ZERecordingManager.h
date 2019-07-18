//
//  ZERecordingManager.h
//  
//
//  Created by Layne on 2019/7/13.
//  Copyright © 2019 Layne. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZEPhotographManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger,ZERecordingFailType){
    ZERecordingFailTypeNone,
    ZERecordingFailTypeExceedMaxDuration,
    ZERecordingFailTypeTooShort
};
typedef AVCaptureVideoDataOutput *(^CaptureVideoOutput)(void);
typedef AVCaptureAudioDataOutput *(^CaptureAudioOutput)(void);

static NSString * const ZERecordingStartNotification = @"ZERecordingStartNotification";

typedef void(^RecordingComplete)(AVPlayerLayer *displayLayer,NSURL * _Nullable videoURL,ZERecordingFailType failType);

@interface ZERecordingManager : NSObject
@property (nonatomic, strong)NSURL *videoURL;
@property (nonatomic, assign)NSInteger maxDuration;//录制的时长

- (instancetype)initWithCaptureSession:(CaptureSession)session captureDevice:(CaptureDevice)device captureVideoOutput:(CaptureVideoOutput)videoOutput captureAudioOutput:(CaptureAudioOutput)audioOutput recordingComplete:(RecordingComplete)complete;

- (void)startRecording;

- (void)stopRecording;

- (void)reset:(BOOL)removeVideo;

@end

NS_ASSUME_NONNULL_END
