//
//  MLSynchronizationOperation.m
//  Core Data integration test
//
//  Created by Marek Lipert on 06.04.2013.
//  Copyright (c) 2013 Marek Lipert. All rights reserved.
//

#import "LRRSynchronizationOperation.h"
#import <UIKit/UIKit.h>

@implementation LRRSyncManagedObjectContext
@end




@interface LRSynchronizationOperation ()

@property(atomic,strong) NSArray *completions;

@property(atomic, strong) NSError *error;
@property(nonatomic, strong) NSMutableDictionary *mappings;
@property(nonatomic, strong) NSMutableDictionary *inverseMappings;
@property(nonatomic, strong) NSManagedObjectContext *backgroundContext;
@property(nonatomic, strong) NSDateFormatter *dateFormatter;

@property(nonatomic, strong) NSDate *startPushRequestTime;
@property(nonatomic, strong) NSDate *stopPushRequestTime;
@property(nonatomic, strong) NSDate *startPushCalculationsTime;
@property(nonatomic, strong) NSDate *stopPushCalculationsTime;

@property(nonatomic, strong) NSDate *startPullRequestTime;
@property(nonatomic, strong) NSDate *stopPullRequestTime;
@property(nonatomic, strong) NSDate *startPullCalculationsTime;
@property(nonatomic, strong) NSDate *stopPullCalculationsTime;

@property(nonatomic, strong) NSDate *startDenormalizationCalculationsTime;
@property(nonatomic, strong) NSDate *stopDenormalizationCalculationsTime;

@property(nonatomic, strong) NSDate *startSaveDatabaseTime;
@property(nonatomic, strong) NSDate *stopSaveDatabaseTime;

@property(nonatomic, strong) NSString *keyAttribute;

- (NSDictionary *)serializeObject:(NSManagedObject *)object;

- (NSDictionary *)deserializeAllInstancesOfAnEntity:(NSEntityDescription *)entity fromArrayOfEntities:(NSArray *)array intoContext:(NSManagedObjectContext *)context maxCounter:(NSNumber * __autoreleasing *)maxCounter error:(NSError * __autoreleasing *)error;

- (NSDictionary *)computeInverseMappingForMapping:(NSDictionary *)mapping;

- (void)cleanUpFromDictionary:(NSDictionary *)dict;

- (NSError *)saveContext;


@end


@implementation LRSynchronizationOperation
@synthesize mappings = _mappings;
@synthesize inverseMappings = _inverseMappings;
@synthesize backgroundContext = _backgroundContext;
@synthesize dateFormatter = _dateFormatter;
@synthesize error = _error;
@synthesize pushError = _pushError;
@synthesize pullError = _pullError;



