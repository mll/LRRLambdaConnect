//
//  MLLMapCar.m
//  VideeVin
//
//  Created by Marek Lipert on 24.04.2014.
//  Copyright (c) 2014 Admin. All rights reserved.
//

#import "MLLMapCar.h"

@implementation NSArray(mll_Mapcar)

- (NSArray *) mll_mapCar: (id (^)(id arg)) mapper
{
    __block NSMutableArray *retVal = [NSMutableArray new];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id mapped = mapper(obj);
        if(mapped)
            [retVal addObject:mapped];
    }];
    return retVal;
}

- (NSArray *) mll_sortedArrayUsingOrderArray: (NSArray *) orderArray
{
    return [self sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    return [@([orderArray indexOfObject:obj1]) compare:@([orderArray indexOfObject:obj2])];
    }];
}



- (id) mll_reduce: (id(^)(id arg1, id arg2)) reducer
{
    NSParameterAssert(reducer);
    if(self.count == 0) return nil;
    if(self.count == 1) return self[0];
    id cumulative = self[0];
    for(int i=1;i<self.count;i++) cumulative = reducer(cumulative,self[i]);
    return cumulative;
}

@end

@implementation NSDictionary (mll_Mapcar)
- (NSDictionary *) mll_dictionaryByAddingKeysAndValuesFromDictionary: (NSDictionary *)source
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:self];
    [d addEntriesFromDictionary:source];
    return d;
}

- (NSDictionary *) mll_mapCar: (id (^)(id key, id arg)) mapper
{
    __block NSMutableDictionary *retVal = [NSMutableDictionary dictionaryWithCapacity:self.count];
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id m = mapper(key,obj);
        if(m) [retVal setObject:m forKey:key];
    }];
    return retVal;
}
@end

@implementation NSSet (mll_Mapcar)

- (NSSet *) mll_mapCar: (id (^)(id arg)) mapper
{
    __block NSMutableSet *retVal = [NSMutableSet setWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        id mapped = mapper(obj);
        if(mapped)
            [retVal addObject:mapped];
    }];
    return retVal;
}
@end

@implementation NSOrderedSet (mll_Mapcar)

- (NSOrderedSet *) mll_mapCar: (id (^)(id arg)) mapper
{
    __block NSMutableOrderedSet *retVal = [NSMutableOrderedSet orderedSetWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id obj,NSUInteger idx, BOOL *stop) {
        id mapped = mapper(obj);
        if(mapped)
            [retVal addObject:mapped];
    }];
    return retVal;
}
@end
