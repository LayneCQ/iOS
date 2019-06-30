//
//  ZEAssetCollectionViewController.m
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZEAssetCollectionViewController.h"
#import <Photos/Photos.h>
#import "ZEAssetCollectionCell.h"
#import "UIImage+Color.h"
#import "ZEPhotoPreviewViewController.h"
#import "ZELoadingView.h"

NSString* const ZEAssetCollectionCellIdentifier = @"ZEAssetCollectionCellID";
NSInteger const ZEAssetCollectionCellCountInSingleLine = 4;//单行cell个数
NSInteger const ZEAssetCollectionCellActionViewDefaultHeight = 44;//底部功能区高度

@interface ZEAssetCollectionViewController ()<UICollectionViewDelegate, UICollectionViewDataSource>
@property (nonatomic, strong)UICollectionView *assetCollectionView;
@property (nonatomic, strong)UIButton *previewButton;//预览
@property (nonatomic, strong)UIButton *originalButton;//原图
@property (nonatomic, strong)UIButton *completeButton;//完成

@property (nonatomic, strong)PHAssetCollection *assetCollection;
@property (nonatomic, strong)NSMutableArray *assets;
@property (nonatomic, assign)BOOL useOriginal;//使用原图

@property (nonatomic, strong)NSMutableArray *selectedAssets;//选择的assets
@property (nonatomic, assign)ZEPhotoPickerMediaType mediaType;

@property (nonatomic, strong)dispatch_queue_t handleSelectedResourcesQueue;//处理选择的资源的队列


@end

@implementation ZEAssetCollectionViewController

- (instancetype)initWithAssetCollection:(PHAssetCollection *)assetCollection mediaType:(ZEPhotoPickerMediaType)type{
    if(self = [super init]){
        self.assetCollection = assetCollection;
        self.mediaType = type;
        [self customSettings];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self navigationControllerSettings];
    
}

