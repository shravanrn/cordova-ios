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

#import <Foundation/Foundation.h>

// This class is a layer that sits on top of NSURLProtocol and provides additional functionality
// The DataResource Request works in 2 stages
// 1) Checks if any plugin wants to modify the request. This is done repeatedly until the request doesn't change
//      Example use case here - If you want foo:// to point to a file uri, you can modify the request to point to the file you want before it is loaded
// 2) Checks if any plugin wants to load that particular request. It is expected that only one loader can handle a particulear type of request. The first loader that can handle the request is used to load the data
//      Example use case here - If you want to implement the the response for gap_exec url's i.e. return empty responses so the browser doesn't throw errors
// An additional extensibility point here is the ability for classes to modify the data stream once it is loaded before it is sent to the browser
//      While this is not currently implemented, this class has been setup so that this may be added easily if needed
@interface CDVDataResourceUrlProtocol : NSObject
+ (BOOL)registerClass:(Class)protocolClass;
+ (BOOL)willModifyRequest:(NSURLRequest*)request;
+ (BOOL)willHandleRequest:(NSURLRequest*)request;
- (NSURLRequest*)modifyRequest:(NSURLRequest*)request;
- (void)handleRequest:(NSURLRequest*)request withResponseCallback:(void(^)(NSURLResponse*))responseCallback withDataCallback:(void(^)(NSData*))dataCallback withFinishedCallback:(void(^)(void))finishedCallback;
@end