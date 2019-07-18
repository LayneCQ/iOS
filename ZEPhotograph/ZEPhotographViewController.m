//
//  ZEPhotographViewController.m
//  
//
//  Created by Layne on 2019/6/30.
//  Copyright © 2019 Layne. All rights reserved.
//

#import "ZEPhotographViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ZEPhotographManager.h"
#import "ZERecordingManager.h"
#import "ZEEditView.h"

NSInteger const ZEPhotographButtonWidth = 80.0f;
NSInteger const ZEPhotographExitButtonWidth = 20.0f;
NSInteger const ZEPhotographVisualEffectViewTag = 9999;


@interface ZEPhotographViewController () 
@property (nonatomic, strong)UIView *photographView;
@property (nonatomic, strong)UIButton *photographButton;//拍照按钮
@property (nonatomic, strong)UIButton *exitButton;//退出按钮
@property (nonatomic, strong)UIButton *switchButton;//前后镜头切换
@property (nonatomic, strong)UIButton *flashButton;//闪光灯按钮

@property (nonatomic, strong)UIImageView *previewImageView;//拍照之后的预览界面
@property (nonatomic, strong)UIButton *cancelButton;//拍照之后的取消按钮
@property (nonatomic, strong)UIButton *completeButton;//拍照之后的完成按钮
@property (nonatomic, strong)UIButton *editButton;//拍照之后的编辑按钮

@property (nonatomic, strong)AVCaptureSession *captureSession;
@property (nonatomic, strong)AVCaptureDevice *videoCaptureDevice;
@property (nonatomic, strong)AVCaptureDevice *audioCaptureDevice;
@property (nonatomic, strong)AVCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, strong)AVCaptureDeviceInput *audioCaptureDeviceInput;
@property (nonatomic, strong)AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong)AVCaptureAudioDataOutput *audioDataOutput;

@property (nonatomic, strong)CAShapeLayer *recordingProgressLayer;

@property (nonatomic, strong)AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, weak)id<ZEPhotographViewControllerDelegate> photographDelegate;
@property (nonatomic, assign)BOOL authorizationChecked;//是否已检测相机权限

@property (nonatomic, strong)ZEPhotographManager *photographManager;
@property (nonatomic, strong)ZERecordingManager *recordingManager;

@property (nonatomic, strong)UILongPressGestureRecognizer *longPressRecognizer;

@end

@implementation ZEPhotographViewController

- (instancetype)initWithDelegate:(id<ZEPhotographViewControllerDelegate>)delegate{
    if(self = [super init]){
        self.photographDelegate = delegate;
        self.view.backgroundColor = [UIColor blackColor];
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if(!self.authorizationChecked){
        self.authorizationChecked = YES;
        [self checkAuthorization];
    }
}

- (void)launch{
    [self setupUI];
    [self setupSettings];
}

/* 检查相机权限 */
- (void)checkAuthorization{
    switch([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]){
        case AVAuthorizationStatusNotDetermined:{
            __weak typeof(self) weakself = self;
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(granted){
                        [weakself launch];
                    }else{
                        [weakself showNoAuthorizationAlert];
                    }
                });
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:{
            [self launch];
            break;
        }
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:{
            [self showNoAuthorizationAlert];
            break;
        }
            
    }
}