- (void)customSettings{
    self.view.backgroundColor = [UIColor whiteColor];
    //collectionView
    UICollectionViewFlowLayout *viewLayout= [[UICollectionViewFlowLayout alloc] init];
    viewLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    CGFloat viewHeight = [UIScreen mainScreen].bounds.size.height-ZEAssetCollectionCellActionViewDefaultHeight;
    CGFloat topInset = 64;
    if([self hasNotch]){
        viewHeight = [UIScreen mainScreen].bounds.size.height-ZEAssetCollectionCellActionViewDefaultHeight-34;
        topInset = 88;
    }
    self.assetCollectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, viewHeight) collectionViewLayout:viewLayout];
    self.assetCollectionView.contentInset = UIEdgeInsetsMake(topInset, 0, 0, 0);
    self.assetCollectionView.backgroundColor = [UIColor whiteColor];
    if(@available(iOS 11.0,*)){
        self.assetCollectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }else{
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    self.assetCollectionView.alwaysBounceVertical = YES;
    self.assetCollectionView.dataSource = self;
    self.assetCollectionView.delegate = self;
    [self.view addSubview:self.assetCollectionView];
    [self registerCells];
    
    [self initializeData];
    
    if(self.assets.count>0){
        [self.assetCollectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:self.assets.count-1 inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:YES];//locate at bottom
    }
    
    //底部功能按钮
    CGFloat actionViewHeight = ZEAssetCollectionCellActionViewDefaultHeight;
    if([self hasNotch]){
        actionViewHeight+=34;
    }
    UIView *actionView = [[UIView alloc] initWithFrame:CGRectMake(0, self.assetCollectionView.frame.origin.y+self.assetCollectionView.frame.size.height, [UIScreen mainScreen].bounds.size.width, actionViewHeight)];
    [actionView setBackgroundColor:[UIColor colorWithWhite:0.2 alpha:1]];
    [self.view addSubview:actionView];
    //预览
    self.previewButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.previewButton setTitle:@"预览" forState:UIControlStateNormal];
    [self.previewButton.titleLabel setFont:[UIFont systemFontOfSize:16.0f]];
    [self.previewButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.previewButton setTitleColor:[UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateDisabled];
    self.previewButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.previewButton sizeToFit];
    [self.previewButton setFrame:CGRectMake(16, 0, 60, ZEAssetCollectionCellActionViewDefaultHeight)];
    [self.previewButton addTarget:self action:@selector(previewButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [actionView addSubview:self.previewButton];
    //原图
    if(self.mediaType != ZEPhotoPickerMediaTypeVideo){
        self.originalButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.originalButton setFrame:CGRectMake(0, 0, 60, ZEAssetCollectionCellActionViewDefaultHeight)];
        [self.originalButton setTitle:@"原图" forState:UIControlStateNormal];
        [self.originalButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.originalButton.titleLabel setFont:[UIFont systemFontOfSize:14.0f]];
        [self.originalButton setImage:[UIImage imageNamed:@"original_unselected"] forState:UIControlStateNormal];
        [self.originalButton setImageEdgeInsets:UIEdgeInsetsMake(0, -2, 0, 2)];
        [self.originalButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 2, 0, -2)];
        self.originalButton.center = CGPointMake(actionView.center.x, ZEAssetCollectionCellActionViewDefaultHeight/2.0f);
        [self.originalButton addTarget:self action:@selector(originalButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        [actionView addSubview:self.originalButton];
    }
    
    //完成
    self.completeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.completeButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:1 alpha:1];
    self.completeButton.layer.cornerRadius = 3;
    [self.completeButton setTitle:@"完成(0)" forState:UIControlStateNormal];
    [self.completeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.completeButton setTitleColor:[UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateDisabled];
    [self.completeButton.titleLabel setFont:[UIFont systemFontOfSize:14.0f]];
    [self.completeButton setContentEdgeInsets:UIEdgeInsetsMake(6, 5, 6, 5)];
    [self.completeButton sizeToFit];
    self.completeButton.center = CGPointMake(actionView.center.x, ZEAssetCollectionCellActionViewDefaultHeight/2.0f);
    [self.completeButton addTarget:self action:@selector(completeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    CGRect rect = self.completeButton.frame;
    rect.origin.x = [UIScreen mainScreen].bounds.size.width-16-rect.size.width;
    [self.completeButton setFrame:rect];
    [actionView addSubview:self.completeButton];
    //添加约束
    [self.completeButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.completeButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:actionView attribute:NSLayoutAttributeRight multiplier:1.0 constant:-16.0f]];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.completeButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:actionView attribute:NSLayoutAttributeTop multiplier:1.0f constant:ZEAssetCollectionCellActionViewDefaultHeight/2.0f]];
    [constraints addObject: [NSLayoutConstraint constraintWithItem:self.completeButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:60.0f]];
    [NSLayoutConstraint activateConstraints:constraints];
    
    //data
    self.useOriginal = NO;
    self.selectedAssets = [NSMutableArray array];
    self.handleSelectedResourcesQueue = dispatch_queue_create("HandleSelectionResourcesQueue", DISPATCH_QUEUE_CONCURRENT);
    
    [self updateActionView];
    
}

- (void)navigationControllerSettings{
    self.title = self.assetCollection.localizedTitle;
    
    //back
    UIButton *leftButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [leftButton setTitle:@"  " forState:UIControlStateNormal];
    [leftButton setImage:[UIImage imageNamed:@"back_icon"] forState:UIControlStateNormal];
    [leftButton addTarget:self action:@selector(backButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [leftButton sizeToFit];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
    //cancel
    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [rightButton setTitle:@"取消" forState:UIControlStateNormal];
    [rightButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [rightButton.titleLabel setFont:[UIFont systemFontOfSize:16.0f]];
    [rightButton sizeToFit];
    [rightButton addTarget:self action:@selector(cancelButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:rightButton];
    
}

- (void)registerCells{
    [self.assetCollectionView registerClass:[ZEAssetCollectionCell class] forCellWithReuseIdentifier:ZEAssetCollectionCellIdentifier];
}

/* 初始化数据 */
- (void)initializeData{
    self.assets = [NSMutableArray arrayWithCapacity:0];
    PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsInAssetCollection:self.assetCollection options:[self fetchOptions]];
    for(int i = 0;i<result.count;++i){
        PHAsset *asset = result[i];
        [self.assets addObject:asset];
    }
}

- (PHFetchOptions *)fetchOptions{
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    switch(self.mediaType){
        case ZEPhotoPickerMediaTypeImage:{
            options.predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"mediaType==%d",(int)PHAssetMediaTypeImage]];
            break;
        }
        case ZEPhotoPickerMediaTypeVideo:{
            options.predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"mediaType==%d",(int)PHAssetMediaTypeVideo]];
            break;
        }
        case ZEPhotoPickerMediaTypeAll:{
            options = nil;
            break;
        }
    }
    return options;
}