- (void)main
{
    UIBackgroundTaskIdentifier bg = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
    @autoreleasepool
    {
        _keyAttribute = [self.configurationDelegate keyAttribute];
        NSParameterAssert(self.persistentStoreCoordinator);
        _dateFormatter = [self.configurationDelegate dateFormatter];
        NSParameterAssert(self.dateFormatter);
        _backgroundContext = [[LRRSyncManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
        _backgroundContext.undoManager = nil;
        _backgroundContext.mergePolicy = self.mergePolicy ?: NSMergeByPropertyStoreTrumpMergePolicy;
        _backgroundContext.persistentStoreCoordinator = self.persistentStoreCoordinator;

        NSParameterAssert(self.backgroundContext);
        NSParameterAssert(self.dateFormatter);
        if(self.shouldDisplayLogs) NSLog(@"---------> Starting synchronization");
        _mappings = [NSMutableDictionary dictionary];
        _inverseMappings = [NSMutableDictionary dictionary];
        NSDictionary *mapping = nil;
        
        /* preparing mappings */

        for (NSString *entityName in [self.configurationDelegate pullEntities])
        {
            if (!_mappings[entityName] && (mapping = [self.configurationDelegate mappingForEntityNamed:entityName]))
            {
                [_mappings setObject:mapping forKey:entityName];
            }
        }


        for (NSString *entityName in [self.configurationDelegate pushEntities])
        {
            if (!_mappings[entityName] && (mapping = [self.configurationDelegate mappingForEntityNamed:entityName]))
            {
                [_mappings setObject:mapping forKey:entityName];
            }
        }

        /* compute inverses for pull */
        for (NSString *mapName in _mappings)
        {
            NSDictionary *map = _mappings[mapName];
            [_inverseMappings setObject:[self computeInverseMappingForMapping:map] forKey:mapName];
        }


        if(self.shouldDisplayLogs) NSLog(@"-----> starting push");
        NSMutableDictionary *allObjects = nil;
        allObjects = [self push];
        if(self.shouldDisplayLogs) NSLog(@"-----> ending push. Pushed %ld objects, error occured: %@", (unsigned long)[allObjects count], _error.localizedDescription);

        if (_error) _pushError = _error;


        if (!_error)
        {
            if(self.shouldDisplayLogs) NSLog(@"-----> starting pull");
            [allObjects addEntriesFromDictionary:[self pull]];
            if(self.shouldDisplayLogs) NSLog(@"-----> ending pull");
            if (_error) _pullError = _error;
        }


        if (_error)
        {
            if(self.shouldDisplayLogs) NSLog(@"*** Synchronization ended with error: %@", _error);
        }
        else
        {
            self.startDenormalizationCalculationsTime = [NSDate date];

            NSDictionary *selectors = [self.configurationDelegate denormalizationSelectors];
            NSSet *classes = [NSSet setWithArray:selectors.allValues];

            NSMutableDictionary *objectsForDenormalization = [NSMutableDictionary new];

            for (NSManagedObject *o in [allObjects allValues])
            {
                for (NSString *class in classes)
                {
                    if ([o isKindOfClass:NSClassFromString(class)])
                    {
                        NSMutableDictionary *classDict = objectsForDenormalization[class];
                        if (classDict == nil)
                        {
                            classDict = [NSMutableDictionary dictionary];
                            objectsForDenormalization[class] = classDict;
                        }
                        classDict[[o valueForKey:_keyAttribute]] = o;
                    }
                }
            }

            for (NSString *selector in selectors)
            {
                NSDictionary *objects = objectsForDenormalization[selectors[selector]];
                if (objects.count)
                {
                    [self.configurationDelegate performSelector:NSSelectorFromString(selector) withObject:objects];
                }
            }
            self.stopDenormalizationCalculationsTime = [NSDate date];
            self.startSaveDatabaseTime = [NSDate date];
            [self saveContext];
            self.stopSaveDatabaseTime = [NSDate date];
            if (_error)
            {
                if(self.shouldDisplayLogs) NSLog(@"*** Synchronization ended with error: %@", _error);
            }
        }
        [self cleanUpFromDictionary:allObjects];
        double total = [self.stopSaveDatabaseTime timeIntervalSinceDate:self.startPushCalculationsTime];
        double pushReq = [self.stopPushRequestTime timeIntervalSinceDate:self.startPushRequestTime];
        double pullReq = [self.stopPullRequestTime timeIntervalSinceDate:self.startPullRequestTime];
        double pushCalc = [self.stopPushCalculationsTime timeIntervalSinceDate:self.startPushCalculationsTime];
        double pullCalc = [self.stopPullCalculationsTime timeIntervalSinceDate:self.startPullCalculationsTime];
        double denoCalc = [self.stopDenormalizationCalculationsTime timeIntervalSinceDate:self.startDenormalizationCalculationsTime];
        double saveTime = [self.stopSaveDatabaseTime timeIntervalSinceDate:self.startSaveDatabaseTime];

        if(self.shouldDisplayLogs) NSLog(@"-----> Synchronization finished in %.2fs. This includes push %.2fs (%.2fs request, %.2fs calc), pull %.2fs (%.2fs request, %.2fs calc) denormalization %.2fs and save %.2fs", total, pushCalc + pushReq, pushReq, pushCalc, pullCalc + pullReq, pullReq, pullCalc, denoCalc, saveTime);


        dispatch_sync(dispatch_get_main_queue(), ^
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kLRRSyncComplete object:self userInfo:nil];
            if(self.completion) self.completion(self.error);
        });

    } /* autoreleasepool */
    [[UIApplication sharedApplication] endBackgroundTask:bg];
}



