#import "BTViewController.h"

@implementation BTViewController

- (void)didReceiveMemoryWarning {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

//-(BOOL)shouldAutorotate {
//    return YES;
//}
//
//-(NSInteger)supportedInterfaceOrientations{
//    NSInteger orientationMask = 0;
//    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationLandscapeLeft])
//        orientationMask |= UIInterfaceOrientationMaskLandscapeLeft;
//    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationLandscapeRight])
//        orientationMask |= UIInterfaceOrientationMaskLandscapeRight;
//    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationPortrait])
//        orientationMask |= UIInterfaceOrientationMaskPortrait;
//    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationPortraitUpsideDown])
//        orientationMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
//    return orientationMask;
//}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:flag ? UIStatusBarAnimationSlide : NO];
    [super presentViewController:viewControllerToPresent animated:flag completion:completion];
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    [super dismissViewControllerAnimated:flag completion:completion];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:flag ? UIStatusBarAnimationSlide : NO];
}

@end
