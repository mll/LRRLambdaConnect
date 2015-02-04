//
//  BaseEntity.m
//  MLLIncrementalSynchronizationDemo
//
//  Created by Marek Lipert on 02.02.2015.
//  Copyright (c) 2015 Lambdarocket. All rights reserved.
//

#import "BaseEntity.h"
#import "LRRLambdaConnect.h"

@implementation BaseEntity

- (NSString *)getUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString *)string;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    [self setPrimitiveValue:[self getUUID] forKey:@"uuid"];
}

- (void)willSave
{
    [super willSave];
    if(self.hasChanges && self.managedObjectContext == [LRRLambdaConnect sharedInstance].mainContext)  [self setPrimitiveValue:@YES forKey:@"isSuitableForPush"];
}

@end