- (void)showNoAuthorizationAlert{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"您未授权相机权限，请先到手机设置中开启相机权限。" preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakself = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakself dismissViewControllerAnimated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakself dismissViewControllerAnimated:YES completion:^{
            if([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]){
                if(@available(iOS 10,*)){
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                }else{
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                }
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    
}

#pragma mark - setup
- (void)setupUI{
    self.view.backgroundColor = [UIColor blackColor];
    self.photographView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.photographView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.photographView];
    
    //拍照按钮
    self.photographButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.photographButton setFrame:CGRectMake(0, 0, ZEPhotographButtonWidth, ZEPhotographButtonWidth)];
    self.photographButton.layer.cornerRadius = ZEPhotographButtonWidth/2.0f;
    [self.photographButton setImage:[UIImage imageNamed:@"photograph_button"] forState:UIControlStateNormal];
    [self.photographButton setImage:[UIImage imageNamed:@"photograph_button_selected"] forState:UIControlStateHighlighted];
    [self.photographButton addTarget:self action:@selector(photographButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    CGRect rect = self.photographButton.frame;
    rect.origin.x = (self.view.frame.size.width-rect.size.width)/2.0f;
    if([self hasNotch]){
        rect.origin.y = self.view.frame.size.height - 34-44-rect.size.height;
    }else{
        rect.origin.y = self.view.frame.size.height - 44-rect.size.height;
    }
    [self.photographButton setFrame:rect];
    self.photographButton.hidden = NO;
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(startRecording:)];
    [self.photographButton addGestureRecognizer:self.longPressRecognizer];
    [self.view addSubview:self.photographButton];
    //录视频时的动画layer
    self.recordingProgressLayer = [CAShapeLayer layer];
    [self.recordingProgressLayer setFrame:CGRectMake(3, 3, self.photographButton.frame.size.width-6, self.photographButton.frame.size.height-6)];
    [self.photographButton.layer addSublayer:self.recordingProgressLayer];
    self.recordingProgressLayer.backgroundColor = [UIColor clearColor].CGColor;
    
    //退出按钮
    self.exitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.exitButton setFrame:CGRectMake(0, 0, ZEPhotographExitButtonWidth, ZEPhotographExitButtonWidth)];
    [self.exitButton setImage:[UIImage imageNamed:@"photograph_exit_button"] forState:UIControlStateNormal];
    [self.exitButton addTarget:self action:@selector(exitButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    rect = self.exitButton.frame;
    rect.origin.x = 16.0f;
    if([self hasNotch]){
        rect.origin.y = 44+10;
    }else{
        rect.origin.y = 20+10;
    }
    [self.exitButton setFrame:rect];
    self.exitButton.hidden = NO;
    [self.view addSubview:self.exitButton];
    //闪光灯按钮
    self.flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.flashButton setFrame:CGRectMake((self.view.frame.size.width-40)/2.0f, self.exitButton.frame.origin.y, 40, 40)];
    [self.flashButton setContentVerticalAlignment:UIControlContentVerticalAlignmentTop];
    [self.flashButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
    [self.flashButton setImage:[UIImage imageNamed:@"flash_off_icon"] forState:UIControlStateNormal];
    [self.flashButton addTarget:self action:@selector(flashButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.flashButton.hidden = NO;
    [self.view addSubview:self.flashButton];
    //切换前后镜头按钮
    self.switchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.switchButton setFrame:CGRectMake(self.view.frame.size.width-30-16.0f, self.exitButton.frame.origin.y, 30, 25)];
    [self.switchButton setImage:[UIImage imageNamed:@"camera_switch_button"] forState:UIControlStateNormal];
    [self.switchButton addTarget:self action:@selector(switchButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.switchButton.hidden = NO;
    [self.view addSubview:self.switchButton];
    
    //取消按钮
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelButton setFrame:CGRectMake(30, 0, ZEPhotographButtonWidth, ZEPhotographButtonWidth)];
    self.cancelButton.layer.cornerRadius = ZEPhotographButtonWidth/2.0f;
    [self.cancelButton setImage:[UIImage imageNamed:@"cancel_button"] forState:UIControlStateNormal];
    [self.cancelButton addTarget:self action:@selector(cancelButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.cancelButton sizeToFit];
    rect = self.cancelButton.frame;
    if([self hasNotch]){
        rect.origin.y = self.view.frame.size.height - 34-44-rect.size.height;
    }else{
        rect.origin.y = self.view.frame.size.height - 44-rect.size.height;
    }
    [self.cancelButton setFrame:rect];
    self.cancelButton.hidden = YES;
    [self.view addSubview:self.cancelButton];
    //完成按钮
    self.completeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.completeButton setFrame:CGRectMake(self.view.frame.size.width - 30-ZEPhotographButtonWidth, self.cancelButton.frame.origin.y, ZEPhotographButtonWidth, ZEPhotographButtonWidth)];
    self.completeButton.layer.cornerRadius = ZEPhotographButtonWidth/2.0f;
    [self.completeButton setImage:[UIImage imageNamed:@"complete_button"] forState:UIControlStateNormal];
    [self.completeButton addTarget:self action:@selector(completeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.completeButton sizeToFit];
    self.completeButton.hidden = YES;
    [self.view addSubview:self.completeButton];
    //编辑按钮
    self.editButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.editButton setFrame:self.photographButton.frame];
    self.editButton.layer.cornerRadius = ZEPhotographButtonWidth/2.0f;
    [self.editButton setImage:[UIImage imageNamed:@"edit_image_button"] forState:UIControlStateNormal];
    [self.editButton addTarget:self action:@selector(editButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.editButton sizeToFit];
    self.editButton.hidden = YES;
    [self.view addSubview:self.editButton];
}

- (void)setupSettings{
    //captureSession
    self.captureSession = [[AVCaptureSession alloc] init];
    
    //视频
    self.videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.videoCaptureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoCaptureDevice error:nil];
    if([self.captureSession canAddInput:self.videoCaptureDeviceInput]){
        [self.captureSession addInput:self.videoCaptureDeviceInput];
    }
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                                     forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    if([self.captureSession canAddOutput:self.videoDataOutput]){
        [self.captureSession addOutput:self.videoDataOutput];
    }
    
    //音频
    self.audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    self.audioCaptureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.audioCaptureDevice error:nil];
    if([self.captureSession canAddInput:self.audioCaptureDeviceInput]){
        [self.captureSession addInput:self.audioCaptureDeviceInput];
    }
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    if([self.captureSession canAddOutput:self.audioDataOutput]){
        [self.captureSession addOutput:self.audioDataOutput];
    }

    __weak typeof(self) weakself = self;
    //拍照
    self.photographManager = [[ZEPhotographManager alloc] initWithCaptureSession:^AVCaptureSession *{
        return weakself.captureSession;
    } captureDevice:^AVCaptureDevice *{
        return weakself.videoCaptureDevice;
    } captureOutput:^AVCaptureVideoDataOutput *{
        return weakself.videoDataOutput;
    } photographComplete:^(UIImage * _Nullable image) {
        [weakself updateUIForImage:image];
        [weakself restoreUI];
    }];
    
    //录视频
    self.recordingManager = [[ZERecordingManager alloc] initWithCaptureSession:^AVCaptureSession *{
        return weakself.captureSession;
    } captureDevice:^AVCaptureDevice *{
        return weakself.videoCaptureDevice;
    } captureVideoOutput:^AVCaptureVideoDataOutput *{
        return weakself.videoDataOutput;
    } captureAudioOutput:^AVCaptureAudioDataOutput *{
        return weakself.audioDataOutput;
    } recordingComplete:^(AVPlayerLayer *displayLayer, NSURL * _Nullable videoURL,ZERecordingFailType failType) {
        switch(failType){
            case ZERecordingFailTypeNone:{
                [weakself updateUIForVideo:videoURL withDisplayLayer:displayLayer];
                break;
            }
            case ZERecordingFailTypeExceedMaxDuration:{
                [weakself.longPressRecognizer setState:UIGestureRecognizerStateEnded];
                break;
            }
            case ZERecordingFailTypeTooShort:{
                [weakself updateUIForVideo:nil withDisplayLayer:nil];
                break;
            }
        }
    }];
    self.recordingManager.maxDuration = 8;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startRecordingAnimation:)
                                                 name:ZERecordingStartNotification
                                               object:nil];
    
    //previewLayer
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    [self.previewLayer setFrame:[UIScreen mainScreen].bounds];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.photographView.layer addSublayer:self.previewLayer];
    
    [self.captureSession startRunning];

}

