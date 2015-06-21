//
//  MLLMapCar.h
//  VideeVin
//
//  Created by Marek Lipert on 24.04.2014.
//  Copyright (c) 2014 Admin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSDictionary (mll_Mapcar)
- (NSDictionary *) mll_mapCar: (id (^)(id key, id arg)) mapper;
- (NSDictionary *) mll_dictionaryByAddingKeysAndValuesFromDictionary: (NSDictionary *)source;
@end

@interface NSSet (mll_Mapcar)
- (NSSet *) mll_mapCar: (id (^)(id arg)) mapper;
@end

@interface NSOrderedSet (mll_Mapcar)
- (NSOrderedSet *) mll_mapCar: (id (^)(id arg)) mapper;
@end

@interface NSArray (mll_Mapcar)
- (NSArray *) mll_mapCar: (id (^)(id arg)) mapper;
- (id) mll_reduce: (id(^)(id arg1, id arg2)) reducer;
- (NSArray *) mll_sortedArrayUsingOrderArray: (NSArray *) orderArray;
@end


