//
//  ZEPhotoPreviewViewController.m
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZEPhotoPreviewViewController.h"
#import <Photos/Photos.h>
#import "UIImage+Color.h"
#import "ZEPhotoPickerViewController.h"
#import "ZEAssetCollectionViewController.h"
#import "ZELoadingView.h"

NSInteger const ZEPhotoPreviewStartIndex = -1;

NSInteger const ZEImageViewContainerPositionTagLeft = 10000;
NSInteger const ZEImageViewContainerPositionTagMiddle = 10001;
NSInteger const ZEImageViewContainerPositionTagRight = 10002;

NSInteger const ZEImageViewInContainerTag = 9999;//在每个scrollView中的imageView的Tag均设为此值
NSInteger const ZEPlayerSwitchViewInContainerTag = 9998;//在每个scrollView中的播放icon的Tag均设为此值

@interface ZEPhotoPreviewViewController ()<UIScrollViewDelegate,UIGestureRecognizerDelegate>
@property (nonatomic, strong)UIView *topView;//顶部功能视图
@property (nonatomic, strong)UIButton *backButton;//顶部返回按钮
@property (nonatomic, strong)UIButton *selectButton;//顶部选择按钮
@property (nonatomic, strong)UIView *bottomView;//底部功能视图
@property (nonatomic, strong)UIButton *completeButton;//完成按钮
@property (nonatomic, strong)UIScrollView *containerView;//内容scrollView

@property (nonatomic, strong)NSArray<PHAsset *> *assets;//所有asset的集合
@property (nonatomic, strong)NSMutableArray<PHAsset *> *selectedAssets;//选中的asset
@property (nonatomic, assign)NSInteger currentIndex;//当前asset在数组中的位置(assets或者selectedAssets中的位置)
@property (nonatomic, assign)NSInteger startIndex;

/* 下滑返回上一页(仿微信)原理就是：在当前的navigationController.view上增加三个view：
 * 1.上页collectionviewcontroller的快照
 * 2.一个背景view，用于显示手指移动时背景黑色渐变效果
 * 3.一个imageView,显示当前屏幕快照，随手指移动的就是它
 * 堆叠顺序为：当前控制器视图->1>2>3。手指在移动的时候，根据移动的距离，3随着手指移动并改变自己的宽高，2变换透明度，逐渐将1展示出来
 * see: [self createFakeView]
 */
@property (nonatomic, strong)UIPanGestureRecognizer *panRecognizer;//滑动手势，主要处理下滑退出预览控制器
@property (nonatomic, assign)BOOL panStarted;//pan手势开始
@property (nonatomic, assign)CGPoint panStartPosition;//pan手势开始的位置
@property (nonatomic, strong)UIImageView *fakeImageView;//下滑退出预览控制器时创建的随手指移动的假的预览控制器界面快照
@property (nonatomic, strong)UIImageView *fakePreviousView;//collectionView控制器的界面快照容器
@property (nonatomic, strong)UIImage *fakePreviousImage;//collectionView控制器的界面快照

@property (nonatomic, strong)UITapGestureRecognizer *tapRecognizer;//点击手势，处理视频的播放和暂停
@property (nonatomic, strong)AVPlayer *player;
@property (nonatomic, strong)AVPlayerLayer *playerLayer;
@property (nonatomic, strong)AVPlayerItem *playerItem;

@end

@implementation ZEPhotoPreviewViewController