/* 更新界面按钮显示/隐藏状态 */
- (void)updateUIForImage:(UIImage *)photographedImage{
    if(photographedImage){//拍照完成后的预览界面
        CGRect photographButtonRect = self.photographButton.frame;
        CGRect  cancelButtonRect = self.cancelButton.frame;
        CGRect completeButtonRect = self.completeButton.frame;
        
        [self.cancelButton setFrame:photographButtonRect];
        [self.completeButton setFrame:photographButtonRect];
        [UIView animateWithDuration:0.1 animations:^{
            [self.cancelButton setFrame:cancelButtonRect];
            [self.completeButton setFrame:completeButtonRect];
        }];
    }else{//拍照界面
        CGRect photographButtonRect = self.photographButton.frame;
        CGRect  cancelButtonRect = self.cancelButton.frame;
        CGRect completeButtonRect = self.completeButton.frame;
        [UIView animateWithDuration:0.1 animations:^{
            [self.cancelButton setFrame:photographButtonRect];
            [self.completeButton setFrame:photographButtonRect];
        } completion:^(BOOL finished) {
            [self.cancelButton setFrame:cancelButtonRect];
            [self.completeButton setFrame:completeButtonRect];
        }];
    }
    
    self.exitButton.hidden = (photographedImage != nil);
    self.flashButton.hidden = (photographedImage != nil);
    self.switchButton.hidden = (photographedImage != nil);
    self.photographButton.hidden = (photographedImage != nil);
    
    self.cancelButton.hidden = !self.photographButton.hidden;
    self.completeButton.hidden = !self.photographButton.hidden;
    self.editButton.hidden = !self.photographButton.hidden;
    
}

