//
//  ZEPhotoPickerViewController.m
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZEPhotoPickerViewController.h"
#import "ZEAssetListViewController.h"
#import "ZEAssetCollectionViewController.h"
#import "UIImage+Color.h"
#import <Photos/Photos.h>

@interface ZEPhotoPickerViewController ()
@property (nonatomic, weak)id<ZEPhotoPickerViewControllerDelegate> pickerDelegate;
@property (nonatomic, assign)BOOL authorizationChecked;//whether has checked the authorization
@end

@implementation ZEPhotoPickerViewController

#pragma mark - life
- (instancetype)initWithDelegate:(id<ZEPhotoPickerViewControllerDelegate>)delegate{
    if(self = [super init]){
        self.pickerDelegate = delegate;
        //UI
        [self.navigationBar setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithWhite:0.9 alpha:0.8] size:CGSizeZero] forBarMetrics:UIBarMetricsDefault];//transparent
        self.view.backgroundColor = [UIColor whiteColor];
        
        self.maxNumOfSelection = 1;//default
        self.mediaType = ZEPhotoPickerMediaTypeImage;
        self.authorizationChecked = NO;
    }
    return self;
}

- (instancetype)init{
    return [self initWithDelegate:nil];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    if(!self.authorizationChecked){
        self.authorizationChecked = YES;
        [self checkAuthorization];
    }
}

- (void)setupControllers{
    PHFetchResult<PHAssetCollection *> *smartAlbumResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];//All Photos
    //一般来说“All Photos”智能相册一定会有，但这里还是进行一下判断
    if(smartAlbumResult.count < 1){
        smartAlbumResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
    }
    
    ZEAssetListViewController *assetListViewController = [[ZEAssetListViewController alloc] init];//list
    ZEAssetCollectionViewController *assetCollectionViewController = [[ZEAssetCollectionViewController alloc] initWithAssetCollection:smartAlbumResult.firstObject mediaType:self.mediaType];//collection
    self.viewControllers = @[assetListViewController,assetCollectionViewController];
    
}

- (void)checkAuthorization{
    if([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined){
        __weak typeof(self) weakself = self;
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                switch(status){
                    case PHAuthorizationStatusAuthorized:{//Authorized
                        [weakself setupControllers];
                        break;
                    }
                    default:{//Denied
                        [weakself showNoAuthorizationAlert];
                        break;
                    }
                }
            });
        }];
    }else if([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized){
        [self setupControllers];
    }else{//Denied
        [self showNoAuthorizationAlert];
    }
}

- (void)showNoAuthorizationAlert{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"您未授权相册权限，请先到手机设置中开启相册权限。" preferredStyle:UIAlertControllerStyleAlert];
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

#pragma mark - event
- (void)cancelSelection{
    if(self.pickerDelegate && [self.pickerDelegate respondsToSelector:@selector(photoPickerDidCancel:)]){
        [self.pickerDelegate photoPickerDidCancel:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)completeSelection:(NSArray *)resources{
    if(self.pickerDelegate && [self.pickerDelegate respondsToSelector:@selector(photoPicker:didFinishPickingResources:)]){
        [self.pickerDelegate photoPicker:self didFinishPickingResources:resources];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc{
    self.pickerDelegate = nil;
}


@end