- (instancetype)initWithAssets:(NSArray<PHAsset *> *)allAssets selectedAssets:(NSMutableArray *)selectedAssets startIndex:(NSInteger)index{
    if(self = [super init]){
        self.assets = allAssets;
        self.selectedAssets = selectedAssets;
        self.startIndex = index;
        [self customSettings];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if(!self.fakePreviousImage){//保存上一页的快照
        UIGraphicsBeginImageContextWithOptions(self.navigationController.view.frame.size, YES, [UIScreen mainScreen].scale);
        [self.navigationController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
        self.fakePreviousImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    [self navigationControllerSettings];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)customSettings{
    self.view.backgroundColor = [UIColor clearColor];
    
    self.containerView = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.containerView.backgroundColor = [UIColor blackColor];
    self.containerView.showsVerticalScrollIndicator = NO;
    self.containerView.showsHorizontalScrollIndicator = NO;
    self.containerView.pagingEnabled = YES;
    self.containerView.scrollEnabled = YES;
    self.containerView.delegate = self;
    [self.view addSubview:self.containerView];
    if(@available(iOS 11.0,*)){
        self.containerView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }else{
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    //顶部视图
    self.topView = [[UIView alloc] init];
    self.topView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    [self.view addSubview:self.topView];
    //返回按钮
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.backButton setImage:[UIImage imageNamed:@"back_icon_white"] forState:UIControlStateNormal];
    [self.backButton setTitle:@"  " forState:UIControlStateNormal];
    [self.backButton sizeToFit];
    [self.backButton addTarget:self action:@selector(backButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:self.backButton];
    //选择按钮
    self.selectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.selectButton setImage:[UIImage imageNamed:@"unselected_icon"] forState:UIControlStateNormal];
    [self.selectButton sizeToFit];
    [self.selectButton addTarget:self action:@selector(selectButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:self.selectButton];
    
    //bottomView
    self.bottomView = [[UIView alloc] init];
    [self.bottomView setBackgroundColor:[UIColor colorWithWhite:0.1 alpha:0.8]];
    [self.view addSubview:self.bottomView];
    //完成按钮
    self.completeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.completeButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:1 alpha:1];
    self.completeButton.layer.cornerRadius = 3;
    NSString *text = self.selectedAssets.count == 0?@"完成":[NSString stringWithFormat:@"完成(%d)",(int)self.selectedAssets.count];
    [self.completeButton setTitle:text forState:UIControlStateNormal];
    [self.completeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.completeButton.titleLabel setFont:[UIFont systemFontOfSize:14.0f]];
    [self.completeButton setContentEdgeInsets:UIEdgeInsetsMake(6, 5, 6, 5)];
    [self.completeButton sizeToFit];
    [self.completeButton addTarget:self action:@selector(completeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomView addSubview:self.completeButton];
    if([self hasNotch]){
        [self.topView setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 88)];
        [self.backButton setFrame:CGRectMake(16, 44+(44-self.backButton.frame.size.height)/2.0f, self.backButton.frame.size.width, self.backButton.frame.size.height)];
        [self.selectButton setFrame:CGRectMake(self.topView.frame.size.width-16-self.selectButton.frame.size.width,44+(44-self.selectButton.frame.size.height)/2.0f,self.selectButton.frame.size.width,self.selectButton.frame.size.height)];
        [self.bottomView setFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height-34-44, [UIScreen mainScreen].bounds.size.width, 34+44)];
    }else{
        [self.topView setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 64)];
        [self.backButton setFrame:CGRectMake(16, 20+(44-self.backButton.frame.size.height)/2.0f, self.backButton.frame.size.width, self.backButton.frame.size.height)];
        [self.selectButton setFrame:CGRectMake(self.topView.frame.size.width-16-self.selectButton.frame.size.width,20+(44-self.selectButton.frame.size.height)/2.0f,self.selectButton.frame.size.width,self.selectButton.frame.size.height)];
        [self.bottomView setFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height-44, [UIScreen mainScreen].bounds.size.width, 44)];
    }
    //添加约束
    [self.completeButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.completeButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.bottomView attribute:NSLayoutAttributeRight multiplier:1.0 constant:-16.0f]];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.completeButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.bottomView attribute:NSLayoutAttributeTop multiplier:1.0f constant:44/2.0f]];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.completeButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:60.0f]];
    [NSLayoutConstraint activateConstraints:constraints];
    
    [self addObserver:self forKeyPath:@"currentIndex" options:NSKeyValueObservingOptionNew context:nil];
    
    [self initContainerView];
    //手势
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    self.panRecognizer.delegate = self;
    self.panStarted = NO;
    [self.containerView addGestureRecognizer:self.panRecognizer];
    [self.containerView.panGestureRecognizer requireGestureRecognizerToFail:self.panRecognizer];
    
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    self.tapRecognizer.delegate = self;
    [self.containerView addGestureRecognizer:self.tapRecognizer];
    [self.panRecognizer requireGestureRecognizerToFail:self.tapRecognizer];
    
    //视频播放完成的通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(videoPlayFinished:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
}

