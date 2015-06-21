//
//  LRRLambdaConnectProtocol.h
//  LRRLambdaConnectDemo
//
//  Created by Marek Lipert on 14/05/15.
//  Copyright (c) 2015 Lambdarocket. All rights reserved.
//
#import <CoreData/CoreData.h>

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
 * @param context NSManagedObjectContext your method should wor with (as it would be fired on a background thread).
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
