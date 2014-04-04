PromiseKit aims to make dealing with assyncronicity in your iPhone app *delightful*. PromiseKit is not just a Promises implementation, it is also a collection of helper functions that make the typical asyncronous patterns we use in iOS development *delightful* too.


What is a Promise?
==================
A promise is an intent to accomplish an asyncronous task. Eg. some library promises to download a [gravatar](http://gravatar.com):

```objc
#import "PromiseKit.h"

- (void)gravatar {
    [ABCDoEverythingLibrary gravatar:myURL].then(^(UIImage *img){
        self.imageView.image = img;
    }).fail(^(NSError *error){
        NSLog(@"%@", error);
    })
}
```

The designer changes their mind (again). They want us to overlay a kitten on the gravatar:

```objc
#import "PromiseKit.h"

- (void)gravatar {
    UIImage *gravatarImage = nil;
    
    [ABCDoEverythingLibrary gravatar:myURL].then(^(UIImage *img){
        gravatarImage = img;
    }).fail(^(NSError *error){
        NSLog(@"%@", error);
    }).then(^{
        return [NSURLConnection GET:@"http://placekitten.com/100/100"];
    }).then(^(UIImage *kittenImage){
        self.imageView.image = [UIImage draw:kittenImage over:gravatarImage];
    });
}
```

Whoops we didn't handle the error for the `NSURLConnection`:

```objc
#import "PromiseKit.h"

- (void)gravatar {
    UIImage *gravatarImage = nil;
    
    [ABCDoEverythingLibrary gravatar:myURL].then(^(UIImage *img){
        gravatarImage = img;
    }).then(^{
        return [NSURLConnection GET:@"http://placekitten.com/100/100"];
    }).then(^(UIImage *kittenImage){
        self.imageView.image = [UIImage draw:kittenImage over:gravatarImage];
    }).fail(^(NSError *error){
        // moved to the end: any errors or thrown exceptions will bubble up
        NSLog(@"%@", error);
    });
}
```

We need to refactor this code so our `imageView` is set elsewhere:

```objc
#import "PromiseKit.h"

- (Promise *)gravatar {
    UIImage *gravatarImage = nil;
    
    [ABCDoEverythingLibrary gravatar:myURL].then(^(UIImage *img){
        gravatarImage = img;
    }).then(^{
        return [NSURLConnection GET:@"http://placekitten.com/100/100"];
    }).then(^(UIImage *kittenImage){
        return [UIImage draw:kittenImage over:gravatarImage];
    });
}

- (void)viewDidLoad {
    self.gravatar.then(^(UIImage *img){
        self.imageView.image = img;
    }).fail(^(NSError *error){
        [UIAlertView show:error];
    });
}
```

In production we find that `ABCDoEverythingLibrary` is a buggy, bloated mostrosity. So we hastily reinvent the wheel:

```objc
#import "PromiseKit.h"

- (Promise *)gravatar {
    UIImage *gravatarImage = nil;
    
    [Promise md5:self.email].then(^(NSString *md5){
        // The MD5 is crunched in a background GCD queue
        return [NSURLConnection GET:@"http://gravatar.com/avatar/%@", md5];
    }).then(^{
        return [NSURLConnection GET:@"http://placekitten.com/100/100"];
    }).then(^(UIImage *kittenImage){
        return [UIImage draw:kittenImage over:gravatarImage];
    });
}
```

Later we realize we’re wasting our users’ lives by downloading the two images
consequentively:

```objc
#import "PromiseKit.h"

- (Promise *)gravatar {
    UIImage *gravatarImage = nil;
    
    [Promise md5:self.email].then(^(NSString *md5){
        id a = [NSURLConnection GET:@"http://gravatar.com/avatar/%@", md5];
        id b = [NSURLConnection GET:@"http://placekitten.com/100/100"];
        return [Promise when:@[a, b]];
    }).then(^(NSArray *images){
        return [UIImage draw:images[0] over:images[1]];
    });
}
```


TODO Further Examples
---------------------
1. UIViewControllers
2. NSURLConnections
