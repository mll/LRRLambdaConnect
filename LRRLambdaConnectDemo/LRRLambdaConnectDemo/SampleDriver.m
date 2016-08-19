//
//  MLLSampleDriver.m
//  LRRLambdaConnectDemo
//
//  Created by Marek Lipert on 02.02.2015.
//  Copyright (c) 2013-2016 Spinney. All rights reserved.
//

#import "SampleDriver.h"

@implementation SampleDriver





#pragma mark - MLLNetworkDriverDelegate

- (NSError *)sendPushData:(NSDictionary *)data operation: (LRSynchronizationOperation *)operation context:(NSManagedObjectContext *)context
{
    NSError *error = nil;
    NSURLResponse *response = nil;
    
    NSData *resData = [NSURLConnection sendSynchronousRequest:[self requestURLWithBaseURL:@"www.my_sync_address.com/push" parameters:data method:@"POST"] returningResponse:&response error:&error];
    return error;
}


- (NSDictionary *)receivePullForData:(NSDictionary *)message error:(NSError * __autoreleasing *)error operation: (LRSynchronizationOperation *)operation context:(NSManagedObjectContext *)context
{
    NSURLResponse *response = nil;
    
    NSData *resData = [NSURLConnection sendSynchronousRequest:[self requestURLWithBaseURL:@"www.my_sync_address.com/pull" parameters:message method:@"POST"] returningResponse:&response error:error];

    if(error) return @{};
    return [NSJSONSerialization JSONObjectWithData:resData options:0 error:error];
}

#pragma mark - Helpers

- (NSMutableURLRequest *) requestURLWithBaseURL:(NSString *)baseURL parameters:(NSDictionary *)parameters method: (NSString *)method
{
    NSError *error = nil;
    
    NSMutableString *resultString = [NSMutableString stringWithString:baseURL];
    NSMutableURLRequest *request = nil;
    if([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"])
    {
        request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:resultString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10];
        [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error]];
    }
    else
    {
        [resultString appendFormat:@"?"];
        for(NSString *key in parameters){
            
            [resultString appendFormat:@"%@=%@&", key, [parameters objectForKey:key]];
        }
        resultString = [NSMutableString stringWithString:[resultString substringToIndex:[resultString length]-1]];
        [resultString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:resultString] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10];
    }
    NSAssert(!error,@"Error: %@",error);
    NSAssert(request,@"No request");
    request.timeoutInterval = 10;
    [request setHTTPMethod:method];
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    request.cachePolicy = NSURLCacheStorageNotAllowed;
    NSLog(@"Creating request for %@",request);
    NSLog(@"Request params: %@", [[NSString alloc]initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
    return request;
}

@end
