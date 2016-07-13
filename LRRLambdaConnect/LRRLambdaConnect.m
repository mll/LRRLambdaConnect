//
//  MLLLambdaConnectTools.m
//  MLLIncrementalSynchronizationDemo
//
//  Created by Marek Lipert on 02.02.2015.
//  Copyright (c) 2015 Lambdarocket. All rights reserved.
//

#import "LRRLambdaConnect.h"


@interface LRRLambdaConnect()

@property (nonatomic,strong) NSOperationQueue *queue;
@property (nonatomic,weak) NSTimer *synchronizationTimer;

@end


@implementation LRRLambdaConnect
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize mainContext = _mainContext;
@synthesize model = _model;

+ (instancetype)sharedInstance
{
    static LRRLambdaConnect *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [LRRLambdaConnect new];
    });
    return instance;
}


- (void) setupCoreDataWithModelNamed: (NSString *)modelName databaseFileName: (NSString *)dbFileName
{
    [self setupCoreDataWithModelNamed:modelName databaseFileName:dbFileName mergePolicy:nil];
}


- (void) setupCoreDataWithModelNamed: (NSString *)modelName databaseFileName: (NSString *)dbFileName mergePolicy: (id) mergePolicy
{
    NSAssert(_persistentStoreCoordinator == nil,@"Already set-up!");
    NSError *error;
    
    NSString *documentDirectory = [NSString stringWithFormat:@"%@/Documents/%@", NSHomeDirectory(), dbFileName];
    NSURL *documentDirectoryURL = [NSURL fileURLWithPath:documentDirectory];
    
    NSURL *modelUrl = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"momd"];
    NSAssert(modelUrl,@"No model url");
    NSManagedObjectModel *model = [[[NSManagedObjectModel alloc] initWithContentsOfURL:modelUrl] mutableCopy];
    NSAssert(model, @"No model");
    _model = model;
    NSMutableArray * ent = [NSMutableArray new];
    for(NSEntityDescription *entit in model.entities)
    {
        NSEntityDescription *entity = entit.copy;
        // Don't add properties for sub-entities, as they already exist in the super-entity
        if ([entit superentity])
        {
            [ent addObject:entity];
            continue;
        }
        
        NSAttributeDescription *syncRevision = [[NSAttributeDescription alloc] init];
        [syncRevision setName:@"syncRevision"];
        [syncRevision setAttributeType:NSInteger64AttributeType];
        [syncRevision setIndexed:NO];
        [syncRevision setOptional:YES];
        
        NSAttributeDescription *isSuitable = [[NSAttributeDescription alloc] init];
        [isSuitable setName:@"isSuitableForPush"];
        [isSuitable setAttributeType:NSBooleanAttributeType];
        [isSuitable setIndexed:NO];
        [isSuitable setOptional:NO];
        [isSuitable setDefaultValue:@NO];

        [entity setProperties:[entity.properties arrayByAddingObjectsFromArray:@[syncRevision,isSuitable]]];
        [ent addObject:entity];
    }
    
    model.entities = ent;
    for(NSEntityDescription *arg in model.entities)
    {
        if([model.entitiesByName[arg.name] subentities].count)
        {
            NSMutableArray *arr = [NSMutableArray new];
            for(NSEntityDescription *subentity in [model.entitiesByName[arg.name] subentities])
            {
                [arr addObject:model.entitiesByName[subentity.name]];
            }
            arg.subentities = arr;
        }
    }
    
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSDictionary *options = @{
                              NSInferMappingModelAutomaticallyOption : @(YES),
                              NSMigratePersistentStoresAutomaticallyOption: @(YES)
                              };
    NSInteger tryNo = 0;
    do
    {
        error = nil;
        [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:documentDirectoryURL options:options error:&error];
        if(error)
        {
            tryNo++;
            NSLog(@"Backing store error: %@",error);
            [[NSFileManager defaultManager] removeItemAtURL:documentDirectoryURL error:nil];
        }
    }
    while(error && tryNo < 3);
    
    NSAssert(error == nil,@"Error adding backing store: %@",error);

    _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _mainContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
    _mainContext.mergePolicy = mergePolicy ?: NSMergeByPropertyObjectTrumpMergePolicy;

    self.queue = [NSOperationQueue new];
    self.queue.maxConcurrentOperationCount = 1;
    
    [self addSkipBackupAttributeToItemAtURL:documentDirectoryURL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeWithMainContext:) name:NSManagedObjectContextDidSaveNotification object:nil];
    
}

