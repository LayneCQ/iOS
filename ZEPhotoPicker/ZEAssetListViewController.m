//
//  ZEAssetListViewController.m
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZEAssetListViewController.h"
#import "ZEAssetListCell.h"
#import <Photos/Photos.h>
#import "ZEAssetCollectionViewController.h"
#import "ZEPhotoPickerViewController.h"
#import "ZELoadingView.h"

NSString *const ZEAssetListCellIdentifier = @"ZEAssetListCellID";

@interface ZEAssetListViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong)UITableView *listView;
@property (nonatomic, strong)NSMutableArray<PHAssetCollection *> *assetCollections;

@property (nonatomic, assign)BOOL hasLoadedAssets;
@end

@implementation ZEAssetListViewController

#pragma mark - life
- (instancetype)init{
    if(self = [super init]){
        [self customSettings];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self navigationControllerSettings];
    if(!self.hasLoadedAssets){
        [ZELoadingView showToView:self.view withText:@"加载中..."];
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if(!self.hasLoadedAssets){
        [self loadAssets];
    }
    
}

- (void)customSettings{
    //UI
    self.view.backgroundColor = [UIColor whiteColor];
    self.listView = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.listView.backgroundColor = [UIColor whiteColor];
    self.listView.dataSource = self;
    self.listView.delegate = self;
    self.listView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self registerCells];
    [self.view addSubview:self.listView];
    
    self.title = @"照片";
    
    //data
    self.assetCollections = [NSMutableArray array];
    self.hasLoadedAssets = NO;
 
}

- (void)navigationControllerSettings{
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [cancelButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelButton.titleLabel setFont:[UIFont systemFontOfSize:16.0f]];
    [cancelButton sizeToFit];
    [cancelButton addTarget:self action:@selector(cancelButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
}

- (void)registerCells{
    [self.listView registerClass:[ZEAssetListCell class] forCellReuseIdentifier:ZEAssetListCellIdentifier];
}

- (void)loadAssets{
    self.hasLoadedAssets = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PHFetchResult<PHAssetCollection *> *albumResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];

        PHFetchResult<PHAssetCollection *> *smartAlbumResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
        
        for(PHFetchResult<PHAssetCollection *> *result in @[smartAlbumResult,albumResult]){
            for(int i = 0;i<result.count;++i){
                PHAssetCollection *assetCollection = (PHAssetCollection *)result[i];
                if(assetCollection.assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumUserLibrary){//"All Photos" shows on Top
                    [self.assetCollections insertObject:assetCollection atIndex:0];
                }else{
                    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:assetCollection options:[self fetchOptions]];
                    if(assets.count>0){//过滤掉空的collection
                        [self.assetCollections addObject:assetCollection];
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
             [ZELoadingView hideFromView:self.view];
             [self.listView reloadData];
        });
    });
}

- (PHFetchOptions *)fetchOptions{
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    ZEPhotoPickerViewController *picker = (ZEPhotoPickerViewController *)self.navigationController;
    switch(picker.mediaType){
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

#pragma mark - button event
- (void)cancelButtonClicked:(UIButton *)sender{
    ZEPhotoPickerViewController *photoPickerVC = (ZEPhotoPickerViewController *)self.navigationController;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [photoPickerVC performSelector:@selector(cancelSelection)];
#pragma clang diagnostic pop
    
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.assetCollections.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    ZEAssetListCell *cell = [self.listView dequeueReusableCellWithIdentifier:ZEAssetListCellIdentifier forIndexPath:indexPath];
    
    PHAssetCollection *collection = self.assetCollections[indexPath.row];
    
    PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsInAssetCollection:collection options:[self fetchOptions]];
    PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    [[PHImageManager defaultManager] requestImageForAsset:assets.lastObject targetSize:CGSizeMake(180, 180) contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        [cell updateWithImage:result collectionName:collection.localizedTitle assetCount:assets.count];
    }];
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return ZEAssetListCellHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.listView deselectRowAtIndexPath:indexPath animated:YES];
    
    ZEPhotoPickerViewController *picker = (ZEPhotoPickerViewController *)self.navigationController;
    ZEAssetCollectionViewController *collectionVC = [[ZEAssetCollectionViewController alloc] initWithAssetCollection:self.assetCollections[indexPath.row] mediaType:picker.mediaType];
    [self.navigationController pushViewController:collectionVC animated:YES];
    
}

- (void)dealloc{
    [self.assetCollections removeAllObjects];
    self.assetCollections = nil;
}

@end
