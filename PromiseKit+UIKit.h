@import UIKit.UIViewController;
@class Promise;
@class Deferred;



@interface UIViewController (PromiseKit)

// presents with a promise
// when you resolve the controller’s deferred we will dismiss the controller
// the dismissal will occur when the promise is resolved, so if you need
// the dismissal of the controller to occur later, instead chain another
// promise before resolving this deferred
- (Promise *)promiseViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void(^)(void))block;

//TODO
// When PromiseKit is loaded, this will always be called
// If you also have a viewDidLoad, it will be called first
//- (void)viewDidLoad:(Deferred *)deferred;

- (void)viewWillDefer:(Deferred *)deferMe;

@end
