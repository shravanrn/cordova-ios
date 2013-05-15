/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVDataResourceUrlProtocol.h"
#import "CDVViewController.h"

#pragma mark declare

@interface DataResourceNSURLProtocol : NSURLProtocol
{
    NSURLRequest* currentRequest;
}
-(BOOL)tryDefaultLoadForRequest:(NSURLRequest*)request withResponseCallback:(void(^)(NSURLResponse*))responseCallback withDataCallback:(void(^)(NSData*))dataCallback withFinishedCallback:(void(^)(void))finishedCallback;
@end

static NSMutableArray* implementingClasses;

#pragma mark DataResourceNSURLProtocol

@implementation DataResourceNSURLProtocol

__attribute__((constructor))
static void initializeNSURLProtocolRegistration() {
    [NSURLProtocol registerClass:[DataResourceNSURLProtocol class]];
}

+ (BOOL)canInitWithRequest:(NSURLRequest*)request
{
    // Do any of the registered handlers have special handling for this request.
    for(Class implementingClass in implementingClasses){
        if([implementingClass performSelector:@selector(willModifyRequest:) withObject:request] ||
           [implementingClass performSelector:@selector(willHandleRequest:) withObject:request]){
            return YES;
        }
    }
    return NO;
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)request
{
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest*)requestA toRequest:(NSURLRequest*)requestB
{
    // Play safe by not caching
    return NO;
}

- (void)startLoading
{
    currentRequest = [self request];
    BOOL repeat = YES;
    int MAX_REPETITIONS = 1000;
    int repetitions = 0;

    // See if registered classes want to modify the request in any way
    while (repeat && repetitions < MAX_REPETITIONS) {
        repeat = NO;
        for(Class implementingClass in implementingClasses){
            if([implementingClass performSelector:@selector(willModifyRequest:) withObject:currentRequest]){
                CDVDataResourceUrlProtocol* registeredClassInstance = [implementingClass new];
                NSURLRequest* modifiedRequest = [registeredClassInstance modifyRequest:currentRequest];
                if(modifiedRequest != nil){
                    currentRequest = modifiedRequest;
                    repeat = YES;
                    break;
                }
            }
        }
    }

    __block BOOL responseReceived = NO;

    void(^onResponseReceived)(NSURLResponse*) = ^(NSURLResponse* response){
        responseReceived = YES;
        [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    };
    void(^onNSDataReceived)(NSData*) = ^(NSData* data){
        // may be called repeatedly with blocks of data
        if(!responseReceived){
            NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[currentRequest URL] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
            [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        }
        [[self client] URLProtocol:self didLoadData:data];
    };
    void(^onFinish)(void) = ^{
        [[self client] URLProtocolDidFinishLoading:self];
    };

    BOOL handled = NO;
    // Now we go through the handling stage.
    // Check if any plugin wants to handle this particular request
    for(Class implementingClass in implementingClasses){
        if([implementingClass performSelector:@selector(willHandleRequest:) withObject:currentRequest]){
            CDVDataResourceUrlProtocol* registeredClassInstance = [implementingClass new];
            [registeredClassInstance handleRequest:currentRequest withResponseCallback:onResponseReceived withDataCallback:onNSDataReceived withFinishedCallback:onFinish];
            handled = YES;
            break;
        }
    }

    if(!handled) {
        // No class handles it. Try the default handler
        handled = [self tryDefaultLoadForRequest:currentRequest withResponseCallback:onResponseReceived withDataCallback:onNSDataReceived withFinishedCallback:onFinish];
    }

    if(!handled){
        // We should not reach this stage. If the startLoading function is called, it means we are capable of handling the request
        NSLog(@"Error - could not load the request : %@", currentRequest.description);
    }
}

- (void)stopLoading
{

}

// The default loader. Currently handles only file requests. If plugins want to modify requests to http or https urls, this loader has to be extended to support those schemes.
-(BOOL)tryDefaultLoadForRequest:(NSURLRequest*)request withResponseCallback:(void(^)(NSURLResponse*))responseCallback withDataCallback:(void(^)(NSData*))dataCallback withFinishedCallback:(void(^)(void))finishedCallback
{
    NSURL *url = [request URL];

    if([[url scheme] isEqualToString:@"file"]){
        NSString *path = [url path];
        FILE *fp = fopen([path UTF8String], "r");
        if (fp) {
            NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
            responseCallback(response);

            char buf[32768];
            size_t len;
            while ((len = fread(buf,1,sizeof(buf),fp))) {
                dataCallback([NSData dataWithBytes:buf length:len]);
            }
            fclose(fp);
            finishedCallback();
        } else {
            NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:404 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
            responseCallback(response);
            finishedCallback();
        }
    }
    return NO;
}

@end

#pragma mark CDVDataResourceUrlProtocol

@implementation CDVDataResourceUrlProtocol

__attribute__((constructor))
static void initializeClassesList() {
    implementingClasses = [[NSMutableArray alloc] init];
}

+ (BOOL)registerClass:(Class)protocolClass
{
    if(![protocolClass isSubclassOfClass:[CDVDataResourceUrlProtocol class]]){
        return NO;
    }
    [implementingClasses addObject:protocolClass];
    return YES;
}

+ (BOOL)willModifyRequest:(NSURLRequest*)request
{
    return NO;
}

+ (BOOL)willHandleRequest:(NSURLRequest*)request
{
    return NO;
}

- (NSURLRequest*)modifyRequest:(NSURLRequest*)request
{
    return nil;
}

- (void)handleRequest:(NSURLRequest*)request withResponseCallback:(void(^)(NSURLResponse*))responseCallback withDataCallback:(void(^)(NSData*))dataCallback withFinishedCallback:(void(^)(void))finishedCallback
{
}

@end
