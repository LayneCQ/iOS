//
//  ZERecordingManager.m
//  
//
//  Created by Layne on 2019/7/13.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZERecordingManager.h"
#import "ZEPhotographViewController.h"

NSString * const ZERecordingFileDestinationPath = @"Videos";
char * const ZERecordingOutputQueueName = "ZERecordingOutputQueueName";

@interface ZERecordingManager () <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic, copy)CaptureSession captureSession;
@property (nonatomic, copy)CaptureDevice captureDevice;
@property (nonatomic, copy)CaptureVideoOutput captureVideoOutput;
@property (nonatomic, copy)CaptureAudioOutput captureAudioOutput;
@property (nonatomic, copy)RecordingComplete recordingComplete;

@property (nonatomic, strong)dispatch_queue_t captureOutputQueue;

@property (nonatomic, strong)AVAssetWriter *writer;
@property (nonatomic, strong)AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong)AVAssetWriterInput *audioWriterInput;

@property (nonatomic, assign,getter=isRecording)BOOL recording;

@property (nonatomic, strong)AVPlayer *player;
@property (nonatomic, strong)AVPlayerItem *playerItem;
@property (nonatomic, strong)AVPlayerLayer *playerLayer;

@property (nonatomic, assign)CGFloat start;
@property (nonatomic, assign)CGFloat current;
@property (nonatomic, assign)NSInteger duration;

@end

@implementation ZERecordingManager

- (instancetype)initWithCaptureSession:(CaptureSession)session captureDevice:(CaptureDevice)device captureVideoOutput:(CaptureVideoOutput)videoOutput captureAudioOutput:(CaptureAudioOutput)audioOutput recordingComplete:(RecordingComplete)complete{
    if(self = [super init]){
        self.captureSession = session;
        self.captureDevice = device;
        self.captureVideoOutput = videoOutput;
        self.captureAudioOutput = audioOutput;
        self.recordingComplete = complete;
        [self setupSettings];
    }
    return self;
}

- (void)setupSettings{
    self.captureOutputQueue = dispatch_queue_create(ZERecordingOutputQueueName, DISPATCH_QUEUE_SERIAL);
    self.maxDuration = 10;//默认录制10s
    
    [self initWriter];
    
    self.videoURL = nil;
    self.duration = -1;
    
    [self addObserver:self forKeyPath:@"duration" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
}

- (void)initWriter{
    self.writer = [AVAssetWriter assetWriterWithURL:[self destinationURL] fileType:AVFileTypeMPEG4 error:nil];
    self.writer.shouldOptimizeForNetworkUse = YES;
    
    //写入视频大小
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    
    NSInteger numPixels = screenWidth * screenHeight;
    CGFloat bitsPerPixel = 8.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    NSDictionary *videoSettings = @{AVVideoCodecKey:AVVideoCodecH264,
                                    AVVideoScalingModeKey:AVVideoScalingModeResizeAspectFill,
                                    AVVideoWidthKey:@(screenHeight * 2),
                                    AVVideoHeightKey:@(screenWidth * 2),
                                    AVVideoCompressionPropertiesKey:@{
                                            AVVideoExpectedSourceFrameRateKey : @(30),
                                            AVVideoAverageBitRateKey: @(bitsPerSecond),
                                            AVVideoMaxKeyFrameIntervalKey:@(10),
                                            }
                                    };
    self.videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.videoWriterInput.expectsMediaDataInRealTime = YES;
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformMakeRotation(M_PI_2);
    if(self.captureDevice().position == AVCaptureDevicePositionFront){
        transform = CGAffineTransformScale(transform, 1, -1);//镜像
    }
    self.videoWriterInput.transform =transform;
    
    if([self.writer canAddInput:self.videoWriterInput]){
        [self.writer addInput:self.videoWriterInput];
    }
    
    NSDictionary *audioSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                                    AVNumberOfChannelsKey: @(1),
                                    AVSampleRateKey: @(22050)};
    self.audioWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    self.audioWriterInput.expectsMediaDataInRealTime = YES;
    if([self.writer canAddInput:self.audioWriterInput]){
        [self.writer addInput:self.audioWriterInput];
    }
}

- (void)initPlayerWithVideo:(NSURL *)videoURL{
    self.playerItem = [AVPlayerItem playerItemWithURL:videoURL];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[self.player currentItem]];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.recordingComplete){
            self.recordingComplete(self.playerLayer,self.writer.outputURL,ZERecordingFailTypeNone);
        }
    });
    self.videoURL = self.writer.outputURL;
}

