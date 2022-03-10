//
//  NSLocalForward.m
//  
//
//  Created by Lakr Aream on 2022/3/9.
//

#import "NSLocalForward.h"

@interface NSLocalForward ()

@property (nonatomic, readwrite, strong) NSString *targetHost;
@property (nonatomic, readwrite, strong) NSNumber *targetPort;
@property (nonatomic, readwrite, strong) NSNumber *localPort;
@property (nonatomic, readwrite, strong) NSNumber *timeout;

@property (nonatomic, nullable, readwrite, assign) LIBSSH2_SESSION *representedSession;
@property (nonatomic, readwrite, assign) int representedSocket;
@property (nonatomic, nonnull, readwrite, strong) NSMutableArray *forwardSocketPair;
@property (nonatomic, nullable, strong) dispatch_block_t terminationBlock;
@property (nonatomic, nullable, strong) NSRemoteChannelContinuationBlock continuationDecisionBlock;
@property (nonatomic, readwrite) BOOL forwardCompleted;

@end

@implementation NSLocalForward

- (instancetype)initWithRepresentedSession:(LIBSSH2_SESSION *)representedSession
                     withRepresentedSocket:(int)socketDescriptor
                            withTargetHost:(NSString*)withTargetHost
                            withTargetPort:(NSNumber*)withTargetPort
                             withLocalPort:(NSNumber*)withLocalPort
                               withTimeout:(NSNumber *)withTimeout
{
    self = [super init];
    if (self) {
        _targetHost = withTargetHost;
        _targetPort = withTargetPort;
        _localPort = withLocalPort;
        _timeout = withTimeout;
        _representedSession = representedSession;
        _representedSocket = socketDescriptor;
        _forwardSocketPair = [[NSMutableArray alloc] init];
        _forwardCompleted = NO;
    }
    return self;
}

- (void)onTermination:(dispatch_block_t)terminationHandler {
    self.terminationBlock = terminationHandler;
}

- (void)setContinuationChain:(NSRemoteChannelContinuationBlock _Nonnull)continuation {
    self.continuationDecisionBlock = continuation;
}

- (void)setForwardCompleted:(BOOL)channelCompleted {
    if (_forwardCompleted != channelCompleted) {
        _forwardCompleted = channelCompleted;
        [self uncheckedConcurrencyDisconnectAndPrepareForRelease];
    }
}

- (BOOL)seatbeltCheckPassed {
    if (!self.representedSession) { self.forwardCompleted = YES; return NO; }
    if (!self.representedSocket) { self.forwardCompleted = YES; return NO; }
    return YES;
}

- (void)uncheckedConcurrencyCallNonblockingOperations {
    if (self.forwardCompleted) { return; }
    if (![self seatbeltCheckPassed]) { return; }
    [self uncheckedConcurrencyChannelMainSocketAccept];
    [self uncheckedConcurrencyProcessAllSocket];
    [self uncheckedConcurrencyChannelShouldTerminate];
}

- (void)uncheckedConcurrencyProcessAllSocket {
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (NSRemoteChannelSocketPair *pair in self.forwardSocketPair) {
        if (![pair uncheckedConcurrencyInsanityCheckAndReturnDidSuccess]) {
            [pair uncheckedConcurrencyDisconnectAndPrepareForRelease];
            continue;
        }
        [pair uncheckedConcurrencyCallNonblockingOperations];
        if (![pair uncheckedConcurrencyInsanityCheckAndReturnDidSuccess]) {
            [pair uncheckedConcurrencyDisconnectAndPrepareForRelease];
            continue;
        }
        [newArray addObject:pair];
    }
    self.forwardSocketPair = newArray;
}

- (void)uncheckedConcurrencyChannelMainSocketAccept {
    while (1) {
        struct sockaddr_in peeraddr;
        socklen_t peeraddrlen = sizeof(peeraddr);
        getpeername(STDIN_FILENO, (struct sockaddr*)&peeraddr, &peeraddrlen);
        int forwardsock = accept(self.representedSocket, (struct sockaddr *)&sin, &peeraddrlen);
        if (forwardsock <= 0) { return; }
        NSLog(@"accept is returning child socket %d", forwardsock);
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.timeout intValue]];
        LIBSSH2_CHANNEL *channel = NULL;
        while (true) {
            if ([date timeIntervalSinceNow] < 0) {
                libssh2_session_set_last_error(self.representedSession, LIBSSH2_ERROR_TIMEOUT, NULL);
                break;
            }
            LIBSSH2_CHANNEL *channelBuilder = libssh2_channel_direct_tcpip_ex(self.representedSession,
                                                                              [self.targetHost UTF8String],
                                                                              [self.targetPort intValue],
                                                                              "127.0.0.1",
                                                                              [self.localPort intValue]);
            if (channelBuilder) {
                channel = channelBuilder;
                break;
            }
            long rc = libssh2_session_last_errno(self.representedSession);
            if (rc == LIBSSH2_ERROR_EAGAIN) {
                continue;
            }
            break;
        }
        if (!channel) {
            NSLog(@"accepted connection failed to open channel");
            close(forwardsock);
            [self uncheckedConcurrencyDisconnectAndPrepareForRelease];
            return;
        }
        NSLog(@"created channel for forward socket %d %p", forwardsock, channel);
        NSRemoteChannelSocketPair *pair = [[NSRemoteChannelSocketPair alloc] initWithSocket:forwardsock
                                                                                withChannel:channel];
        [self.forwardSocketPair addObject:pair];
    }
}

- (BOOL)uncheckedConcurrencyChannelShouldTerminate {
    do {
        if (self.continuationDecisionBlock && !self.continuationDecisionBlock()) {
            break;
        }
        return NO;
    } while (0);
    self.forwardCompleted = YES;
    return YES;
}

- (BOOL)uncheckedConcurrencyInsanityCheckAndReturnDidSuccess {
    do {
        if (self.forwardCompleted) { break; }
        if (![self seatbeltCheckPassed]) { break; }
        return YES;
    } while (0);
    return NO;
}

- (void)uncheckedConcurrencyDisconnectAndPrepareForRelease {
    if (!self.forwardCompleted) { self.forwardCompleted = YES; }
    if (!self.representedSession) { return; }
    if (!self.representedSocket) { return; }
    int socket = self.representedSocket;
    [GenericNetworking destroyNativeSocket:socket];
    self.representedSession = NULL;
    self.representedSocket = NULL;
    for (NSRemoteChannelSocketPair *pair in self.forwardSocketPair) {
        [pair uncheckedConcurrencyDisconnectAndPrepareForRelease];
    }
    self.forwardSocketPair = [[NSMutableArray alloc] init];
    if (self.terminationBlock) { self.terminationBlock(); }
    self.terminationBlock = NULL;
}

@end
