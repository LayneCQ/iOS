# Usage
```objective-c
- (IBAction)buttonClick:(id)sender {
    ZEPhotoPickerViewController *pickerVC = [[ZEPhotoPickerViewController alloc] initWithDelegate:self];
    pickerVC.maxNumOfSelection = 10;
    pickerVC.mediaType = ZEPhotoPickerMediaTypeAll;
    [self presentViewController:pickerVC animated:YES completion:nil];
    
}

#pragma mark - ZEPhotoPickerViewControllerDelegate
- (void)photoPicker:(ZEPhotoPickerViewController *)pickerController didFinishPickingResources:(NSArray *)resources{
    NSLog(@"selected:%@",resources);
}

- (void)photoPickerDidCancel:(ZEPhotoPickerViewController *)pickerController{
    NSLog(@"Cancel");
}
```

