#import "BTViewController.h"

@implementation BTViewController

- (void)didReceiveMemoryWarning {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:flag ? UIStatusBarAnimationSlide : NO];
    [super presentViewController:viewControllerToPresent animated:flag completion:completion];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    [super dismissViewControllerAnimated:flag completion:completion];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:flag ? UIStatusBarAnimationSlide : NO];
}

@end
