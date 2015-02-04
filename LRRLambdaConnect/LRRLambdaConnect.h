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

/** 
  * Mother singleton for LambdaConnect, manages CoreData stack and schedules synchronization operations 
*/

@interface LRRLambdaConnect : NSObject

/// Singleton access
+ (instancetype) sharedInstance;
/// Managed object model
@property(nonatomic,readonly) NSManagedObjectModel *model;
/// Persistent store coordinator
@property(nonatomic,readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
/// Primary managed object context associated with the main thread
@property(nonatomic,readonly) NSManagedObjectContext *mainContext;
/// This variable holds network driver object to be used by operations.
@property(nonatomic,strong) id<LRRNetworkDriverDelegate> strongDriverDelegate;
/// Configuration object to be passed to operations
@property(nonatomic,strong) id<LRRSynchronizationConfigurationDelegate> strongConfigurationDelegate;
/// Indicates if the operation should use NSLog to display debugging information
@property(nonatomic,assign) BOOL shouldDisplayLogs;

/**
  * Setups core data stack. Primary context uses object trump merge policy.
  * @param modelName  Name of model file to be searched for in the application bundle
  * @param dbFileName Name of the database file. If not found, would be created.
 */
- (void) setupCoreDataWithModelNamed: (NSString *)modelName databaseFileName: (NSString *)dbFileName;

/**
 * Setups core data stack.
 * @param modelName  Name of model file to be searched for in the application bundle
 * @param dbFileName Name of the database file. If not found, would be created.
 * @param mergePolicy Merge policy to be used by primary context. If set to nil, default merge policy (object trump) is used
 */
- (void) setupCoreDataWithModelNamed: (NSString *)modelName databaseFileName: (NSString *)dbFileName mergePolicy: (id) mergePolicy;
/** 
  * This method immediately executes one synchronization cycle 
  */
- (void) forceSynchronization;
/**
 * This method schedules periodic synchronization
 * @param interval Time interval (in seconds) between consecutive synchronizations.
 */
- (void) startSynchronizationWithTimeInterval: (NSTimeInterval) interval;
/**
 * This method disables periodic synchronization
 */
- (void) stopSynchronization;
/**
 * This is an easy snipplet to save main context, one can use standard core data methods instead
 */
- (void) saveMainContext;

@end
