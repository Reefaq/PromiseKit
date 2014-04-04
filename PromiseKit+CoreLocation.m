#import "PromiseKit+CoreLocation.h"
#import "PromiseKit/Deferred.h"
#import "PromiseKit/Promise.h"

#define __anti_arc_retain(...) \
    void *retainedThing = (__bridge_retained void *)__VA_ARGS__; \
    retainedThing = retainedThing
#define __anti_arc_release(...) \
    void *retainedThing = (__bridge void *) __VA_ARGS__; \
    id unretainedThing = (__bridge_transfer id)retainedThing; \
    unretainedThing = nil

@interface PMKLocationManager : CLLocationManager <CLLocationManagerDelegate>
@end



@implementation PMKLocationManager {
    Deferred *deferred;
}

- (id)init {
    self = [super init];
    deferred = [Deferred new];
    return self;
}

- (Promise *)promise {
    return deferred.promise;
}

#define PMKLocationManagerCleanup() \
    [manager stopUpdatingLocation]; \
    self.delegate = nil; \
    __anti_arc_release(self);

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [deferred resolve:locations.count == 1 ? locations[0] : locations];
    PMKLocationManagerCleanup();
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [deferred reject:error];
    PMKLocationManagerCleanup();
}

@end



@implementation CLLocationManager (PromiseKit)

+ (Promise *)promise {
    PMKLocationManager *manager = [PMKLocationManager new];
    manager.delegate = manager;
    [manager startUpdatingLocation];
    __anti_arc_retain(manager);
    return manager.promise;
}

@end
