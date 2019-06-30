//
//  ZEPhotoPickerViewController.h
//  
//
//  Created by layne on 2019/6/20.
//  Copyright © 2019 layne. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger,ZEPhotoPickerMediaType){
    ZEPhotoPickerMediaTypeImage,//default
    ZEPhotoPickerMediaTypeVideo,
    ZEPhotoPickerMediaTypeAll
};

NS_ASSUME_NONNULL_BEGIN

@class ZEPhotoPickerViewController;
@protocol ZEPhotoPickerViewControllerDelegate <NSObject>

- (void)photoPicker:(ZEPhotoPickerViewController *)pickerController didFinishPickingResources:(NSArray *)resources;

- (void)photoPickerDidCancel:(ZEPhotoPickerViewController *)pickerController;

@end

@interface ZEPhotoPickerViewController : UINavigationController <UIImagePickerControllerDelegate>
@property (nonatomic, assign)NSInteger maxNumOfSelection;//max number allowed to select
@property (nonatomic, assign)ZEPhotoPickerMediaType mediaType;

- (instancetype)initWithDelegate:(id<ZEPhotoPickerViewControllerDelegate> __nullable)delegate;

@end

NS_ASSUME_NONNULL_END