- (void)updateActionView{
    self.previewButton.enabled = self.selectedAssets.count > 0;
    self.completeButton.enabled = self.selectedAssets.count > 0;
    
    [self.completeButton setTitle:[NSString stringWithFormat:@"完成(%ld)",self.selectedAssets.count] forState:UIControlStateNormal];
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

/* 处理点击“完成”事件，获取图片/视频，视频返回为视频地址 */
- (void)handleCompleteEvent:(NSArray<PHAsset *> *)assets{
    dispatch_async(self.handleSelectedResourcesQueue, ^{
        NSMutableArray *resArray = [NSMutableArray array];
        for(PHAsset *assetTmp in assets){
            if(assetTmp.mediaType == PHAssetMediaTypeImage){//图片
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.synchronous = YES;
                options.networkAccessAllowed = YES;
                CGSize targetSize = CGSizeZero;
                if(self.useOriginal){
                    options.resizeMode = PHImageRequestOptionsResizeModeNone;
                    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
                    targetSize = PHImageManagerMaximumSize;
                }else{
                    options.resizeMode = PHImageRequestOptionsResizeModeFast;
                    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
                    targetSize = CGSizeMake(1024,1024);
                }
                [[PHImageManager defaultManager] requestImageForAsset:assetTmp targetSize:targetSize contentMode:PHImageContentModeDefault options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                    [resArray addObject:[result fixOrentation]];
                }];
            }else if(assetTmp.mediaType == PHAssetMediaTypeVideo){
                PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
                options.version = PHVideoRequestOptionsVersionOriginal;
                options.networkAccessAllowed = YES;
                options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
                //使用信号量实现同步执行
                dispatch_semaphore_t sema = dispatch_semaphore_create(0);
                [[PHImageManager defaultManager] requestAVAssetForVideo:assetTmp options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                        if([asset isKindOfClass:[AVURLAsset class]]){//有可能为AVComposition
                            AVURLAsset *urlAsset = (AVURLAsset *)asset;
                            [resArray addObject:urlAsset.URL];
                        }
                    dispatch_semaphore_signal(sema);
                }];
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ZEPhotoPickerViewController *photoPickerVC = (ZEPhotoPickerViewController *)self.navigationController;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            [photoPickerVC performSelector:@selector(completeSelection:) withObject:resArray];
#pragma clang diagnostic pop
        });
    });
    
    
}