- (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL
{
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

- (void) mergeWithMainContext: (NSNotification *) note
{
    if(![note.object isKindOfClass:[LRRSyncManagedObjectContext class]]) return;
    if([NSThread isMainThread])
    {
        [self.mainContext mergeChangesFromContextDidSaveNotification:note];
    }
    else
    {
        __weak LRRLambdaConnect *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.mainContext mergeChangesFromContextDidSaveNotification:note];
        });
    }
}

- (void) forceSynchronizationCompletion: (void (^)(NSError *error)) completion
{
    [self periodicJobCompletion:completion];
}

- (void) periodicJob
{
    [self periodicJobCompletion:nil];
}

- (void) periodicJobCompletion: (void (^)(NSError *error)) completion
{
    LRSynchronizationOperation *op = [LRSynchronizationOperation new];
    op.persistentStoreCoordinator = self.persistentStoreCoordinator;
    NSAssert(self.strongConfigurationDelegate,@"No configuration delegate supplied");
    NSAssert(self.strongDriverDelegate,@"No network driver delegate supplied");
    op.configurationDelegate = self.strongConfigurationDelegate;
    op.delegate = self.strongDriverDelegate;
    op.shouldDisplayLogs = self.shouldDisplayLogs;
    op.completion = completion;
    [self.queue addOperation:op];
}


- (void) startSynchronizationWithTimeInterval: (NSTimeInterval) interval
{
    if(self.synchronizationTimer) return;
    [self forceSynchronizationCompletion:nil];
    self.synchronizationTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(periodicJob) userInfo:nil repeats:YES];
}

- (void) stopSynchronization
{
    [self.synchronizationTimer invalidate];
}

- (void) saveMainContext
{
    NSError *error = nil;
    BOOL ok  = [self.mainContext save:&error];
    NSAssert(ok,@"Error saving main context: %@",error);
}

- (void) deleteAllObjectsCompletion: (void (^)()) completion
{
    [self stopSynchronization];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.queue waitUntilAllOperationsAreFinished];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self releaseAllObjects:self.mainContext];
            for(NSEntityDescription *e in self.mainContext.persistentStoreCoordinator.managedObjectModel.entities)
            {
                NSFetchRequest *frq = [[NSFetchRequest alloc] initWithEntityName:e.name];
                NSError *err = nil;
                NSArray *objects = [self.mainContext executeFetchRequest:frq error:&err];
                NSAssert(!err, @"Error fetching objects for deletion; entity: %@", e.name);
                for (NSManagedObject *o in objects) [self.mainContext deleteObject:o];
            }
            
            [self saveMainContext];
            if (completion) completion();
        });
    });
}

- (void) clearObjectSubtree: (NSManagedObject *) object visitedObjects: (NSSet *) visitedObjects{
    if(!object || object.isFault || [visitedObjects containsObject:object]) return;
    
    for (NSRelationshipDescription *rel in object.entity.relationshipsByName.allValues) {
        if ([object hasFaultForRelationshipNamed:rel.name]) continue;
        id relObj = [object valueForKey:rel.name];
        if (rel.isToMany) {
            for (NSManagedObject *o in relObj) {
                [self clearObjectSubtree:o visitedObjects:[visitedObjects setByAddingObject:object]];
            }
        } else [self clearObjectSubtree:relObj visitedObjects:[visitedObjects setByAddingObject:object]];
    }
    [object.managedObjectContext refreshObject:object mergeChanges:NO];
}

- (void) releaseAllObjects: (NSManagedObjectContext *) context {
    for (NSManagedObject *object in context.registeredObjects) {
        [self clearObjectSubtree:object visitedObjects:[NSSet set]];
    }
}


@end
