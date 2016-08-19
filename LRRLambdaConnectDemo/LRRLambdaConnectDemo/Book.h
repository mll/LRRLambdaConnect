//
//  Book.h
//  LRRLambdaConnectDemo
//
//  Created by Marek Lipert on 02.02.2015.
//  Copyright (c) 2013-2016 Spinney. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BaseEntity.h"

@interface Book : BaseEntity

@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * active;
@property (nonatomic, retain) NSNumber * authorCount;
@property (nonatomic, retain) NSSet *authors;
@end

@interface Book (CoreDataGeneratedAccessors)

- (void)addAuthorsObject:(NSManagedObject *)value;
- (void)removeAuthorsObject:(NSManagedObject *)value;
- (void)addAuthors:(NSSet *)values;
- (void)removeAuthors:(NSSet *)values;

@end