- (void)navigationControllerSettings{
    self.navigationItem.hidesBackButton = YES;
    self.navigationController.navigationBar.hidden = YES;
}

/* 创建合适的scrollView(每个包含一个imageView) */
- (void)createContentForContainerViewFromIndex:(NSInteger)startIndex toIndex:(NSInteger)endIndex{
    for(NSInteger i = startIndex;i<endIndex;++i){
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(self.containerView.frame.size.width*i, 0, self.containerView.frame.size.width, self.containerView.frame.size.height)];
        scrollView.backgroundColor = [UIColor blackColor];
        scrollView.delegate = self;
        scrollView.maximumZoomScale = 3.0f;
        scrollView.minimumZoomScale = 1.0f;
        scrollView.showsVerticalScrollIndicator = NO;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.tag = ZEImageViewContainerPositionTagLeft+i-startIndex;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:scrollView.bounds];
        imageView.backgroundColor = [UIColor blackColor];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.userInteractionEnabled = YES;
        imageView.tag = ZEImageViewInContainerTag;
        [scrollView addSubview:imageView];
        
        UIImageView *playerSwitchView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"video_icon_large"]];
        [playerSwitchView sizeToFit];
        [playerSwitchView setCenter:CGPointMake(scrollView.frame.size.width/2.0f, scrollView.frame.size.height/2.0f)];
        playerSwitchView.tag = ZEPlayerSwitchViewInContainerTag;
        [scrollView addSubview:playerSwitchView];
        
        [self.containerView addSubview:scrollView];
        
        PHAsset *asset = self.assets[i];
        playerSwitchView.hidden = (asset.mediaType != PHAssetMediaTypeVideo);
    
        [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(1024, 1024) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
            imageView.image = result;
        }];
    }
}

- (void)initContainerView{
    [self.containerView setContentSize:CGSizeMake(self.containerView.frame.size.width * self.assets.count , self.containerView.frame.size.height)];
    
    if(self.selectedAssets.count>0 && self.startIndex == ZEPhotoPreviewStartIndex){//预览
        self.currentIndex = 0;
        NSInteger maxCount = self.assets.count<=3?self.assets.count:3;
        [self createContentForContainerViewFromIndex:0 toIndex:maxCount];
    }else{//全相册
        self.currentIndex = self.startIndex;
        NSInteger maxCount = self.assets.count<=3?self.assets.count:3;
        if(self.currentIndex == 0){//左起
            [self createContentForContainerViewFromIndex:0 toIndex:maxCount];
        }else if(self.currentIndex == self.assets.count-1){//右终
            [self createContentForContainerViewFromIndex:self.currentIndex+1-maxCount toIndex:self.currentIndex+1];
        }else{//中间，必有3个imageView
            [self createContentForContainerViewFromIndex:self.currentIndex-1 toIndex:self.currentIndex+2];
        }
        //跳到正确的页面
        [self.containerView setContentOffset:CGPointMake(self.containerView.frame.size.width * self.currentIndex, 0)];
    }
}

/* 图片个数超限的弹框 */
- (void)showExceedMaxAlert{
    ZEPhotoPickerViewController *photoPickerVC = (ZEPhotoPickerViewController *)self.navigationController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:[NSString stringWithFormat:@"你最多只能选取%ld张图片",(long)photoPickerVC.maxNumOfSelection]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"我知道了" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {}]];
    [self presentViewController:alert animated:YES completion:nil];
}

/* 更新顶部选中按钮状态及底部完成按钮上的数字统计 */
- (void)updateSelectedStatus{
    PHAsset *asset = self.assets[self.currentIndex];
    if(![self.selectedAssets containsObject:asset]){
        [self.selectButton setImage:[UIImage imageNamed:@"unselected_icon"] forState:UIControlStateNormal];
    }else{
        [self.selectButton setImage:[UIImage imageWithNumber:[self.selectedAssets indexOfObject:asset]+1] forState:UIControlStateNormal];
    }
    //更新数字统计
    NSString *text = self.selectedAssets.count == 0?@"完成":[NSString stringWithFormat:@"完成(%d)",(int)self.selectedAssets.count];
    [self.completeButton setTitle:text forState:UIControlStateNormal];
}

