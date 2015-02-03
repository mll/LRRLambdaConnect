//
//  MLSynchronizationOperation.h
//  Core Data integration test
//
//  Created by Marek Lipert on 06.04.2013.
//  Copyright (c) 2013 Lambdarocket. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

static NSString *kLRRSyncComplete  = @"LRRSyncComplete";

@interface LRRSyncManagedObjectContext : NSManagedObjectContext
@end


@protocol LRRSynchronizationConfigurationDelegate <NSObject>


- (NSDictionary *) fetchCounterForSynchronizationType:(NSString *)type andEntityName:(NSString *)entityName inContext:(NSManagedObjectContext *)context;

- (NSError *) updateSynchronizationCounters:   (NSDictionary *) counters forType:(NSString *) type inContext:(NSManagedObjectContext *)context;

- (NSString *)keyAttribute;

- (NSArray *)pullEntities;

- (NSArray *)pushEntities;

- (NSDictionary *)mappingForEntityNamed:(NSString *)entityName;

- (NSString *)tableNameForModelName:(NSString *)modelName;

- (NSString *)modelNameForTableName:(NSString *)tableName;

- (NSDateFormatter *)dateFormatter;

/* Produces dictionary of the form:
 
 @{ @"denormalizeFriendsFromUsers:": @"LRRUser" }
 
 The selector would be invoked after synchronization but before save. Its argument would be a dictionary with uuids as keys and values - objects of class that was requested that changed durning synchro. */

- (NSDictionary *)denormalizationSelectors;

@end

@class LRSynchronizationOperation;



@protocol LRRNetworkDriverDelegate <NSObject>

/* synchronously sends data to the remote server, error encapsulates all connection/server/parsing errors. nil error signals completion */

/* data is of the form @{ @"Event" : [event1,event2,...], ...  }  */

- (NSError *)sendPushData:(NSDictionary *)data operation: (LRSynchronizationOperation *)operation context:(NSManagedObjectContext *)context;

/* synchronously sends message to the remote server, error encapsulates all connection/server/parsing errors. nil error signals completion. return value holds response. Message is something like @{@"Event":@(100),... } where 100 is sync_revision of an event. It is expected that this method returns either nil (on error) or NSDictionary containing arrays of objects named with entity names (capital letters at the beginning of a name!) */

- (NSDictionary *)receivePullForData:(NSDictionary *)message error:(NSError * __autoreleasing *)error operation: (LRSynchronizationOperation *)operation context:(NSManagedObjectContext *)context;

@end

/* 
   this operation is configured by LRRSynchronizationConfiguration delegate.
 
   It invokes kLRRSyncComplete notification on the main thread as a last action, which actually might be received before operation ends, but also after it ends (this is indetermined)
 
   If synchronization ended with an error, pushError or pullError property will be set on the operation.
 */

@interface LRSynchronizationOperation : NSOperation

@property(atomic, weak) id <LRRNetworkDriverDelegate> delegate;
@property(atomic, weak) id <LRRSynchronizationConfigurationDelegate> configurationDelegate;

@property(atomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property(atomic, strong, readonly) NSError *pushError;
@property(atomic, strong, readonly) NSError *pullError;

@property(atomic, strong) NSDictionary *userInfo;

/// If nil - default is used (store trump)
@property(atomic, strong) id mergePolicy;

@property(atomic, assign) BOOL shouldDisplayLogs;


@end
