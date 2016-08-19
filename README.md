# LambdaConnect

LambdaConnect is a solution that enables full, transparent incremental database synchronization between CoreData based iOS application and any incremental backend (we have our own clojure backend that supports the integration).

It allows an app to operate offline without any hassle and the only technology programmers must learn to use it is Core Data itself. It is therefore excellent as a drop-in replacement for other, inferior solutions (e.g. RestKit).
It allows for object creation on iOS side using uuid probabilistic technology.

It is constructed to be versatile and fast. It's memory footprint is as small as possible (using autoreleasepools and refreshObject:mergeChanges:NO to effectively manage the object graph).

The solution supports two encryption layers (SSL for external security and AES-based encryption of the protocol).

See our webpage for success stories. (www.spinney.io) 

## Installation instructions

1. Create a project, prepare managed object model (we suggest you do not use core-data provided inheritance).
2. Create Managed objects from the model.
3. Create one mother class (not in model, just as a class) that inherits from NSManagedObject and implements lifecycle operations common to all entities (such as awakeFromInsert, willSave, etc.) to effectively manage uuid creation and mark-to-send functionality.
4. Make all entities inherit from the mother class (not in CD model, just in objective-C)
5. Copy LRRLambdaConnect and LRRSynchronizationOperation to your porject (just 4 files!)
6. Add stack initialization call to application:didFinishLaunchingWithOptions: (see demo project)
7. Create NetworkDriver and Configuration classes (see demo project).
8. Deploy synchronization calling either - (void) startSynchronizationWithTimeInterval: (NSTimeInterval) interval; or - (void) forceSynchronizationCompletion: (void (^)(NSError *error)) completion
