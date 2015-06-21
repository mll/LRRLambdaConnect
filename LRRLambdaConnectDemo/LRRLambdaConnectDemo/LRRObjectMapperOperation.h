//
//  LRRObjectMapper.h
//  LRRLambdaConnectDemo
//
//  Created by Marek Lipert on 14/05/15.
//  Copyright (c) 2015 Lambdarocket. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LRRSynchronizationConfigurationDelegate.h"
#import <CoreData/CoreData.h>
#import "LRRLambdaConnect.h"

@interface LRRObjectMapperOperation : NSOperation

/// Configuration delegate. Must be set before scheduling.
@property(atomic, weak) id <LRRSynchronizationConfigurationDelegate> configurationDelegate;
/// Persistent store coordinator to be used, must be set before scheduling.
@property(atomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
/// Error message
@property(atomic, strong, readonly) NSError *error;
/// UserInfo, might be useful to transfer some data between different methods that have this as their argument.
@property(atomic, strong) NSDictionary *userInfo;

/// Merge policy to be used by operation's context. If nil - default is used (store trump)
@property(atomic, strong) NSMergePolicy *mergePolicy;
/// If set to yes, detailed debugging info will be logged through NSLog
@property(atomic, assign) BOOL shouldDisplayLogs;


@end
