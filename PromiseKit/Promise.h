@import Foundation.NSArray;
@import Foundation.NSError;
@import Foundation.NSObject;


@interface Promise : NSObject
- (Promise *(^)(id))then;        // onsuccess
- (Promise *(^)(id))chug;        // then, but in a background thread
- (Promise *(^)(id))yolo;        // then & fail, type will be NSError when was from fail()
- (Promise *(^)(NSError *))fail; // @catch, but for promises

/**
 Returns a promise that is fulfilled when all the promises
 passed in the array are fulfilled. If any of the promises
 fail then the returned promise is failed. Thus the usual
 way to process a when is with a yolo() so you can decide
 how to proceed next
**/
+ (Promise *)when:(NSArray *)promises;

/**
 Repeats the fail block of the returned promise forever
 the promises passed in all succeed. You can exit the
 loop by throwing inside the error handler, or failing
 any promise you return from there.
**/
+ (Promise *)until:(NSArray *)promises;

@end


#define PMKErrorDomain @"PMKErrorDomain"
#define PMKThrown @"PMKThrown"