/* 更新imageView的图片 */
- (void)updateImagesWithTargetOffset:(CGPoint)offset{
    NSInteger targetIndex = offset.x/self.containerView.frame.size.width;
    UIImageView *leftImageView = [[self.containerView viewWithTag:ZEImageViewContainerPositionTagLeft] viewWithTag:ZEImageViewInContainerTag];
    UIImageView *rightImageView = [[self.containerView viewWithTag:ZEImageViewContainerPositionTagRight] viewWithTag:ZEImageViewInContainerTag];
    PHAsset *leftAsset = self.assets[targetIndex-1];
    PHAsset *rightAsset = self.assets[targetIndex+1];
    
    [[self.containerView viewWithTag:ZEImageViewContainerPositionTagLeft] viewWithTag:ZEPlayerSwitchViewInContainerTag].hidden = (leftAsset.mediaType != PHAssetMediaTypeVideo);
    [[self.containerView viewWithTag:ZEImageViewContainerPositionTagRight] viewWithTag:ZEPlayerSwitchViewInContainerTag].hidden = (rightAsset.mediaType != PHAssetMediaTypeVideo);
    
    [[PHImageManager defaultManager] requestImageForAsset:leftAsset targetSize:CGSizeMake(1024, 1024) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        leftImageView.image = result;
    }];
    [[PHImageManager defaultManager] requestImageForAsset:rightAsset targetSize:CGSizeMake(1024, 1024) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        rightImageView.image = result;
    }];
    
}

/* 创建假View */
- (void)createFakeView{
    //fakeImageView
    if(!self.fakeImageView){
        self.fakeImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        self.fakeImageView.userInteractionEnabled = YES;
    }else{
        [self.fakeImageView.superview removeFromSuperview];
        [self.fakeImageView removeFromSuperview];
    }
    //当前页面快照
    self.topView.hidden = YES;//隐藏顶部功能区
    self.bottomView.hidden = YES;
    UIGraphicsBeginImageContextWithOptions(self.view.frame.size, YES, [UIScreen mainScreen].scale);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    self.fakeImageView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.topView.hidden = NO;//显示顶部功能区
    self.bottomView.hidden = NO;
    
    UIView *view = [[UIView alloc] initWithFrame:self.view.frame];
    view.backgroundColor = [UIColor blackColor];
    [view addSubview:self.fakeImageView];
    
    
    //fakePreviousView
    if(!self.fakePreviousView){
        self.fakePreviousView = [[UIImageView alloc] initWithFrame:self.view.frame];
        self.fakePreviousView.userInteractionEnabled = YES;
    }else{
        [self.fakePreviousView removeFromSuperview];
    }
   
    [self.fakePreviousView setImage:self.fakePreviousImage];
    [self.navigationController.view addSubview:self.fakePreviousView];
    [self.navigationController.view addSubview:view];

}

/* 销毁假的View */
- (void)resetFakeView{
    [self.fakePreviousView removeFromSuperview];
    self.fakePreviousView = nil;
    [self.fakeImageView.superview removeFromSuperview];
    [self.fakeImageView removeFromSuperview];
    self.fakeImageView = nil;
}

#pragma mark - play video
- (void)createVideoPlayer:(PHAsset *)asset{
    __weak typeof(self) weakself = self;
    [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:nil resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakself.playerItem = playerItem;
            [weakself.playerItem addObserver:weakself forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
            weakself.player = [AVPlayer playerWithPlayerItem:weakself.playerItem];
            [weakself.player addObserver:weakself forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
            weakself.playerLayer = [AVPlayerLayer playerLayerWithPlayer:weakself.player];
            [weakself.playerLayer setFrame:weakself.view.frame];
        });
        
    }];
}

