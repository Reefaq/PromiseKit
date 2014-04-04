@import Foundation.NSDictionary;
@import Foundation.NSException;
@import Foundation.NSMethodSignature;
@import Foundation.NSNull;
@import Foundation.NSPointerArray;
#import "PromiseKit/Promise.h"
#import "PromiseKit/Deferred.h"
#import "NSMethodSignatureForBlock.m"
#import "assert.h"

#define NSErrorWithThrown(e) [NSError errorWithDomain:PMKErrorDomain code:1 userInfo:@{PMKThrown: e}]

/**TODO
 + NSProgress rather than normal promise progress system
 + then() can take a Promise ?
 + test that returning a promise from its own chain is not destructive
 + warn if a Deferred is returned? Or just process to promise.
 **/

static id voodoo(id frock, id result) {
    if (!frock)
        @throw @"PromiseKit: Internal error!";

    NSMethodSignature *sig = NSMethodSignatureForBlock(frock);
    const uint nargs = sig.numberOfArguments;
    const char rtype = sig.methodReturnType[0];

    if (nargs == 2 && rtype == 'v') {
        void (^block)(id) = frock;
        block(result);
        return [NSNull null];
    }
    if (nargs == 1 && rtype == 'v') {
        void (^block)(void) = frock;
        block();
        return [NSNull null];
    }
    if (nargs == 2) {
        id (^block)(id) = frock;
        return block(result);
    }
    else {
        id (^block)(void) = frock;
        return block();
    }
}



@implementation Promise {
@public
    NSMutableArray *thens;
    NSMutableArray *fails;
    id result;
}

- (instancetype)init {
    thens = [NSMutableArray new];
    fails = [NSMutableArray new];
    return self;
}


static void RecursiveResolve(Promise *promise) {
    if (!promise)
        return;

    assert(promise->result);
    assert(![promise->result isKindOfClass:[NSError class]]);

    for (Promise *(^processThenAndReturnNextPromise)(BOOL) in promise->thens) {
        Promise *nextPromise = processThenAndReturnNextPromise(NO);
        if ([nextPromise->result isKindOfClass:[NSError class]])
            RecursiveReject(nextPromise);
        else if (![nextPromise->result isKindOfClass:[Promise class]])
            RecursiveResolve(nextPromise);
    }
}

static void RecursiveReject(Promise *promise) {
    if (!promise)
        return;

//    assert(promise->result);
//    assert([promise->result isKindOfClass:[NSError class]]);

    if (promise->fails.count) for (Promise *(^block)(void) in promise->fails) {
        Promise *nextPromise = block();
        if (nextPromise->result == [NSNull null])
            return;  // done!
        if ([nextPromise->result isKindOfClass:[NSError class]])
            @throw @"Throwing upwards not yet supported";
        else if (![nextPromise->result isKindOfClass:[Promise class]]) {
            RecursiveResolve(nextPromise);
        }
    }
    else for (Promise *(^block)(BOOL) in promise->thens)
        RecursiveReject(block(YES));
}

static void ProcessPromiseBlock(id block, id result, Promise *nextPromise) {
    Promise *resultForNextPromise = voodoo(block, result);
    nextPromise->result = resultForNextPromise;

    if ([resultForNextPromise isKindOfClass:[Promise class]]) {
        resultForNextPromise.then(^(id o){
            nextPromise->result = o;
            RecursiveResolve(nextPromise);
        }).fail(^(id o){
            nextPromise->result = o;
            RecursiveReject(nextPromise);
        });
    }
}

- (Promise *(^)(id))then {
    return ^(id block) {
        Promise const * const nextPromise = [Promise new];
        if (result) {
            // promise is already resolved: process `block` immediately
            if (![result isKindOfClass:[NSError class]])
                nextPromise->result = voodoo(block, result);
        } else {
            [thens addObject:^id(BOOL earlyExit){
                if (nextPromise->result || earlyExit)
                    return nextPromise;   // block already processed
                @try {
                    ProcessPromiseBlock(block, result, nextPromise);
                } @catch (id e) {
                    if (![e isKindOfClass:[NSError class]])
                        e = NSErrorWithThrown(e);
                    nextPromise->result = e;
                }
                return nextPromise;
            }];
        }
        return nextPromise;
    };
}

- (Promise *(^)(id))fail {
    return ^(id block) {
        Promise *nextPromise = [Promise new];
        if (result) {
            nextPromise->result = voodoo(block, result);
        } else {
            [fails addObject:^{
                ProcessPromiseBlock(block, result, nextPromise);
                return nextPromise;
            }];
        }
        return nextPromise;
    };
}

- (Promise *(^)(id))yolo {
    return ^(id block) {
        Promise *nextPromise = [Promise new];
        id process = ^(id o){
            ProcessPromiseBlock(block, result, nextPromise);
        };
        self.then(process);
        self.fail(process);
        return nextPromise;
    };
}

+ (Promise *)when:(NSArray *)promises {
    Deferred *d = [Deferred new];

    NSPointerArray *results = [NSPointerArray strongObjectsPointerArray];
    results.count = promises.count;

    __block int x = 0;
    for (Promise *promise in promises) {
        promise.yolo(^(id o){
            NSUInteger ii = [promises indexOfObject:promise];
            [results replacePointerAtIndex:ii withPointer:(__bridge void *)o];
            if (++x == promises.count) {
                for (id result in results.allObjects)
                    if ([result isKindOfClass:[NSError class]]) {
                        [d reject:results.allObjects];
                        return;
                    }
                [d resolve:results.allObjects];
            }
        });
    }

    return d.promise;
}

@end



@implementation Deferred

- (instancetype)init {
    promise = [Promise new];
    return self;
}

- (void)resolve:(id)value {
    if (promise->result)
        return NSLog(@"PromiseKit: Deferred already rejected or resolved!");
    if (!value)
        value = [NSNull null];

    promise->result = value;
    RecursiveResolve(promise);
}

- (void)reject:(NSError *)error {
    if (promise->result)
        return NSLog(@"PromiseKit: Deferred already rejected or resolved!");
    if (!error)
        error = [NSNull null];
    if (![error isKindOfClass:[NSError class]])
        error = NSErrorWithThrown(error);

    promise->result = error;
    RecursiveReject(promise);
}

@synthesize promise;
@end