- (void)updateUIForVideo:(NSURL *)videoURL withDisplayLayer:(AVPlayerLayer *)layer{
    [self stopAnimation];
    if(videoURL){
        if(layer){
            [layer setFrame:self.previewLayer.frame];
            [self.previewLayer addSublayer:layer];
            AVPlayer *player = layer.player;
            [player play];
            
            //更新UI
            self.photographButton.hidden = YES;
            self.editButton.hidden = YES;
            
            self.exitButton.hidden = YES;
            self.flashButton.hidden = YES;
            self.switchButton.hidden = YES;
            
            self.cancelButton.hidden = NO;
            self.completeButton.hidden = NO;
            
            CGRect photographButtonRect = self.photographButton.frame;
            CGRect  cancelButtonRect = self.cancelButton.frame;
            CGRect completeButtonRect = self.completeButton.frame;
            
            [self.cancelButton setFrame:photographButtonRect];
            [self.completeButton setFrame:photographButtonRect];
            [UIView animateWithDuration:0.1 animations:^{
                [self.cancelButton setFrame:cancelButtonRect];
                [self.completeButton setFrame:completeButtonRect];
            }];
        }
    }else{
        //更新UI
        self.photographButton.hidden = NO;
        self.editButton.hidden = YES;
        
        self.exitButton.hidden = NO;
        self.flashButton.hidden = NO;
        self.switchButton.hidden = NO;
        
        self.cancelButton.hidden = YES;
        self.completeButton.hidden = YES;
        
        [self.recordingManager reset:YES];
        [self.captureSession startRunning];
        
    }
    
}

/* 点击拍照按钮后冻结UI，使按钮不可点击 */
- (void)freezeUI{
    self.photographButton.userInteractionEnabled = NO;
    self.exitButton.userInteractionEnabled = NO;
    self.flashButton.userInteractionEnabled = NO;
    self.switchButton.userInteractionEnabled = NO;
}

/* 恢复按钮状态 */
- (void)restoreUI{
    self.photographButton.userInteractionEnabled = YES;
    self.exitButton.userInteractionEnabled = YES;
    self.flashButton.userInteractionEnabled = YES;
    self.switchButton.userInteractionEnabled = YES;
}

/* 开启动画 */
- (void)startAnimation{
    CGRect rect = self.recordingProgressLayer.frame;
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(rect.size.width/2.0f, rect.size.height/2.0f) radius:rect.size.width/2.0f startAngle:-M_PI_2 endAngle:3 *M_PI_2  clockwise:YES];
    
    [self.recordingProgressLayer setLineWidth:5];
    [self.recordingProgressLayer setStrokeColor:[UIColor blueColor].CGColor];
    [self.recordingProgressLayer setFillColor:[UIColor clearColor].CGColor];
    [self.recordingProgressLayer setStrokeEnd:0.0];
    self.recordingProgressLayer.path = path.CGPath;
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    animation.duration = self.recordingManager.maxDuration-0.5;//减小时间使动画连续
    animation.fromValue = @(0.0);
    animation.toValue = @(1.0);
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    self.recordingProgressLayer.strokeEnd = 1.0;
    [self.recordingProgressLayer addAnimation:animation forKey:@"drawCircle"];
}

/* 关闭动画 */
- (void)stopAnimation{
    [self.recordingProgressLayer removeAllAnimations];
    self.recordingProgressLayer.path = nil;
}

