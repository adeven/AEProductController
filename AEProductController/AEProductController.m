//
//  AEProductController.m
//  AEProductController
//
//  Created by Christian Wellenbrock on 15.11.12.
//  Copyright (c) 2012 adeven. All rights reserved.
//

#import "AEProductController.h"
#import "AFNetworking.h"
#import "AELogger.h"
#import <StoreKit/StoreKit.h>

@interface AEProductController() <SKStoreProductViewControllerDelegate>

@property (copy) NSString *productId;
@property (copy) NSString *callbackUrl;
@property (retain) AELogger *logger;

@end


@implementation AEProductController

+ (BOOL)isAvailable {
    BOOL available = (NSClassFromString(@"SKStoreProductViewController") != nil);
    return available;
}

- (id)initWithProductId:(NSString *)product callbackUrl:(NSString *)callback {
    self = [super init];
    if (self == nil) return nil;

    self.productId = product;
    self.callbackUrl = callback;
    self.logger = [AELogger loggerWithTag:@"AEProductController" enabled:YES];

    return self;
}

+ (AEProductController *)controllerWithProductId:(NSString *)productId callbackUrl:(NSString *)callbackUrl {
    return [[[AEProductController alloc] initWithProductId:productId callbackUrl:callbackUrl] autorelease];
}

- (void)showInViewController:(UIViewController *)viewController {
    BOOL available = self.class.isAvailable;
    __block NSURL *lastUrl;
    
    // Execute the callback and follow all redirects
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.callbackUrl]];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [operation setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        lastUrl = request.URL;
        if (redirectResponse == nil) {
            [self.logger log:@"Callback started: %@", lastUrl.absoluteString];
        } else {
            [self.logger log:@"Callback redirected to: %@", lastUrl.absoluteString];
        }
        return request;
    }];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (available) {
            [self.logger log:@"Callback finished."];
        } else {
            if ([lastUrl.host isEqualToString:@"itunes.apple.com"]) {
                [self.logger log:@"Opening iTunes URL externally."];
                [[UIApplication sharedApplication] openURL:lastUrl];
            } else {
                [self.logger log:@"Callback didn't lead to iTunes URL."];
            }
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self.logger log:[NSString stringWithFormat:@"Callback failed. %@", error]];
    }];
    [operation start];

    if (available) {
        // Prepare the product view controller by providing the product ID.
        SKStoreProductViewController *productViewController = [[[SKStoreProductViewController alloc] init] autorelease];
        productViewController.delegate = self;
        NSDictionary *storeParameters = [NSDictionary dictionaryWithObject:self.productId forKey:SKStoreProductParameterITunesItemIdentifier];
        
        // Present the product view controller
        [viewController presentViewController:productViewController animated:YES completion:^(void) {
            [self.logger log:@"Presented product view controller."];
        }];
        
        // Try to load the product and dismiss the product view controller in case of failure
        [productViewController loadProductWithParameters:storeParameters completionBlock:^(BOOL result, NSError *error) {
            if (result) {
                [self.logger log:@"Presented product: %@", self.productId];
            } else {
                [self.logger log:@"Failed to load product: %@", error];
            }
        }];
    }
}

// SKStoreProductViewControllerDelegate method that dismisses the product view controller
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:^{
        [self.logger log:@"Dismissed product view controller."];
    }];
}

@synthesize productId;
@synthesize callbackUrl;

@end
