//
//  ZELoadingView.m
//  
//
//  Created by Layne on 2019/6/29.
//  Copyright © 2019 layne. All rights reserved.
//

#import "ZELoadingView.h"

@interface ZELoadingView ()
@property (nonatomic, strong)UIView *HUD;
@end

@implementation ZELoadingView

+ (ZELoadingView *)showToView:(UIView *)view withText:(NSString *)message{
    ZELoadingView *loadingView = [[ZELoadingView alloc] initWithParentView:view text:message];
    [view addSubview:loadingView];
    return loadingView;
}

+ (void)hideFromView:(UIView *)view{
    for(UIView *sView in view.subviews){
        if([sView isKindOfClass:[self class]]){
            [sView removeFromSuperview];
            break;
        }
    }
}

- (instancetype)initWithParentView:(UIView *)view text:(NSString *)message{
    if(self = [super initWithFrame:view.bounds]){
        self.backgroundColor = [UIColor clearColor];
        //屏幕中心的HUD
        self.HUD = [[UIView alloc] initWithFrame:CGRectMake((self.frame.size.width-120)/2.0f, (self.frame.size.height-120)/2.0f, 120, 120)];
        self.HUD.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5];
        self.HUD.layer.cornerRadius = 10;
        [self addSubview:self.HUD];
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(35, 20, 50, 50)];
        [indicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [indicator startAnimating];
        UILabel *tipLabel = [[UILabel alloc] init];
        [tipLabel setFont:[UIFont systemFontOfSize:18.0f]];
        [tipLabel setTextColor:[UIColor whiteColor]];
        [tipLabel setText:(message && message.length>0)?message:@"加载中..."];
        [tipLabel sizeToFit];
        CGRect rect = tipLabel.frame;
        rect.origin.x = (120-rect.size.width)/2;
        rect.origin.y = 120-20-rect.size.height;
        [tipLabel setFrame:rect];
        [self.HUD addSubview:tipLabel];
        [self.HUD addSubview:indicator];
    }
    return self;
}


@end