- (void)resetVideoPlayer{
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    if(self.player){
        [self.player removeObserver:self forKeyPath:@"rate" context:nil];
    }
    self.player = nil;
    if(self.playerItem){
        [self.playerItem removeObserver:self forKeyPath:@"status" context:nil];
    }
    self.playerItem=nil;
    
    //视频类型显示播放按钮
    PHAsset *asset = self.assets[self.currentIndex];
    if(asset.mediaType == PHAssetMediaTypeVideo){
        [self showPlayerSwitchView:YES];
    }else{
        [self showPlayerSwitchView:NO];
    }
    
}

- (void)play{
    if(!self.playerLayer.superlayer){
        CGFloat offset = self.containerView.frame.size.width * self.currentIndex;
        UIScrollView *currentScrollView = nil;
        for(UIScrollView *scrollView in self.containerView.subviews){
            if(scrollView.frame.origin.x == offset){
                currentScrollView = scrollView;
                break;
            }
        }
        if(currentScrollView){
            [currentScrollView.layer insertSublayer:self.playerLayer below:[currentScrollView viewWithTag:ZEPlayerSwitchViewInContainerTag].layer];
        }
        
    }
    if(self.player){
        [self.player play];
    }
}

- (void)pause{
    if(self.player){
        [self.player pause];
    }
}

- (void)showPlayerSwitchView:(BOOL)show{
    CGFloat offset = self.containerView.frame.size.width * self.currentIndex;
    UIScrollView *currentScrollView = nil;
    for(UIScrollView *scrollView in self.containerView.subviews){
        if(scrollView.frame.origin.x == offset){
            currentScrollView = scrollView;
            break;
        }
    }
    
    if(currentScrollView){
        [currentScrollView viewWithTag:ZEPlayerSwitchViewInContainerTag].hidden = !show;
    }
}

#pragma mark - notification
- (void)videoPlayFinished:(NSNotification *)notification{
    [self.playerItem seekToTime:kCMTimeZero];//回到原点
}

#pragma mark - pan recognizer
- (void)pan:(UIPanGestureRecognizer *)recognizer{
    CGPoint velocity = [recognizer velocityInView:[UIApplication sharedApplication].keyWindow];
    if(!self.panStarted){//初始
        if(velocity.y<=0){//向上
            if(fabs(velocity.y)<fabs(velocity.x)){//主要水平滑动，则禁掉自定义的手势
                if(self.assets.count>1){//仅有一张图片的情况下，scrollView的delegate方法不会走，自定义手势无法恢复；因此只在多于一张图片的情况下禁掉手势
                    self.panRecognizer.enabled = NO;
                }
            }
            return;
        }else{//向下
            if(fabs(velocity.y)<fabs(velocity.x)){//主要水平滑动,则禁掉自定义的手势
                if(self.assets.count>1){
                    self.panRecognizer.enabled = NO;
                }
                return;
            }
        }

    }
    
    switch(recognizer.state){
        case UIGestureRecognizerStateBegan:{
            self.panStarted = YES;
            [self resetVideoPlayer];
            self.panStartPosition = [recognizer locationInView:[UIApplication sharedApplication].keyWindow];//点击的位置
            [self createFakeView];
            self.topView.hidden = YES;
            self.bottomView.hidden = YES;
        }
        case UIGestureRecognizerStateChanged:{
            NSInteger distance = [recognizer locationInView:[UIApplication sharedApplication].keyWindow].y-self.panStartPosition.y;
            CGRect rect = self.fakeImageView.frame;
            CGFloat alpha = 1;
            if(distance > 0){
                alpha = 1 -  distance/[UIScreen mainScreen].bounds.size.height;
            }else{
                alpha = 1;
            }
            [self.fakeImageView.superview setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:alpha]];
            rect.size.width = [UIScreen mainScreen].bounds.size.width * alpha;
            rect.size.height = [UIScreen mainScreen].bounds.size.height * alpha;
            rect.origin.y = [recognizer locationInView:[UIApplication sharedApplication].keyWindow].y-self.panStartPosition.y*alpha;
            rect.origin.x = [recognizer locationInView:[UIApplication sharedApplication].keyWindow].x-self.panStartPosition.x*alpha;
            [self.fakeImageView setFrame:rect];

            break;
        }
        case UIGestureRecognizerStateEnded:{
            self.panStarted = NO;
            CGPoint endPoint = [recognizer locationInView:[UIApplication sharedApplication].keyWindow];
            CGFloat bottomPosition = [UIScreen mainScreen].bounds.size.height-60;
            if(endPoint.y<bottomPosition){//恢复
                self.topView.hidden = NO;
                self.bottomView.hidden = NO;
                [UIView animateWithDuration:0.3 animations:^{
                    [self.fakeImageView setFrame:self.view.frame];
                    [self.fakeImageView.superview setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:1.0]];
                } completion:^(BOOL finished) {
                    [self resetFakeView];
                }];
            
            }else{//退出当前控制器
                if(self.postionForAsset){
                    CGRect rect = self.postionForAsset(self.assets[self.currentIndex]);
                    if(rect.size.width != 0 && rect.size.height != 0){
                        [UIView animateWithDuration:0.3 animations:^{
                            [self.fakeImageView setFrame:rect];
                        } completion:^(BOOL finished) {
                            [self resetFakeView];
                        }];
                    }else{
                         [self resetFakeView];
                    }
                }else{
                     [self resetFakeView];
                }
            
                [self.navigationController popViewControllerAnimated:NO];
            }
            
            break;
        }
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:{
            self.panStarted = NO;
            [self resetFakeView];
            self.topView.hidden = NO;
            self.bottomView.hidden = NO;
            break;
        }
    }
}

