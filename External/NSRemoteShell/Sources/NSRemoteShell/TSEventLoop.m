//
//  NSRemoteEvent.m
//  
//
//  Created by Lakr Aream on 2022/2/5.
//

// TS: Thread Safe

#import "TSEventLoop.h"

@interface TSEventLoop () 

@property (nonatomic, nonnull, strong) NSThread *associatedThread;
@property (nonatomic, nonnull, strong) NSRunLoop *associatedRunLoop;
@property (nonatomic, nonnull, strong) NSTimer *associatedTimer;
@property (nonatomic, nonnull, strong) NSPort *associatedPort;

@property (nonatomic, nonnull, strong) NSLock *concurrentLock;
@property (nonatomic, nonnull, strong) dispatch_queue_t concurrentQueue;
@property (nonatomic, nonnull, strong) NSHashTable<NSRemoteShell *> *delegatedObjects;

@end

@implementation TSEventLoop

+ (instancetype)sharedLoop {
    static TSEventLoop *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _concurrentQueue = dispatch_queue_create("wiki.qaq.remote.event.concurrent", DISPATCH_QUEUE_CONCURRENT);
        _delegatedObjects = [NSHashTable weakObjectsHashTable];
        _associatedThread = [[NSThread alloc] initWithTarget:self
                                                    selector:@selector(associatedThreadHandler)
                                                      object:NULL];
        _concurrentLock = [[NSLock alloc] init];
        [_associatedThread start];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"deallocating %p", self);
}

- (void)explicitRequestHandle {
    [self.associatedPort sendBeforeDate:[[NSDate alloc] init]
                             components:NULL
                                   from:NULL
                               reserved:NO];
}

- (void)associatedThreadHandler {
    self.associatedRunLoop = [NSRunLoop currentRunLoop];
    
    self.associatedPort = [[NSPort alloc] init];
    self.associatedPort.delegate = self;
    [self.associatedRunLoop addPort:self.associatedPort forMode:NSRunLoopCommonModes];
    
    self.associatedTimer = [[NSTimer alloc] initWithFireDate: [[NSDate alloc] init]
                            interval:0.2
                            target:self selector:@selector(associatedLoopHandler)
                            userInfo:NULL
                            repeats:YES];
    [self.associatedRunLoop addTimer:self.associatedTimer forMode:NSRunLoopCommonModes];
    [self.associatedRunLoop run];
    assert(false);
}

- (void)handleMachMessage:(void *)msg {
    // we don't care about the message, if received any, call handler
    [self associatedLoopHandler];
}

- (void)associatedLoopHandler {
    BOOL tryLock = [self.concurrentLock tryLock];
    if (tryLock) {
        [self processUncheckedLoopDispatch];
        [self.concurrentLock unlock];
    }
}

- (void)delegatingRemoteWith:(NSRemoteShell *)object {
    [self.concurrentLock lock];
    [self.delegatedObjects addObject:object];
    [self.concurrentLock unlock];
}

- (void)processUncheckedLoopDispatch {
    dispatch_group_t group = dispatch_group_create();
    for (NSRemoteShell *delegatedObject in self.delegatedObjects.allObjects) {
        if (!delegatedObject) {
            continue;
        }
        dispatch_group_enter(group);
        dispatch_async(self.concurrentQueue, ^{
            [delegatedObject handleRequestsIfNeeded];
            dispatch_group_leave(group);
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@end