- (NSMutableDictionary *)push
{
    NSError *error = nil;
    self.startPushCalculationsTime = [NSDate date];
    NSMutableDictionary *pushDictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary *allObjects = [NSMutableDictionary dictionary];

    for (NSString *name in [self.configurationDelegate pushEntities])
    {
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:name];
        fetch.predicate = [NSPredicate predicateWithFormat:@"(isSuitableForPush == %d)", YES];

        NSArray *objects = [_backgroundContext executeFetchRequest:fetch error:&error];
        if (error)
        {
            _error = error;
            return allObjects;
        }
        NSMutableArray *tree = [NSMutableArray arrayWithCapacity:[objects count]];

        for (NSManagedObject *object in objects)
        {
            [tree addObject:[self serializeObject:object]];
            NSParameterAssert([object valueForKey:_keyAttribute]);
            
            [allObjects setObject:object forKey:[NSString stringWithFormat:@"%@%@",object.entity.name,[object valueForKey:_keyAttribute]]];
        }

        if(self.shouldDisplayLogs) NSLog(@"--> Will push %ld objects of type %@", (unsigned long)[objects count], name);

        [pushDictionary setObject:tree forKey:[self.configurationDelegate tableNameForModelName:name]];
        if (self.isCancelled)
        {
            _error = [NSError errorWithDomain:@"SynchronizationOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : @"Cancelled"}];
            return allObjects;
        }
    } /* for */
    bool shouldWeSend = NO;
    for (NSArray *a in [pushDictionary allValues]) if (a.count) shouldWeSend = YES;
    self.stopPushCalculationsTime = [NSDate date];
    self.startPushRequestTime = [NSDate date];
    if (shouldWeSend)
    { /* if we have something to send */
        id <LRRNetworkDriverDelegate> strongDelegate;
        strongDelegate = self.delegate;
        NSParameterAssert(strongDelegate);
        NSAssert([strongDelegate respondsToSelector:@selector(sendPushData:operation:context:)], @"Delegate does not implement sendPushData:");
        if(self.shouldDisplayLogs) NSLog(@"*** Starting push request");
        _error = [strongDelegate sendPushData:pushDictionary operation:self context:self.backgroundContext];
        if(self.shouldDisplayLogs) NSLog(@"*** Finished push request");
        if (!_error)
        {
            for (NSManagedObject *o in [allObjects allValues]) [o setValue:@NO forKey:@"isSuitableForPush"];
        }
    }
    else if(self.shouldDisplayLogs) NSLog(@"*** No objects to push, skipping request");
    
    self.stopPushRequestTime = [NSDate date];
    return allObjects;
}