- (void)tap:(UITapGestureRecognizer *)recognizer{
    PHAsset *asset = self.assets[self.currentIndex];
    if(asset.mediaType == PHAssetMediaTypeVideo){//视频类型自己管理topView和bottomView的显示
        if(self.playerItem){
            if(self.player.rate == 0.0){//当前为暂停状态，则开始播放
                [self play];
            }else{//当前为播放状态，则暂停
                [self pause];
            }
        }else{
            [self createVideoPlayer:asset];
        }
    }else{//图片
        self.topView.hidden = !self.topView.hidden;
        self.bottomView.hidden = !self.bottomView.hidden;
    }
    
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([object isKindOfClass:[self class]] && [keyPath isEqualToString:@"currentIndex"]){
        [self updateSelectedStatus];
    }else if([object isKindOfClass:[AVPlayerItem class]] && [keyPath isEqualToString:@"status"]){
        switch(self.playerItem.status){
            case AVPlayerItemStatusReadyToPlay:{
                [self play];
                break;
            }
            case AVPlayerItemStatusUnknown:
            case AVPlayerItemStatusFailed:{
                [self resetVideoPlayer];
                break;
            }
        }
    }else if([object isKindOfClass:[AVPlayer class]] && [keyPath isEqualToString:@"rate"]){
        float rate = [change[NSKeyValueChangeNewKey] floatValue];
        if(rate == 0.0){
            float currentTime = ceil(self.playerItem.currentTime.value * 1.0f/self.playerItem.currentTime.timescale);
            if(currentTime == 0.0){//end
                [self resetVideoPlayer];
            }
            self.topView.hidden = NO;
            self.bottomView.hidden = NO;
            [self showPlayerSwitchView:YES];
        }else{//播放
            self.topView.hidden = YES;
            self.bottomView.hidden = YES;
            [self showPlayerSwitchView:NO];
        }
    }
}

