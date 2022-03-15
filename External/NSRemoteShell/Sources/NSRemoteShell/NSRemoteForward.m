//
//  NSRemoteForward.m
//  
//
//  Created by Lakr Aream on 2022/3/9.
//

#import "NSRemoteForward.h"

@interface NSRemoteForward ()

@property (nonatomic, readwrite, strong) NSString *targetHost;
@property (nonatomic, readwrite, strong) NSNumber *targetPort;
@property (nonatomic, readwrite, strong) NSNumber *timeout;

@property (nonatomic, nullable, readwrite, assign) LIBSSH2_SESSION *representedSession;
@property (nonatomic, nullable, readwrite, assign) LIBSSH2_LISTENER *representedListener;
@property (nonatomic, nonnull, readwrite, strong) NSMutableArray *forwardSocketPair;

@property (nonatomic, nullable, strong) dispatch_block_t terminationBlock;
@property (nonatomic, nullable, strong) NSRemoteChannelContinuationBlock continuationDecisionBlock;

@property (nonatomic, readwrite) BOOL forwardCompleted;

@end

@implementation NSRemoteForward

- (instancetype)initWithRepresentedSession:(LIBSSH2_SESSION *)representedSession
                   withRepresentedListener:(LIBSSH2_LISTENER *)representedListener
                            withTargetHost:(NSString*)withTargetHost
                            withTargetPort:(NSNumber*)withTargetPort
                               withTimeout:(NSNumber*)withTimeout
{
    self = [super init];
    if (self) {
        _timeout = withTimeout;
        _representedSession = representedSession;
        _representedListener = representedListener;
        _targetHost = withTargetHost;
        _targetPort = withTargetPort;
        _timeout = withTimeout;
        _forwardSocketPair = [[NSMutableArray alloc] init];
        _forwardCompleted = NO;
    }
    return self;
}

- (void)setForwardCompleted:(BOOL)channelCompleted {
    if (_forwardCompleted != channelCompleted) {
        _forwardCompleted = channelCompleted;
        [self unsafeDisconnectAndPrepareForRelease];
    }
}

- (void)onTermination:(dispatch_block_t)terminationHandler {
    self.terminationBlock = terminationHandler;
}
- (void)setContinuationChain:(NSRemoteChannelContinuationBlock)continuation {
    self.continuationDecisionBlock = continuation;
}

- (BOOL)seatbeltCheckPassed {
    if (!self.representedSession) { self.forwardCompleted = YES; return NO; }
    if (!self.representedListener) { self.forwardCompleted = YES; return NO; }
    return YES;
}

- (void)unsafeCallNonblockingOperations {
    if (self.forwardCompleted) { return; }
    if (![self seatbeltCheckPassed]) { return; }
    [self unsafeListenerAccept];
    [self unsafeProcessAllSocket];
    [self unsafeChannelShouldTerminate];
}

- (void)unsafeListenerAccept {
    LIBSSH2_CHANNEL *channel = libssh2_channel_forward_accept(self.representedListener);
    if (!channel) {
        int rc = libssh2_session_last_errno(self.representedSession);
        if (rc != LIBSSH2_ERROR_EAGAIN) { self.forwardCompleted = YES; }
        return;
    }
    NSLog(@"channel forward accepted a channel");
    int socket = [GenericNetworking createSocketWithTargetHost:self.targetHost
                                                withTargetPort:self.targetPort
                                          requireNonblockingIO:YES];
    if (!socket) {
        NSLog(@"failed to create socket to target");
        LIBSSH2_CHANNEL_SHUTDOWN(channel);
        return;
    }
    NSRemoteChannelSocketPair *pair = [[NSRemoteChannelSocketPair alloc] initWithSocket:socket
                                                                            withChannel:channel];
    [self.forwardSocketPair addObject:pair];
}

- (void)unsafeProcessAllSocket {
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (NSRemoteChannelSocketPair *pair in self.forwardSocketPair) {
        if (![pair unsafeInsanityCheckAndReturnDidSuccess]) {
            [pair unsafeDisconnectAndPrepareForRelease];
            continue;
        }
        [pair unsafeCallNonblockingOperations];
        if (![pair unsafeInsanityCheckAndReturnDidSuccess]) {
            [pair unsafeDisconnectAndPrepareForRelease];
            continue;
        }
        [newArray addObject:pair];
    }
    self.forwardSocketPair = newArray;
}

- (BOOL)unsafeChannelShouldTerminate {
    do {
        if (self.continuationDecisionBlock && !self.continuationDecisionBlock()) {
            break;
        }
        return NO;
    } while (0);
    self.forwardCompleted = YES;
    return YES;
}

- (BOOL)unsafeInsanityCheckAndReturnDidSuccess {
    do {
        if (self.forwardCompleted) { break; }
        if (![self seatbeltCheckPassed]) { break; }
        return YES;
    } while (0);
    return NO;
}

- (void)unsafeDisconnectAndPrepareForRelease {
    if (!self.forwardCompleted) { self.forwardCompleted = YES; }
    if (!self.representedSession) { return; }
    if (!self.representedListener) { return; }
    self.representedSession = NULL;
    LIBSSH2_LISTENER *listener = self.representedListener;
    self.representedListener = NULL;
    while (libssh2_channel_forward_cancel(listener) == LIBSSH2_ERROR_EAGAIN) {};
    for (NSRemoteChannelSocketPair *pair in self.forwardSocketPair) {
        [pair unsafeDisconnectAndPrepareForRelease];
    }
    self.forwardSocketPair = [[NSMutableArray alloc] init];
    if (self.terminationBlock) { self.terminationBlock(); }
    self.terminationBlock = NULL;
}


@end
