//
//  SampleConfiguration.m
//  MLLIncrementalSynchronizationDemo
//
//  Created by Marek Lipert on 02.02.2015.
//  Copyright (c) 2015 Lambdarocket. All rights reserved.
//

#import "SampleConfiguration.h"
#import "Book.h"

@implementation SampleConfiguration

- (NSArray *)pullEntities
{
    return @[@"Author",@"Book"];
}

- (NSArray *)pushEntities
{
    return [self pullEntities];
}

- (NSString *)keyAttribute
{
    return @"uuid";
}


- (NSDictionary *)mappingForEntityNamed:(NSString *)entityName
{
    if([entityName isEqual:@"Author"])
    {
        return @{
                 @"name":@"backend_name",
                 @"books":@"backend_books",
                 @"uuid":@"id",
                 @"active":@"backend_active",
                 @"syncRevision":@"sync_revision"
                };
    }
    if([entityName isEqual:@"Book"])
    {
        return @{
                 @"title":@"backend_name",
                 @"authors":@"backend_authors",
                 @"uuid":@"id",
                 @"active":@"backend_active",
                 @"syncRevision":@"sync_revision"
                };
    }
    NSAssert(NO,@"Unknown entity: %@",entityName);
    return nil;
}


- (id) fetchCounterForSynchronizationType:(NSString *)type andEntityName:(NSString *)entityName inContext:(NSManagedObjectContext *)context
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    return [[NSUserDefaults standardUserDefaults] objectForKey:[entityName stringByAppendingString:type]]?:@0;
}

- (NSError *) updateSynchronizationCounters:   (NSDictionary *) counters forType:(NSString *) type inContext:(NSManagedObjectContext *)context
{
    /* You can save it to the db or just... */
    for(NSString *entityName in counters)
        [[NSUserDefaults standardUserDefaults] setObject:counters[entityName] forKey:[entityName stringByAppendingString:type]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    /* but it's not a good solution - counters should be kept in sync with the db */
    return nil;
}


- (NSString *)tableNameForModelName:(NSString *)modelName
{
    NSDictionary *names = @{
                            @"Author":@"authors",
                            @"Book":@"books"
                            };
    return names[modelName];
}

- (NSString *)modelNameForTableName:(NSString *)tableName
{
    NSDictionary *names = @{
                            @"authors":@"Author",
                            @"books":@"Book"
                            };
    return names[tableName];
    
}

- (NSDateFormatter *)dateFormatter
{
    return [NSDateFormatter new];
}

- (NSDictionary *) denormalizationSelectors
{
    return @{
             NSStringFromSelector(@selector(denormalizeAuthorCount:)):@"Book"
            };
}

- (void) denormalizeAuthorCount: (NSDictionary *) booksById
{
    for(Book *book in booksById.allValues)
    {
        book.authorCount = @(book.authors.count);
    }
}



@end