#pragma mark - support
/* 是否有刘海屏 */
- (BOOL)hasNotch{
    if(@available(iOS 11.0, *)){
        return [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom > 0.0f;
    }
    return NO;
}

#pragma mark - button event
/* 返回 */
- (void)backButtonClicked:(UIButton *)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

/* 选择/取消选择 */
- (void)selectButtonClicked:(UIButton *)sender{
    PHAsset *asset = self.assets[self.currentIndex];
    if([self.selectedAssets containsObject:asset]){//选中->未选中
        [self.selectedAssets removeObject:asset];
    }else{//未选中->选中
        ZEPhotoPickerViewController *picker = (ZEPhotoPickerViewController *)self.navigationController;
        if(self.selectedAssets.count>=picker.maxNumOfSelection){
            [self showExceedMaxAlert];
            return;
        }else{
            [self.selectedAssets addObject:asset];//排在最后
        }
    }
    //更新UI
    [self updateSelectedStatus];
    if(self.updateViewsBlock){
        self.updateViewsBlock();
    }
}

/* 完成 */
- (void)completeButtonClicked:(UIButton *)sender{
    [ZELoadingView showToView:self.view withText:@"正在处理..."];
    if(self.completeSelectionBlock){
        if(self.selectedAssets.count>0){
            self.completeSelectionBlock(self.selectedAssets);
        }else{
            self.completeSelectionBlock(@[self.assets[self.currentIndex]]);
        }
    }
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    self.panRecognizer.enabled = YES;//滑动结束之后恢复自定义手势
    if(scrollView != self.containerView){//放大缩小的scrollView不处理
        return;
    }
    UIScrollView *imageViewContainer0 = [self.containerView viewWithTag:ZEImageViewContainerPositionTagLeft];
    UIScrollView *imageViewContainer1 = [self.containerView viewWithTag:ZEImageViewContainerPositionTagMiddle];
    UIScrollView *imageViewContainer2 = [self.containerView viewWithTag:ZEImageViewContainerPositionTagRight];
    //一定有imageViewContainer0，但不一定有imageViewContainer2
    if(CGPointEqualToPoint(*targetContentOffset, CGPointMake(imageViewContainer0.frame.origin.x, 0))){
        if(imageViewContainer0.frame.origin.x != 0){
            [imageViewContainer2 setFrame:CGRectMake((*targetContentOffset).x-self.containerView.frame.size.width, 0, imageViewContainer2.frame.size.width, imageViewContainer2.frame.size.height)];
            imageViewContainer0.tag = ZEImageViewContainerPositionTagMiddle;//通过更改tag，保证左边的imageView的tag值为10000，中间的为10001，右边的为10002
            imageViewContainer1.tag = ZEImageViewContainerPositionTagRight;
            imageViewContainer2.tag = ZEImageViewContainerPositionTagLeft;
            [self updateImagesWithTargetOffset:*targetContentOffset];
        }
    }else if(imageViewContainer2 && CGPointEqualToPoint(*targetContentOffset, CGPointMake(imageViewContainer2.frame.origin.x, 0))){
        if(imageViewContainer2.frame.origin.x != self.containerView.contentSize.width-self.containerView.frame.size.width){
            [imageViewContainer0 setFrame:CGRectMake(self.containerView.frame.size.width+(*targetContentOffset).x, 0, imageViewContainer0.frame.size.width, imageViewContainer0.frame.size.height)];
            imageViewContainer0.tag = ZEImageViewContainerPositionTagRight;
            imageViewContainer1.tag = ZEImageViewContainerPositionTagLeft;
            imageViewContainer2.tag = ZEImageViewContainerPositionTagMiddle;
            [self updateImagesWithTargetOffset:*targetContentOffset];
        }
    }
    
    self.currentIndex = (*targetContentOffset).x/self.containerView.frame.size.width;
    
    [self resetVideoPlayer];//滑动之后重置
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{
    if(scrollView != self.containerView){
        PHAsset *asset = self.assets[self.currentIndex];
        if(asset.mediaType == PHAssetMediaTypeVideo){//video不允许缩放
            return nil;
        }
        return [scrollView viewWithTag:ZEImageViewInContainerTag];
    }
    return nil;
}

#pragma mark - UIGestureRecognizerDelegate
/* 保证containerView自带的pan手势和自定的pan手势可以共存 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if(otherGestureRecognizer == self.containerView.panGestureRecognizer){
        return YES;
    }
    return NO;
}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"currentIndex"];
    [self.containerView removeGestureRecognizer:self.panRecognizer];
    [self.containerView removeGestureRecognizer:self.tapRecognizer];
    self.panRecognizer = nil;
    self.tapRecognizer = nil;
    
    [self resetVideoPlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    
}

@end
