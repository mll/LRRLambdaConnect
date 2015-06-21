//
//  MLSynchronizationOperation.h
//  Core Data integration test
//
//  Created by Marek Lipert on 06.04.2013.
//  Copyright (c) 2013 Lambdarocket. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "LRRSynchronizationConfigurationDelegate.h"

static NSString *kLRRSyncComplete  = @"LRRSyncComplete";

/**
  *  This class is used to distinguish LRRSynchronizationOperation's context for merge purposes
  */

@interface LRRSyncManagedObjectContext : NSManagedObjectContext
@end


@class LRSynchronizationOperation;


/**
  *  Network driver protocol to be implemented by the network driver object.
  */
@protocol LRRNetworkDriverDelegate <NSObject>

/** Synchronously sends data to the remote server, 
  * @param data Data is of the form @{ @"Event" : [event1,event2,...], ...  }
  * @param operation The reference to the operation.
  * @param context SHould any database read/writes be needed, context is provided to do it.
  * @return Returns error object that encapsulates all connection/server/parsing errors. nil if no errors occured.
 */

- (NSError *)sendPushData:(NSDictionary *)data operation: (LRSynchronizationOperation *)operation context:(NSManagedObjectContext *)context;

/** Synchronously sends message to the remote server,  
  * @param error Error should be filled with all connection/server/parsing errors. nil if no errors occured.
  * @param message Message is something like @{@"Event":@(100),... } where 100 is SyncRevision of an event, returned earlier by fetchCounterForSynchronizationType:(NSString *)type andEntityName:(NSString *)entityName inContext:.
  * @param operation The reference to the operation.
  * @param context SHould any database read/writes be needed, context is provided to do it.
  * @return It is expected that this method returns either nil (on error) or NSDictionary containing arrays of objects named with entity names , e.g. @{ @"Event" : [event1,event2,...], ...  }. All relationships are provided as id's of objects, not as nested objects. E.g. if relationship is to-one, NSDictionary should contain @"house" : @"abf9cdf776fg". To-many relationship shoul look like @"houses" : @[ @"abf9cdf776fg",@"dafadfa78686"]. ALl referenced objects should be guaranteed to either be contained in the response or already present in our database. The operation will verify this explicitly, so you will get an error message should anything go wrong.
 */

- (NSDictionary *)receivePullForData:(NSDictionary *)message error:(NSError * __autoreleasing *)error operation: (LRSynchronizationOperation *)operation context:(NSManagedObjectContext *)context;

@end

/* 
 * The NSOperation-descendant synchronization class. It operates on a background thread and uses LRRSynchronizationConfiguration and LRRNetworkDriver objects to gain knowledge of what to do.
 * It first pushes modified data to the server and then pulls data from the server.
 
 * If any phase of synchronization fails (e.g. push) synchronization is stopped immediately, nothing is written to CoreData and proper error messages are set.
 *  It invokes kLRRSyncComplete notification on the main thread as the last action regardless of the result.
 
 */

@interface LRSynchronizationOperation : NSOperation
/// Network driver delegate. Must be set before scheduling.
@property(atomic, weak) id <LRRNetworkDriverDelegate> delegate;
/// Configuration delegate. Must be set before scheduling.
@property(atomic, weak) id <LRRSynchronizationConfigurationDelegate> configurationDelegate;
/// Persistent store coordinator to be used, must be set before scheduling.
@property(atomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
/// Push error message
@property(atomic, strong, readonly) NSError *pushError;
/// Pull error message
@property(atomic, strong, readonly) NSError *pullError;
/// UserInfo, might be useful to transfer some data between different methods that have this as their argument.
@property(atomic, strong) NSDictionary *userInfo;

/// Merge policy to be used by operation's context. If nil - default is used (store trump)
@property(atomic, strong) NSMergePolicy *mergePolicy;
/// If set to yes, detailed debugging info will be logged through NSLog
@property(atomic, assign) BOOL shouldDisplayLogs;

@end