#pragma mark - setter
- (void)setUseOriginal:(BOOL)useOriginal{
    _useOriginal = useOriginal;
    UIImage *icon = useOriginal?[UIImage imageNamed:@"original_selected"]:[UIImage imageNamed:@"original_unselected"];
    [self.originalButton setImage:icon forState:UIControlStateNormal];
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
- (void)backButtonClicked:(UIButton *)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

/* 取消 */
- (void)cancelButtonClicked:(UIButton *)sender{
    ZEPhotoPickerViewController *photoPickerVC = (ZEPhotoPickerViewController *)self.navigationController;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [photoPickerVC performSelector:@selector(cancelSelection)];
#pragma clang diagnostic pop
    
}

/* 原图 */
- (void)originalButtonClicked:(UIButton *)sender{
    self.useOriginal = !self.useOriginal;
}

/* 预览 */
- (void)previewButtonClicked:(UIButton *)sender{
    ZEPhotoPreviewViewController *previewVC = [[ZEPhotoPreviewViewController alloc] initWithAssets:[self.selectedAssets copy] selectedAssets:self.selectedAssets startIndex:ZEPhotoPreviewStartIndex];
    __weak typeof(self) weakself = self;
    previewVC.updateViewsBlock = ^{
        [weakself.assetCollectionView reloadItemsAtIndexPaths:[weakself.assetCollectionView indexPathsForVisibleItems]];
        [weakself updateActionView];
    };
    previewVC.postionForAsset = ^CGRect(PHAsset * _Nonnull asset) {
        NSInteger index = [weakself.assets indexOfObject:asset];
        ZEAssetCollectionCell *cell = (ZEAssetCollectionCell *)[weakself.assetCollectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        return [weakself.assetCollectionView convertRect:cell.frame toView:weakself.navigationController.view];
    };
    previewVC.completeSelectionBlock = ^(NSArray<PHAsset *> * _Nonnull selected) {
        [weakself handleCompleteEvent:selected];
    };
    [self.navigationController pushViewController:previewVC animated:YES];
}

/* 完成 */
- (void)completeButtonClicked:(UIButton *)sender{
    [ZELoadingView showToView:self.view withText:@"正在处理..."];
    [self handleCompleteEvent:self.selectedAssets];
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.assets.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    ZEAssetCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:ZEAssetCollectionCellIdentifier forIndexPath:indexPath];
    
    PHAsset *asset = self.assets[indexPath.row];
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    __weak typeof(self) weakself = self;
    ZEPhotoPickerViewController *picker = (ZEPhotoPickerViewController *)weakself.navigationController;
    NSInteger maxNumOfSelection = picker.maxNumOfSelection;//最多可选图片数量
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:CGSizeMake(150, 150) contentMode:PHImageContentModeAspectFill options:options resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        int duration = -1;
        if(asset.mediaType == PHAssetMediaTypeVideo){
            duration = ceil(asset.duration);
        }
        
        if([weakself.selectedAssets containsObject:asset]){
            [cell updateWithImage:result selectedOrder:[weakself.selectedAssets indexOfObject:asset]+1 isBlur:NO videoDuration:duration];
        }else{
            [cell updateWithImage:result selectedOrder:ZEAssetCollectionCellUnselectedOrder isBlur:(weakself.selectedAssets.count >= maxNumOfSelection) videoDuration:duration];
        }
        
    }];
    cell.indexPathRow = indexPath.row;
    cell.selection = ^NSInteger{
        NSInteger cellOrder = ZEAssetCollectionCellUnselectedOrder;
        if([weakself.selectedAssets containsObject:asset]){
            if(weakself.selectedAssets.count >= maxNumOfSelection){
                [[NSNotificationCenter defaultCenter] postNotificationName:ZEAssetCollectionCellChangeBlurNotification object:nil];
            }//取消模糊效果
            [weakself.selectedAssets removeObject:asset];
            NSMutableArray *reloadIndexes = [NSMutableArray array];//刷新序号
            for(PHAsset *assetTmp in weakself.selectedAssets){
                NSInteger position = [weakself.assets indexOfObject:assetTmp];
                [reloadIndexes addObject:[NSIndexPath indexPathForRow:position inSection:0]];
            }
            [weakself.assetCollectionView reloadItemsAtIndexPaths:reloadIndexes];
            cellOrder = ZEAssetCollectionCellUnselectedOrder;
        }else{
            if(weakself.selectedAssets.count >= maxNumOfSelection){//超过可选最大数量
                [weakself showExceedMaxAlert];
                cellOrder = ZEAssetCollectionCellUnselectedOrder;
            }else{
                [weakself.selectedAssets addObject:asset];
                if(weakself.selectedAssets.count >= maxNumOfSelection){//若超过上限则启动模糊效果
                    NSMutableArray *selectedIndexes = [NSMutableArray array];
                    for(PHAsset *ast in weakself.selectedAssets){
                        [selectedIndexes addObject:@([weakself.assets indexOfObject:ast])];
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:ZEAssetCollectionCellChangeBlurNotification object:selectedIndexes];
                }

                cellOrder = weakself.selectedAssets.count;
            }
        }

        [weakself updateActionView];
        return cellOrder;
    };
    return cell;
}

#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    ZEPhotoPreviewViewController *previewVC = [[ZEPhotoPreviewViewController alloc] initWithAssets:[self.assets copy] selectedAssets:self.selectedAssets startIndex:indexPath.row];
    __weak typeof(self) weakself = self;
    previewVC.updateViewsBlock = ^{
        [weakself.assetCollectionView reloadItemsAtIndexPaths:[weakself.assetCollectionView indexPathsForVisibleItems]];
        [weakself updateActionView];
    };
    previewVC.postionForAsset = ^CGRect(PHAsset * _Nonnull asset) {
        NSInteger index = [weakself.assets indexOfObject:asset];
        ZEAssetCollectionCell *cell = (ZEAssetCollectionCell *)[weakself.assetCollectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        return [weakself.assetCollectionView convertRect:cell.frame toView:weakself.navigationController.view];
    };
    previewVC.completeSelectionBlock = ^(NSArray<PHAsset *> * _Nonnull selected) {
        [weakself handleCompleteEvent:selected];
    };
    [self.navigationController pushViewController:previewVC animated:YES];
}

#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    return CGSizeMake(screenWidth/ZEAssetCollectionCellCountInSingleLine, screenWidth/ZEAssetCollectionCellCountInSingleLine);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
    
}

- (void)dealloc{
    self.assetCollection = nil;
    [self.assets removeAllObjects];
}

@end