#pragma mark - support
- (BOOL)hasNotch{
    if(@available(iOS 11.0, *)){
        return [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom > 0.0f;
    }
    return NO;
}

#pragma mark - button event
/* 退出 */
- (void)exitButtonClicked:(UIButton *)sender{
    if(self.photographDelegate && [self.photographDelegate respondsToSelector:@selector(photographCancel:)]){
        [self.photographDelegate photographCancel:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

/* 闪光灯开关 */
- (void)flashButtonClicked:(UIButton *)sender{
    [self.photographManager updateFlashStatus];

    if(self.photographManager.isFlashOn){
        [self.flashButton setImage:[UIImage imageNamed:@"flash_on_icon"] forState:UIControlStateNormal];
    }else{
        [self.flashButton setImage:[UIImage imageNamed:@"flash_off_icon"] forState:UIControlStateNormal];
    }
}

/* 切换前后镜头 */
- (void)switchButtonClicked:(UIButton *)sender{
    NSArray *devices;
    AVCaptureDevicePosition targetPosition = (self.videoCaptureDevice.position == AVCaptureDevicePositionBack?AVCaptureDevicePositionFront:AVCaptureDevicePositionBack);
    if(@available(iOS 10.0,*)){
        AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:targetPosition];
        devices = session.devices;
    }else{
        devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    }
    
    AVCaptureDevice *nDevice = nil;
    for(int i = 0;i<devices.count;++i){
        AVCaptureDevice *device = devices[i];
        if(device.position == targetPosition){
            nDevice = device;
            break;
        }
    }
    
    if(nDevice != nil){
        [self.captureSession stopRunning];
        self.videoCaptureDevice = nDevice;
        [self.captureSession removeInput:self.videoCaptureDeviceInput];
        self.videoCaptureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoCaptureDevice error:nil];
        if([self.captureSession canAddInput:self.videoCaptureDeviceInput]){
            [self.captureSession addInput:self.videoCaptureDeviceInput];
        }
        
        UIBlurEffect *effect =  [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        effectView.tag = ZEPhotographVisualEffectViewTag;
        effectView.frame = self.photographView.frame;
        [self.photographView addSubview:effectView];
        
        [UIView transitionWithView:self.photographView duration:0.3 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
        } completion:^(BOOL finished) {
            [self.captureSession startRunning];
            [[self.photographView viewWithTag:ZEPhotographVisualEffectViewTag] removeFromSuperview];
        }];
        
    }
}

/* 拍照 */
- (void)photographButtonClicked:(UIButton *)sender{
    [self freezeUI];
    [self.photographManager photograph];
}

/* 开始录制 */
- (void)startRecording:(UILongPressGestureRecognizer *)recognizer{
    switch(recognizer.state){
        case UIGestureRecognizerStateBegan:{
            [self.photographButton setImage:[UIImage imageNamed:@"photograph_button_selected"] forState:UIControlStateNormal];
            self.exitButton.hidden = YES;
            self.flashButton.hidden = YES;
            self.switchButton.hidden = YES;
            [self.recordingManager startRecording];
            break;
        }
        case UIGestureRecognizerStateChanged:{
            break;
        }
        case UIGestureRecognizerStateEnded:{
            [self stopAnimation];//这里调用是为了减少动画的延迟
            [self.photographButton setImage:[UIImage imageNamed:@"photograph_button"] forState:UIControlStateNormal];
            [self.recordingManager stopRecording];
            [self.captureSession stopRunning];
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStatePossible:{
            break;
        }
    }
}

/* 取消 */
- (void)cancelButtonClicked:(UIButton *)sender{
    [self.photographManager reset];
    [self.recordingManager reset:YES];
    
    [self.captureSession startRunning];
    
    if(self.previewImageView){
        [self.previewImageView removeFromSuperview];
        self.previewImageView = nil;
    }
    
}

/* 完成 */
- (void)completeButtonClicked:(UIButton *)sender{
    id result = nil;
    if(self.photographManager.photographedImage){
        result = self.photographManager.photographedImage;
        if(self.previewImageView){//有编辑过的图
            result = self.previewImageView.image;
        }
    }else if(self.recordingManager.videoURL){
        result = self.recordingManager.videoURL;
    }
    
    if(self.photographDelegate && [self.photographDelegate respondsToSelector:@selector(photograph:didFinishPhotographing:)]){
        [self.photographDelegate photograph:self didFinishPhotographing:result];
    }
    
    [self.photographManager reset];
    [self.recordingManager reset:NO];
    
    [self dismissViewControllerAnimated:YES completion:nil];

    
}

/* 编辑 */
- (void)editButtonClicked:(UIButton *)sender{
    ZEEditView *editView = [[ZEEditView alloc] initWithFrame:self.photographView.frame imageToEdit:self.photographManager.photographedImage editedData:self.photographManager.editedData];
    __weak typeof(self) weakself = self;
    editView.editComplete = ^(UIImage * _Nonnull editedImage, NSDictionary * _Nonnull editedData) {
        if(!weakself.previewImageView){
            weakself.previewImageView = [[UIImageView alloc] initWithFrame:weakself.view.frame];
            [weakself.photographView addSubview:weakself.previewImageView];
        }
        weakself.previewImageView.image = editedImage;
        weakself.photographManager.editedData = [editedData copy];
    };
    
    [self.view addSubview:editView];
}

#pragma mark - Notification
- (void)startRecordingAnimation:(NSNotification *)notification{
    [self startAnimation];
}

- (void)dealloc{
    [self.photographButton removeGestureRecognizer:self.longPressRecognizer];
    self.longPressRecognizer = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
