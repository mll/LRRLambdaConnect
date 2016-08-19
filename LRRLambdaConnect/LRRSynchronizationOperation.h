//
//  LRRSynchronizationOperation.h
//  LRRLambdaConnect
//
//  Created by Marek Lipert on 06.04.2013.
//  Copyright (c) 2013-2016 Spinney. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

static NSString *kLRRSyncComplete  = @"LRRSyncComplete";

/**
  *  This class is used to distinguish LRRSynchronizationOperation's context for merge purposes
  */

@interface LRRSyncManagedObjectContext : NSManagedObjectContext
@end

/**
 *  A class implementing this protocol is needed to configure synchronization.
 */

@protocol LRRSynchronizationConfigurationDelegate <NSObject>

/**
 *  Incremental synchronization is based on SyncRevision - an integer that keeps increasing on backend reflecting changes to the database. After syncgronization we have to store the biggest value for each model in order to be
     able to query the server for only incremental change. This method retrieves piervously saved maximal SyncRevision.
 * @param type String that indicates purpose, can be @"pull" or @"push". Just store pulls and pushes separately.
 * @param entityName name of Core Data entity for which we want to retrieve counter
 * @param context NSManagedObjectContext your method should wor with (as it would be fired on a background thread).
 * @return Should return an object that represents the counter (typicalyy - NSNumber). Dictionary of those objects will be then passed to network driver. The driver will be responsible of using this ionformation to form proper request for the backend.
 */

- (id) fetchCounterForSynchronizationType:(NSString *)type andEntityName:(NSString *)entityName inContext:(NSManagedObjectContext *)context;

/**
 *  Incremental synchronization is based on SyncRevision - an integer that keeps increasing on backend reflecting changes to the database. After syncgronization we have to store the biggest value for each model in order to be
 able to query the server for only incremental change. This method stores computed sync revisions.
 * @param counters Dictionary with keys being entity names and values being tokens that need to be stored (e.g. NSNumbers)
 * @param type String that indicates purpose, can be @"pull" or @"push". Just store pulls and pushes separately.
 * @param context NSManagedObjectContext your method should work with (as it would be fired on a background thread).
 * @return nil if all is ok, otherwise an NSError object describing the error.
 */

- (NSError *) updateSynchronizationCounters:   (NSDictionary *) counters forType:(NSString *) type inContext:(NSManagedObjectContext *)context;
/**
  * Returns the name of an attribute that is used as a unique key for all entities.
  */
- (NSString *)keyAttribute;
/**
 * Returns an array of Core Data entity names that should be pulled from the backend.
 */
- (NSArray *)pullEntities;
/**
 * Returns an array of Core Data entity names that should be pushed to the backend.
 */
- (NSArray *)pushEntities;
/**
 * Returns a dictionary of "ourName:theirName" mapping values for a given entity. 
 * @param entityName Name of CoreData entity the mapping is designated for
 * @return A dictionary with thye mapping. It must contain all fields of the model. If nil is returned, it is assumet that given mapping is an identity.
 */
- (NSDictionary *)mappingForEntityNamed:(NSString *)entityName;

/** Table names used by the server that correspond to our models. For example, 'users' might be mapped to 'LRRUser' object
   * @param modelName e.g 'LRRUser'
   * @return table name, e.g. 'users'
 */
- (NSString *)tableNameForModelName:(NSString *)modelName;

/** Model names used by CoreData that correspond server names. For example, 'LRRUser' might be mapped to 'users'. It is an inverse of mappingForEntityNamed:
 * @param modelName e.g users
 * @return table name, e.g. LRRUser
 * @see mappingForEntityNamed:
 */
- (NSString *)modelNameForTableName:(NSString *)tableName;

/** Returns NSDateFormatter to be used when formatting/reading dates from the server. It is advisible not to generate one every time as this operation is very heavy
  * @return NSDateFormatter to be used. */

- (NSDateFormatter *)dateFormatter;

/** 
 * Produces dictionary of the form:
 * @{ @"denormalizeFriendsFromUsers:": @"LRRUser" }
 * The selector would be invoked after synchronization but before save. Its argument would be a dictionary with uuids as keys and values - objects of class that was requested that changed durning synchro. 
 * @return Returns a dictionary containing denormalizatio selectors. Those selectors must be availible in this class, otherwise a crash might occur.
 */

- (NSDictionary *)denormalizationSelectors;

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
/// If set, completion block is fired after synchro completes
@property(nonatomic, copy) void (^completion)(NSError *error);

@end
