@import UIKit.UINavigationController;
#import "PromiseKit/Deferred.h"
#import "PromiseKit/Promise.h"
#import "PromiseKit+UIKit.h"


static char PromiseKitDeferredKey;


@implementation UIViewController (PromiseKit)

- (Promise *)promiseViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void(^)(void))block {
    [self presentViewController:vc animated:animated completion:block];

    if ([vc isKindOfClass:[UINavigationController class]])
        vc = [(id)vc viewControllers].firstObject;

    Deferred *d = [Deferred new];
    [vc viewWillDefer:d];

    return d.promise.then(^(id o){
        [self dismissViewControllerAnimated:animated completion:nil];
        return o;
    });
}

- (void)viewWillDefer:(Deferred *)deferred {
    NSLog(@"Base implementation of viewWillDefer: called, you probably want to override this.");
}

@end