- (NSDictionary *)pull
{
    NSMutableDictionary *synchronizationCounters = [NSMutableDictionary dictionary];
    NSMutableDictionary *allObjects = [NSMutableDictionary dictionaryWithCapacity:1000];

    @autoreleasepool
    { /* sending request with computed counters */
        NSMutableDictionary *pullDictionary = [NSMutableDictionary dictionary];
        for (NSString *name in [self.configurationDelegate pullEntities])
        {
            [pullDictionary setObject:[self.configurationDelegate fetchCounterForSynchronizationType:@"pull" andEntityName:name inContext:_backgroundContext] forKey:[self.configurationDelegate tableNameForModelName:name] ? : name];
        }
        if (![pullDictionary count])
        {
            return @{};
        }
        if(self.shouldDisplayLogs) NSLog(@"*** Sync revisions being sent in pull:");
        for (NSString *s in pullDictionary) if(self.shouldDisplayLogs) NSLog(@"-> %@ : %@", [self.configurationDelegate modelNameForTableName:s], pullDictionary[s]);
        NSError *error = nil;
        id <LRRNetworkDriverDelegate> strongDelegate;
        strongDelegate = self.delegate;
        NSParameterAssert(strongDelegate);
        /* read data */
        NSAssert([strongDelegate respondsToSelector:@selector(receivePullForData:error:operation:context:)], @"Delegate does not implement receivePullForData:error:");
        if(self.shouldDisplayLogs) NSLog(@"*** Starting pull request");
        self.startPullRequestTime = [NSDate date];
        NSDictionary *dictResponse = [strongDelegate receivePullForData:pullDictionary error:&error operation:self context:self.backgroundContext];
        NSAssert(dictResponse, @"No response from driver!");
        NSAssert([dictResponse isKindOfClass:[NSDictionary class]],@"Not a dictionary in response from driver!");

        self.stopPullRequestTime = [NSDate date];
        if(self.shouldDisplayLogs) NSLog(@"*** Finished pull request");
        self.startPullCalculationsTime = [NSDate date];
        _error = error;
        if (error) return @{};
        /* deserialize */
        if (![dictResponse isKindOfClass:[NSDictionary class]])
        {
            _error = [NSError errorWithDomain:@"SynchronizationOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"JSON response is not a dictionary, but %@", [dictResponse class]]}];
            return allObjects;
        }
        if(self.shouldDisplayLogs) NSLog(@"--> Pull pass I: Deserializing received objects");
        
        NSMutableDictionary *remainingObjects = [NSMutableDictionary dictionaryWithCapacity:1000];
        
        for (NSString *entityNameCandidate in dictResponse)
        { /* pass one, fetching/creating all changed objects */
            NSString *entityName = [self.configurationDelegate modelNameForTableName:entityNameCandidate] ? : entityNameCandidate;

            NSEntityDescription *en = [NSEntityDescription entityForName:entityName inManagedObjectContext:_backgroundContext];
            if (!en) continue;

            NSNumber *maxCounterForEntity = nil;
            NSError *error = nil;
            NSDictionary *managedObjects = [self deserializeAllInstancesOfAnEntity:en fromArrayOfEntities:dictResponse[entityNameCandidate] intoContext:_backgroundContext maxCounter:&maxCounterForEntity error:&error];
            if(self.shouldDisplayLogs) NSLog(@"-> %@ - deserialized %ld instances", entityName, (unsigned long)managedObjects.count);
            if (error)
            {
                _error = error;
                return allObjects;
            }
            /* we set this array here, but set counters at the very end so that we are sure all was pulled */
            NSNumber *currentCounter = pullDictionary[entityNameCandidate] ? : maxCounterForEntity;
            if (currentCounter.integerValue <= maxCounterForEntity.integerValue) [synchronizationCounters setObject:maxCounterForEntity forKey:entityName];
            
            [allObjects addEntriesFromDictionary:managedObjects];
        }

        NSMutableSet *referencedEntities = [NSMutableSet setWithCapacity:1000];
        
        if(self.shouldDisplayLogs) NSLog(@"--> Pull pass II: Localizing referenced but not yet fetched objects");
        for (NSString *entityNameCandidate in dictResponse)
        { /* pass two, finding all objects that are referenced from changed objects and not yet fetched - we do not want to fetch them one-by-one */
            NSString *entityName = [self.configurationDelegate modelNameForTableName:entityNameCandidate] ? : entityNameCandidate;
            NSDictionary *allRelationships = [[NSEntityDescription entityForName:entityName inManagedObjectContext:_backgroundContext] relationshipsByName];
            NSDictionary *mapping = _mappings[entityName];
            for (NSDictionary *object in dictResponse[entityNameCandidate])
            {
                for (NSString *relationship in allRelationships)
                {
                    NSString *mappedRelationship = mapping ? mapping[relationship] : relationship;
                    if (!mappedRelationship) continue;
                    id val = object[mappedRelationship];
                    if (!val || [val isKindOfClass:[NSNull class]]) continue; /* empty fields ignored */

                    NSString *destinationEntity = [[allRelationships[relationship] destinationEntity] name];

                    NSArray *relationships = [val isKindOfClass:[NSArray class]] ? val : @[val];
                    for (id idd in relationships)
                    {
                        id fixedId = [NSString stringWithFormat:@"%@%@",destinationEntity,idd];
                        if (allObjects[fixedId]) continue;
                        if (remainingObjects[destinationEntity][idd]) continue;
                        [referencedEntities addObject:destinationEntity];
                        NSMutableDictionary *singleDict = remainingObjects[destinationEntity];
                        
                        if(!singleDict) remainingObjects[destinationEntity] = singleDict =  [NSMutableDictionary new];
                        
                        [singleDict setObject:[NSString stringWithFormat:@"id: %@ onObject: %@ relationship: %@ rid: %@\n", object[_keyAttribute], entityName, relationship, fixedId] forKey:idd];
                    }
                }
            }
        } /* we now end this nightmareish loop and fetch */
        if(self.shouldDisplayLogs) NSLog(@"--> Pull pass II: fetching additional %ld referenced objects", (unsigned long)remainingObjects.count);
        NSMutableArray *fetchedRemainingObjects = [NSMutableArray arrayWithCapacity:1000];
        NSInteger remainingCount = 0;
        for (NSString *entityName in referencedEntities)
        {
            NSDictionary *singleDict = remainingObjects[entityName];
            remainingCount += singleDict.count;
            NSAssert(singleDict,@"No entity in single dict");
            NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
            fetch.predicate = [NSPredicate predicateWithFormat:@"%K IN %@",_keyAttribute,[singleDict allKeys]];
            fetch.returnsObjectsAsFaults = NO;
            [fetchedRemainingObjects addObjectsFromArray:[_backgroundContext executeFetchRequest:fetch error:&error]];
            if (error)
            {
                if(self.shouldDisplayLogs) NSLog(@"*** Fetch request error durning deserialization: %@", error.localizedDescription);
                return allObjects;
            }
        }
        for (NSManagedObject *entity in fetchedRemainingObjects)
        {
            [allObjects setObject:entity forKey:[NSString stringWithFormat:@"%@%@",entity.entity.name,[entity valueForKey:_keyAttribute]]];
        }


        if ([fetchedRemainingObjects count] != remainingCount)
        {
            NSMutableString *errorString = [NSMutableString string];
            for (NSString *entityName in remainingObjects)
            for (NSString *id in remainingObjects[entityName])
                if (allObjects[[NSString stringWithFormat:@"%@%@",entityName,id]] == nil) [errorString appendString:remainingObjects[entityName][id]];

            _error = [NSError errorWithDomain:@"SynchronizationOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Received data contains references to objects that are neither present in it, nor present in our database: %@", errorString]}];
            return allObjects;
        }

        if(self.shouldDisplayLogs) NSLog(@"--> Pull pass III: patching up all received relationships");

        for (NSString *entityNameCandidate in dictResponse)
        { /* we now drill down relationship route */
            NSString *entityName = [self.configurationDelegate modelNameForTableName:entityNameCandidate] ? : entityNameCandidate;
            NSDictionary *allRelationships = [[NSEntityDescription entityForName:entityName inManagedObjectContext:_backgroundContext] relationshipsByName];
            NSDictionary *mapping = _mappings[entityName];

            int number = 1;
            for (NSDictionary *object in dictResponse[entityNameCandidate])
            {
                number++;
                NSManagedObject *deserializedObject = allObjects[[NSString stringWithFormat:@"%@%@",entityName,object[_keyAttribute]]];


                for (NSString *relationship in allRelationships)
                {
                    NSString *mappedRelationship = mapping ? mapping[relationship] : relationship;
                    if (!mappedRelationship) continue;
                

                    id val = object[mappedRelationship];
                    if (!val || [val isKindOfClass:[NSNull class]])
                    {
                        continue; /* empty fields ignored */
                    }

                    NSAssert([val isKindOfClass:[NSArray class]] == [allRelationships[relationship] isToMany], @"To-many relationship doesnt get an array");

                    /* one-to-one */
                    if (![val isKindOfClass:[NSArray class]])
                    {
                        NSRelationshipDescription *rel = allRelationships[relationship];
                        NSManagedObject *objetToAdd = allObjects[[NSString stringWithFormat:@"%@%@",rel.destinationEntity.name,val]];
                        NSParameterAssert(objetToAdd);

                        if (![objetToAdd isKindOfClass:NSClassFromString([NSString stringWithFormat:@"%@", rel.destinationEntity.managedObjectClassName])])
                        {
                            NSString *errorString = [NSString stringWithFormat:@"Relationship %@ for %@ - %@ expects %@ but got %@ - %@", relationship, deserializedObject.class, [deserializedObject valueForKey:_keyAttribute], rel.destinationEntity.managedObjectClassName, objetToAdd.class, [objetToAdd valueForKey:_keyAttribute ]];
                            _error = [NSError errorWithDomain:@"SynchronizationOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : errorString}];
                            _pullError = _error;
                            break;
                        }
                        [deserializedObject setValue:objetToAdd forKey:relationship];
                    }
                    else
                    { /* one-to-many */
                        NSRelationshipDescription *rel = allRelationships[relationship];
                        NSMutableSet *relation = rel.isOrdered ? (NSMutableSet *)[[NSMutableOrderedSet alloc] initWithCapacity:1000]  :  [NSMutableSet setWithCapacity:1000];


                        for (NSString *id in (NSArray *) val)
                        {
                            NSManagedObject *objetToAdd = allObjects[[NSString stringWithFormat:@"%@%@",rel.destinationEntity.name,id]];

                            if (![objetToAdd isKindOfClass:NSClassFromString([NSString stringWithFormat:@"%@", rel.destinationEntity.managedObjectClassName])]) {
                                NSString *errorString = [NSString stringWithFormat:@"Relationship %@ for %@ - %@ expects %@ but got %@ - %@", relationship, deserializedObject.class, [deserializedObject valueForKey:_keyAttribute ], rel.destinationEntity.managedObjectClassName, objetToAdd.class, [objetToAdd valueForKey:_keyAttribute ]];
                                _error = [NSError errorWithDomain:@"SynchronizationOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : errorString}];
                                _pullError = _error;
                                break;
                            }
                            [relation addObject:objetToAdd];
                        }
                        [deserializedObject setValue:relation forKey:relationship];
                    }
                }
            }
        } /* outer for */
        
        if(self.shouldDisplayLogs) NSLog(@"*** Updating sync revisions for next pull");
        for (NSString *s in synchronizationCounters)
        {
            if(self.shouldDisplayLogs) NSLog(@"-> %@ : %@", s, synchronizationCounters[s]);
        }
        if (!_error)
        { /* write synchro info down to database */
            _error = [self.configurationDelegate updateSynchronizationCounters:synchronizationCounters forType:@"pull" inContext:_backgroundContext];
        }
        int objC = 0;
        for (NSArray *a in [dictResponse allValues]) objC += a.count;
        self.stopPullCalculationsTime = [NSDate date];
        if(self.shouldDisplayLogs) NSLog(@"*** End pulling %d objects.", objC);
    } /* autoreleasPool */

    return allObjects;
}

#pragma mark - helpers



- (NSDictionary *)deserializeAllInstancesOfAnEntity:(NSEntityDescription *)entity fromArrayOfEntities:(NSArray *)array intoContext:(NSManagedObjectContext *)context maxCounter:(NSNumber * __autoreleasing *)maxCounter error:(NSError * __autoreleasing *)error
{ /* this does not deserialize relationships! */

    NSMutableDictionary *retVal = [NSMutableDictionary dictionaryWithCapacity:array.count];
    long long int maxCounterInternal = 0;
    NSError *internalError = nil;
    @autoreleasepool
    { /* lots of free memory is what we like */
        do
        {
            NSParameterAssert(entity);
            NSParameterAssert(array);
            NSParameterAssert(context);
            NSDictionary *mapping = _mappings[entity.name];

            NSMutableArray *ids = [NSMutableArray arrayWithCapacity:array.count];
            for (NSDictionary *d in array)
            { /* rebuilding entrant json-like core foundation representation into array of ids */
                NSString *uid = d[_keyAttribute];
                NSParameterAssert(uid);
                [ids addObject:uid];
            }

            /* fetching objects with given ids */

            NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entity.name];
            fetch.predicate = [NSPredicate predicateWithFormat:@"%K IN %@", _keyAttribute, ids];
            fetch.returnsObjectsAsFaults = NO;

            NSArray *results = [context executeFetchRequest:fetch error:&internalError];
            if (internalError)
            {
                if(self.shouldDisplayLogs) NSLog(@"Fetch request error durning deserialization: %@", (*error).localizedDescription);
                break;
            }
            /* building dictionary from results */
            NSMutableDictionary *dictResults = [NSMutableDictionary dictionaryWithCapacity:results.count];
            for (NSManagedObject *e in results)
            {
                NSAssert(dictResults[[e valueForKey:_keyAttribute ]] == nil, @"Database integrity error - we have at least TWO %@ with id %@", e.class, [e valueForKey:_keyAttribute]);
                [dictResults setObject:e forKey:[e valueForKey:_keyAttribute]];
            }


            NSDateFormatter *dateFormatter = _dateFormatter;
            NSMutableDictionary *createdObjects = [NSMutableDictionary new];
            
            for (NSDictionary *serialized in array)
            {
                NSManagedObject *object = dictResults[serialized[_keyAttribute]];
                if (!object)
                { /* create object if was not found */
                    NSAssert(!createdObjects[serialized[_keyAttribute]],@"Database integrity error - we have at least TWO %@ with id %@", entity.name, serialized[_keyAttribute]);
                    object = [NSEntityDescription insertNewObjectForEntityForName:entity.name inManagedObjectContext:context];
                    createdObjects[serialized[_keyAttribute]] = object;
                }
                
                for (NSString *attributeCandidate in entity.attributesByName)
                {
                    if ([attributeCandidate isEqualToString:@"syncRevisionPush"]) continue;
                    NSString *attribute = mapping ? mapping[attributeCandidate] : attributeCandidate;
             
                    if (!attribute) continue;

                    id value = serialized[attribute];

                    if (!value) continue;
                    

                    if ([value isKindOfClass:[NSNull class]]) value = nil;


                    NSString *attribClass = [entity.attributesByName[attributeCandidate] attributeValueClassName];

                    if (value && [attribClass isEqualToString:@"NSDate"])
                    { /* date formatting */
                        if(![value isKindOfClass:[NSDate class]])
                            value = [dateFormatter dateFromString:value];
                    }

                    if (value && ![value isKindOfClass:NSClassFromString(attribClass)] )
                    {
                        NSString *errorString = [NSString stringWithFormat:@"Attribute %@ class mismach for %@ - %@! required %@ got %@", attributeCandidate, [object class], [object valueForKey:_keyAttribute ], attribClass, [value class]];

                        if(self.shouldDisplayLogs) NSLog(@"%@", errorString);
                        internalError = [NSError errorWithDomain:@"SynchronizationOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : errorString}];
                        break;
                    }


                    /* validation, can be disabled for release/performance */
                    [object validateValue:&value forKey:attributeCandidate error:&internalError];
                    if (internalError)
                    {
                        if(self.shouldDisplayLogs) NSLog(@"Validation error for %@.%@ value: %@: %@", entity.name, attributeCandidate, value, internalError.localizedDescription);
                        break;
                    }
                    [object setValue:value forKey:attributeCandidate];
                }
                /* update max counter */
                maxCounterInternal = maxCounterInternal < [[object valueForKey:@"syncRevision" ] longLongValue] ? [[object valueForKey:@"syncRevision" ] longLongValue] : maxCounterInternal;

                [retVal setObject:object forKey:[NSString stringWithFormat:@"%@%@",object.entity.name,[object valueForKey:_keyAttribute]]];
            }
        } while (NO);
    }
    *maxCounter = [NSNumber numberWithLongLong:maxCounterInternal];
    *error = internalError;
    return retVal;
}


- (NSDictionary *)serializeObject:(NSManagedObject *)object
{
    NSParameterAssert(object);
    NSMutableDictionary *serialized = [NSMutableDictionary dictionary];
    NSDictionary *mapping = _mappings[object.entity.name];

    for (NSString *attributeCandidate in object.entity.attributesByName)
    {
        NSString *attribute = mapping ? mapping[attributeCandidate] : attributeCandidate;
        
        if (!attribute) continue;
        if([attribute isEqualToString:@"isSuitableForPush"] || [attribute isEqualToString:@"syncRevision"]) continue;
        if(object.entity.attributesByName[attributeCandidate].isTransient) continue;
        id val = [object valueForKey:attributeCandidate];
        if (val == nil) val = [NSNull null];
        if ([val isKindOfClass:[NSDate class]])
        {
            val = [_dateFormatter stringFromDate:val];
        }
        if (!([val isKindOfClass:[NSNull class]] || [val isKindOfClass:[NSNumber class]] || [val isKindOfClass:[NSString class]])) val = [val description];

        [serialized setObject:val forKey:attribute];
    }


    for (NSString *relationCandidate in object.entity.relationshipsByName)
    {
        NSString *relation = mapping ? mapping[relationCandidate] : relationCandidate;
        if (!relation) continue;

        id rel = [object valueForKey:relationCandidate];

        if ([rel isKindOfClass:[NSSet class]] || [rel isKindOfClass:[NSOrderedSet class]])
        { /* to many */
            NSMutableArray *array = [NSMutableArray array];
            for (NSManagedObject *o in (NSSet *) rel)
            {
                [array addObject:[o valueForKey:_keyAttribute]];
                /* break potential strong cycles by turning o into a fault */
                [o.managedObjectContext refreshObject:o mergeChanges:NO];
            }
            [serialized setObject:array forKey:relation];
        } else
        {
            NSManagedObject *o = (NSManagedObject *) rel;
            [serialized setObject:rel ? [o valueForKey:_keyAttribute] : [NSNull null] forKey:relation];
            /* break potential strong cycles by turning o into a fault */
            [o.managedObjectContext refreshObject:o mergeChanges:NO];
        }
    }
    return serialized;
}


- (NSDictionary *)computeInverseMappingForMapping:(NSDictionary *)mapping
{
    NSParameterAssert(mapping);
    NSMutableDictionary *retVal = [NSMutableDictionary dictionaryWithCapacity:mapping.count];
    for (NSString *val in mapping)
    {
        NSString *name = mapping[val];
        NSAssert(retVal[name] == nil, @"Mapping is not one-to-one for attribute %@ value %@", val, name);
        [retVal setObject:val forKey:name];
    }
    NSAssert(retVal, @"No return value");
    return retVal;
}

- (void)cleanUpFromDictionary:(NSDictionary *)dict
{
    for (NSManagedObject *m in [dict allValues])
    {
        NSAssert([m isKindOfClass:[NSManagedObject class]], @"Not an NSManagedObject entity in allObjects!");
        [_backgroundContext refreshObject:m mergeChanges:NO];
    }
}

- (NSError *)saveContext
{
    NSError *error = nil;
    if (!_error)
    {
        if(self.shouldDisplayLogs) NSLog(@"*** Saving context");
        [_backgroundContext save:&error];
        if(self.shouldDisplayLogs) NSLog(@"*** Saved context");
        _error = error;
    }
    return error;
}

@end