- (void)startRecording{
    [self.captureVideoOutput() setSampleBufferDelegate:self queue:self.captureOutputQueue];
    [self.captureAudioOutput() setSampleBufferDelegate:self queue:self.captureOutputQueue];
    [self initWriter];
    self.recording = YES;
}

- (void)stopRecording{
    self.recording = NO;
    
    if([self videoIsTooShort]){
        return;
    }
    
    if(self.writer){
        if(self.videoWriterInput){
            [self.videoWriterInput markAsFinished];
        }
        if(self.audioWriterInput){
            [self.audioWriterInput markAsFinished];
        }
        __weak typeof(self) weakself = self;
        [self.writer finishWritingWithCompletionHandler:^{
            [weakself initPlayerWithVideo:weakself.writer.outputURL];
        }];
    }
    
}

- (void)reset:(BOOL)removeVideo{
    self.recording = NO;
    
    if(removeVideo){
        NSFileManager *fm = [NSFileManager defaultManager];
        if([fm fileExistsAtPath:self.writer.outputURL.path]){
            [fm removeItemAtURL:self.writer.outputURL error:nil];
        }
    }
    
    self.writer = nil;
    self.videoWriterInput = nil;
    self.audioWriterInput = nil;
    
    if(self.playerLayer){
        [self.playerLayer removeFromSuperlayer];
    }
    self.playerLayer = nil;
    self.playerItem = nil;
    self.player = nil;
    
    self.videoURL = nil;
    
    self.duration = -1;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)videoIsTooShort{
    if(self.duration < 1 && self.writer){//录制时间太短
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.recordingComplete){
                self.recordingComplete(self.playerLayer,self.writer.outputURL,ZERecordingFailTypeTooShort);
            }
        });
        return YES;
    }
    return NO;
}

#pragma mark - setter
- (void)setMaxDuration:(NSInteger)maxDuration{
    _maxDuration = maxDuration<5?5:maxDuration;
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    dispatch_async(dispatch_get_main_queue(), ^{
        if([object isKindOfClass:[self class]] && [keyPath isEqualToString:@"duration"]){
            CGFloat old = [change[NSKeyValueChangeOldKey] floatValue];
            CGFloat new = [change[NSKeyValueChangeNewKey] floatValue];
            if(old == -1 && new == 0){
                [[NSNotificationCenter defaultCenter] postNotificationName:ZERecordingStartNotification object:nil];
            }
            if(self.duration >= self.maxDuration){
                if(self.recordingComplete){
                    self.recordingComplete(self.playerLayer,self.writer.outputURL,ZERecordingFailTypeExceedMaxDuration);
                }
            }
        }
    });
}

#pragma mark - Notification
- (void)playerItemDidReachEnd:(NSNotification *)notification{
    AVPlayerItem *playerItem = [notification object];
    [playerItem seekToTime:kCMTimeZero];
}

#pragma mark - support
- (NSURL *)destinationURL{
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *destinationPath = [documentsPath stringByAppendingPathComponent:ZERecordingFileDestinationPath];
    if(![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]){
        [[NSFileManager defaultManager] createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSDateFormatter *dfm = [[NSDateFormatter alloc] init];
    [dfm setDateFormat:@"yyyy-MM-dd_HH:mm:ss"];
    NSString *fileName = [[dfm stringFromDate:[NSDate date]] stringByAppendingPathExtension:@"mp4"];
    NSString *filePath = [destinationPath stringByAppendingPathComponent:fileName];
    
    return [NSURL fileURLWithPath:filePath];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    @synchronized (self) {
        if(self.recording){
            if(self.writer) {
                if(self.writer.status == AVAssetWriterStatusFailed ||
                   self.writer.status == AVAssetWriterStatusCancelled ||
                   self.writer.status == AVAssetWriterStatusCompleted){
                    return;
                }
                if(self.writer.status == AVAssetWriterStatusUnknown){
                    [self.writer startWriting];
                    [self.writer startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                    CMTime startTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                    self.start = startTimeStamp.value/startTimeStamp.timescale;
                }
                
                if(connection == [self.captureVideoOutput() connectionWithMediaType:AVMediaTypeVideo]) {
                    if(self.videoWriterInput.readyForMoreMediaData){
                        [self.videoWriterInput appendSampleBuffer:sampleBuffer];
                    }
                }else if(connection == [self.captureAudioOutput() connectionWithMediaType:AVMediaTypeAudio]) {
                    if(self.audioWriterInput.readyForMoreMediaData){
                        [self.audioWriterInput appendSampleBuffer:sampleBuffer];
                    }
                }
                
                CMTime timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                self.current = timeStamp.value/timeStamp.timescale;
                self.duration = floorf(self.current - self.start);//记录时长
            }
        }
        
    }

}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"duration"];
}

@end
