//
//  LRRLambdaConnectTools.h
//  LRRIncrementalSynchronizationDemo
//
//  Created by Marek Lipert on 02.02.2015.
//  Copyright (c) 2015 Lambdarocket. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "LRRSynchronizationOperation.h"

@interface LRRLambdaConnect : NSObject

+ (instancetype) sharedInstance;

@property(nonatomic,readonly) NSManagedObjectModel *model;
@property(nonatomic,readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property(nonatomic,readonly) NSManagedObjectContext *mainContext;

@property(nonatomic,strong) id<LRRNetworkDriverDelegate> strongDriverDelegate;
@property(nonatomic,strong) id<LRRSynchronizationConfigurationDelegate> strongConfigurationDelegate;

@property(nonatomic,assign) BOOL shouldDisplayLogs;

/** Uses default merge policy (object trump) */
- (void) setupCoreDataWithModelNamed: (NSString *)modelName databaseFileName: (NSString *)dbFileName;

- (void) setupCoreDataWithModelNamed: (NSString *)modelName databaseFileName: (NSString *)dbFileName mergePolicy: (id) mergePolicy;

- (void) forceSynchronization;

- (void) startSynchronizationWithTimeInterval: (NSTimeInterval) interval;
- (void) stopSynchronization;
- (void) saveMainContext;

@end
