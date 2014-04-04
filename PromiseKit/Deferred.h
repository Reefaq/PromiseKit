@import Foundation.NSArray;
@import Foundation.NSError;
@import Foundation.NSObject;
@class Promise;


@interface Deferred : NSObject
- (void)resolve:(id)obj;
- (void)resolveWithObjects:(NSArray *)objs;
- (void)reject:(NSError *)err;

@property (nonatomic, readonly) Promise *promise;
@end
