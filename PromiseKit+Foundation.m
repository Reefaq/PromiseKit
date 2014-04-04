#import "Chuzzle.h"
@import CoreFoundation.CFString;
@import CoreFoundation.CFURL;
@import Foundation.NSJSONSerialization;
@import Foundation.NSOperation;
@import Foundation.NSURL;
@import Foundation.NSURLError;
@import Foundation.NSURLResponse;
#import "PromiseKit/Deferred.h"
#import "PromiseKit+Foundation.h"



static NSString *enc(NSString *in) {
    return (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(
            NULL,
            (__bridge CFStringRef)in,
            NULL,
            CFSTR("!*'();:@&=+$,/?%#[]"),
            kCFStringEncodingUTF8);
}

static BOOL NSHTTPURLResponseIsJSON(NSHTTPURLResponse *rsp) {
    NSString *type = rsp.allHeaderFields[@"Content-Type"];
    NSArray *bits = [type componentsSeparatedByString:@";"];
    return [bits.chuzzle containsObject:@"application/json"];
}

static BOOL NSHTTPURLResponseIsImage(NSHTTPURLResponse *rsp) {
    NSString *type = rsp.allHeaderFields[@"Content-Type"];
    NSArray *bits = [type componentsSeparatedByString:@";"];
    for (NSString *bit in bits) {
        if ([bit isEqualToString:@"image/jpeg"]) return YES;
        if ([bit isEqualToString:@"image/png"]) return YES;
    };
    return NO;
}

static NSDictionary *NSDictionaryExtend(NSDictionary *add, NSMutableDictionary *base) {
    base = base.mutableCopy;
    [base addEntriesFromDictionary:add];
    return base;
}

NSString *NSDictionaryToURLQueryString(NSDictionary *params) {
    if (!params.chuzzle)
        return nil;
    NSMutableString *query = [NSMutableString new];
    for (NSString *key in params) {
        NSString *value = [params objectForKey:key];
        [query appendFormat:@"%@=%@&", enc(key.description), enc(value.description)];
    }
    [query deleteCharactersInRange:NSMakeRange(query.length-1, 1)];
    return query;
}


@implementation NSURLConnection (PromiseKit)

+ (Promise *)GET:(id)url {
    return [self GET:url query:nil];
}

+ (Promise *)GET:(id)url query:(NSDictionary *)params {
    if (params.chuzzle) {
        if ([url isKindOfClass:[NSURL class]])
            url = [url absoluteString];
        id query = NSDictionaryToURLQueryString(params);
        url = [NSString stringWithFormat:@"%@?%@", url, query];
    }
    if ([url isKindOfClass:[NSString class]])
        url = [NSURL URLWithString:url];

    return [self send:[NSURLRequest requestWithURL:url]];
}

+ (Promise *)send:(NSURLRequest *)rq {
    #define PMKURLErrorWithCode(x) \
        [NSError errorWithDomain:NSURLErrorDomain code:x userInfo:NSDictionaryExtend(@{PMKURLErrorFailingURLResponse: rsp}, error.userInfo)]

    Deferred *deferred = [Deferred new];
    [NSURLConnection sendAsynchronousRequest:rq queue:[NSOperationQueue currentQueue] completionHandler:^(id rsp, id data, NSError *error) {
        if (error) {
            [deferred reject:rsp ? PMKURLErrorWithCode(error.code) : error];
        } else if ([rsp statusCode] != 200) {
            [deferred reject:PMKURLErrorWithCode(NSURLErrorBadServerResponse)];
        } else if (NSHTTPURLResponseIsJSON(rsp)) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                id error = nil;
                id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error)
                        [deferred reject:error];
                    else
                        [deferred resolve:json];
                });
            });
#ifdef UIKIT_EXTERN
        } else if (NSHTTPURLResponseIsImage(rsp)) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImage *image = [[UIImage alloc] initWithData:data];
                image = [[UIImage alloc] initWithCGImage:[image CGImage] scale:image.scale orientation:image.imageOrientation];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (image)
                        [deferred resolve:image];
                    else
                        [deferred reject:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:nil]];
                });
            });
#endif
        } else {
            [deferred resolve:data];
        }
    }];
    return deferred.promise;
}

@end
