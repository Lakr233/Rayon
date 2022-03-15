//
//  NSRemoteShell.m
//
//
//  Created by Lakr Aream on 2022/2/4.
//

#import "NSRemoteShell.h"

#import "TSEventLoop.h"

#import "NSRemoteChannel.h"
#import "NSLocalForward.h"
#import "NSRemoteForward.h"

#import "GenericHeaders.h"
#import "GenericNetworking.h"

#import "Constructor.h"

@interface NSRemoteShell ()

@property (nonatomic, readwrite, assign) BOOL destroyed;

@property (nonatomic, readonly, nonnull, strong) TSEventLoop *associatedLoop;

@property (nonatomic, readwrite, nonnull, strong) NSString *remoteHost;
@property (nonatomic, readwrite, nonnull, strong) NSNumber *remotePort;
@property (nonatomic, readwrite, nonnull, strong) NSNumber *operationTimeout;

@property (nonatomic, readwrite, nullable, strong) NSString *resolvedRemoteIpAddress;
@property (nonatomic, readwrite, nullable, strong) NSString *remoteBanner;
@property (nonatomic, readwrite, nullable, strong) NSString *remoteFingerPrint;
@property (nonatomic, readwrite, nullable, strong) NSString *lastError;

@property (nonatomic, readwrite, getter=isConnected) BOOL connected;
@property (nonatomic, readwrite, getter=isConnectedSFTP) BOOL connectedSFTP;
@property (nonatomic, readwrite, getter=isAuthenicated) BOOL authenticated;

@property (nonatomic, readwrite, assign) int associatedSocket;
@property (nonatomic, readwrite, nullable, assign) LIBSSH2_SESSION *associatedSession;
@property (nonatomic, readwrite, nullable, assign) LIBSSH2_SFTP *associatedSFTP;
@property (nonatomic, readwrite, nullable, strong) dispatch_source_t associatedSocketSource;

@property (nonatomic, readwrite, nonnull, strong) NSMutableArray<id<NSRemoteOperableObject>> *operableObjects;
@property (nonatomic, readwrite, nonnull, strong) NSMutableArray *requestInvokations;
@property (nonatomic, readwrite, nonnull, strong) NSLock *requestLoopLock;

@property (nonatomic, readwrite, assign) unsigned keepAliveAttampt;
@property (nonatomic, readwrite, nullable, strong) NSDate *keepAliveLastSuccessAttampt;

@end

@implementation NSRemoteShell

#pragma mark init

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _destroyed = NO;
        _associatedLoop = [[TSEventLoop alloc] initWithParent:self];
        _remoteHost = @"";
        _remotePort = @(22);
        _operationTimeout = @(8);
        _connected = NO;
        _authenticated = NO;
        _resolvedRemoteIpAddress = NULL;
        _lastError = NULL;
        _associatedSocket = NULL;
        _associatedSession = NULL;
        _associatedSFTP = NULL;
        _operableObjects = [[NSMutableArray alloc] init];
        _requestInvokations = [[NSMutableArray alloc] init];
        _requestLoopLock = [[NSLock alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    self.destroyed = YES;
    NSLog(@"shell object at %p deallocating", self);
    [self.requestLoopLock lock];
    [self unsafeDisconnect];
    [self.associatedLoop destroyLoop];
    [self.requestLoopLock unlock];
}

- (void)destroyPermanently {
    if (self.destroyed) { return; }
    self.destroyed = YES;
    NSLog(@"shell object at %p destroy permanently", self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.requestLoopLock lock];
        [self.associatedLoop destroyLoop];
        [self unsafeDisconnect];
        // so there won't be any connect request semaphore f***ing us
        for (dispatch_block_t invocation in self.requestInvokations) {
            if (invocation) { invocation(); }
        }
        // call again to make sure no connect invocation
        [self unsafeDisconnect];
        [self.requestInvokations removeAllObjects];
        // and no more semaphore sitting there in sub channels
        for (id<NSRemoteOperableObject> object in [self.operableObjects copy]) {
            [object unsafeDisconnectAndPrepareForRelease];
        }
        [self.operableObjects removeAllObjects];
        // should cancel any source
        [self unsafeDispatchSourceMakeDecision];
        [self.requestLoopLock unlock];
    });
}

- (instancetype)setupConnectionHost:(NSString *)targetHost {
    @synchronized(self) {
        [self setRemoteHost:targetHost];
    }
    return self;
}

- (instancetype)setupConnectionPort:(NSNumber *)targetPort {
    @synchronized(self) {
        [self setRemotePort:targetPort];
    }
    return self;
}

- (instancetype)setupConnectionTimeout:(NSNumber *)timeout {
    if (timeout.doubleValue < 1) {
        NSLog(@"setting timeout value %@ below 1 is not supported", [timeout stringValue]);
#if DEBUG
        NSLog(@"for debug purpose, call ivar setter on operationTimeout with a NSNumber");
#endif
        return;
    }
    @synchronized(self) {
        [self setOperationTimeout:timeout];
    }
    return self;
}

// MARK: - EVENT LOOP

- (void)handleRequestsIfNeeded {
    if (![self.requestLoopLock tryLock]) {
        return;
    }
    @synchronized (self.requestInvokations) {
        for (dispatch_block_t invocation in self.requestInvokations) {
            if (invocation) { invocation(); }
        }
        [self.requestInvokations removeAllObjects];
        [self unsafeKeepAliveCheck];
        [self unsafeDispatchSourceMakeDecision];
        NSMutableArray *newArray = [[NSMutableArray alloc] init];
        for (id<NSRemoteOperableObject> object in [self.operableObjects copy]) {
#define NSRemoteOperableObjectCheck(OBJECT) \
do { \
if (!(OBJECT)) { continue; } \
if (![(OBJECT) unsafeInsanityCheckAndReturnDidSuccess]) { \
[(OBJECT) unsafeDisconnectAndPrepareForRelease]; \
continue; \
} \
} while (0);
            NSRemoteOperableObjectCheck(object);
            [object unsafeCallNonblockingOperations];
            NSRemoteOperableObjectCheck(object);
            [newArray addObject:object];
        }
        self.operableObjects = newArray;
        [self unsafeDispatchSourceMakeDecision];
    }
    [self unsafeReadLastError];
    [self.requestLoopLock unlock];
}

- (void)explicitRequestStatusPickup {
    @synchronized (self.associatedLoop) {
        [self.associatedLoop explicitRequestHandle];
    }
}

// MARK: - API

- (void)requestConnectAndWait {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeConnect];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self explicitRequestStatusPickup];
    MakeDispatchSemaphoreWait(sem)
}

- (void)requestDisconnectAndWait {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeDisconnect];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)authenticateWith:(NSString *)username andPassword:(NSString *)password {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeAuthenticateWith:username
                                            andPassword:password];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWait(sem)
}

- (void)authenticateWith:(NSString *)username andPublicKey:(NSString *)publicKey andPrivateKey:(NSString *)privateKey andPassword:(NSString *)password {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeAuthenticateWith:username
                                           andPublicKey:publicKey
                                          andPrivateKey:privateKey
                                            andPassword:password];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWait(sem)
}

- (int)beginExecuteWithCommand:(NSString*)withCommand
                   withTimeout:(NSNumber*)withTimeoutSecond
                  withOnCreate:(dispatch_block_t)withOnCreate
                    withOutput:(nullable void (^)(NSString*))withOutput
       withContinuationHandler:(nullable BOOL (^)(void))withContinuationBlock {
    if (self.destroyed) return;
    __block int exitCode = 0;
    NSLog(@"requesting execute: %@", withCommand);
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeExecuteRemote:withCommand
                                     withExecTimeout:withTimeoutSecond
                                        withOnCreate:withOnCreate
                                          withOutput:withOutput
                             withContinuationHandler:withContinuationBlock
                                     withSetExitCode:&exitCode
                             withCompletionSemaphore:sem];
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return exitCode;
}

- (void)beginShellWithTerminalType:(nullable NSString*)withTerminalType
                              withOnCreate:(dispatch_block_t)withOnCreate
                          withTerminalSize:(nullable CGSize (^)(void))withRequestTerminalSize
                       withWriteDataBuffer:(nullable NSString* (^)(void))withWriteDataBuffer
                      withOutputDataBuffer:(void (^)(NSString * _Nonnull))withOutputDataBuffer
                   withContinuationHandler:(BOOL (^)(void))withContinuationBlock;
{
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeOpenShellWithTerminal:withTerminalType
                                            withTerminalSize:withRequestTerminalSize
                                               withWriteData:withWriteDataBuffer
                                                  withOutput:withOutputDataBuffer
                                                withOnCreate:withOnCreate
                                     withContinuationHandler:withContinuationBlock
                                     withCompletionSemaphore:sem];
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)createPortForwardWithLocalPort:(NSNumber *)localPort
                         withForwardTargetHost:(NSString *)targetHost
                         withForwardTargetPort:(NSNumber *)targetPort
                                  withOnCreate:(dispatch_block_t)withOnCreate
                       withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeCreatePortForwardWithLocalPort:localPort
                                                withForwardTargetHost:targetHost
                                                withForwardTargetPort:targetPort
                                                         withOnCreate:withOnCreate
                                              withContinuationHandler:continuationBlock
                                              withCompletionSemaphore:sem];
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)createPortForwardWithRemotePort:(NSNumber *)remotePort
                          withForwardTargetHost:(NSString *)targetHost
                          withForwardTargetPort:(NSNumber *)targetPort
                                   withOnCreate:(dispatch_block_t)withOnCreate
                        withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeCreatePortForwardWithRemotePort:remotePort
                                                 withForwardTargetHost:targetHost
                                                 withForwardTargetPort:targetPort
                                                          withOnCreate:withOnCreate
                                               withContinuationHandler:continuationBlock
                                               withCompletionSemaphore:sem];
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)requestConnectSFTPAndWait {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeConnectSFTPWithCompleteBlock:^{
                DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
            }];
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWait(sem);
}
- (void)requestDisconnectSFTPAndWait {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [self unsafeSFTPCloseFor:self.associatedSFTP];
            self.associatedSFTP = NULL;
            self.connectedSFTP = NO;
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWait(sem);
}

- (nullable NSArray<NSRemoteFile *> *)requestFileListAt:(NSString *)atDirPath {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block NSArray<NSRemoteFile*>* result = NULL;
    @synchronized (self.requestInvokations) {
        id block = [^{
            result = [magic unsafeGetDirFileListAt:atDirPath];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWait(sem);
    return result;
}

- (nullable NSRemoteFile *)requestFileInfoAt:(NSString *)atPath {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block NSRemoteFile *result = NULL;
    @synchronized (self.requestInvokations) {
        id block = [^{
            result = [magic unsafeGetFileInfo:atPath];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWait(sem);
    return result;
}

// MARK: - HELPER

- (nullable NSString *)getLastError {
    NSString *result;
    @synchronized (self.lastError) {
        result = self.lastError;
        self.lastError = NULL;
    }
    if ([result isEqualToString:@""]) {
        return NULL;
    }
    return result;
}

// MARK: - UNCHECKED CONCURRENCY

- (void)unsafeConnect {
    [self unsafeDisconnect];
    
    int sock = [GenericNetworking createSocketWithTargetHost:self.remoteHost
                                              withTargetPort:self.remotePort
                                        requireNonblockingIO:NO];
    if (!sock) {
        NSLog(@"failed to create socket to host");
        return;
    }
    self.associatedSocket = sock;
    
    self.resolvedRemoteIpAddress = [GenericNetworking getResolvedIpAddressWith:sock];
    
    LIBSSH2_SESSION *constructorSession = libssh2_session_init_ex(0, 0, 0, (__bridge void *)(self));
    if (!constructorSession) {
        [self unsafeDisconnect];
        return;
    }
    self.associatedSession = constructorSession;
    
    libssh2_session_set_timeout(constructorSession, [self.operationTimeout doubleValue] * 1000);
    
    libssh2_session_set_blocking(constructorSession, 0);
    BOOL sessionHandshakeComplete = NO;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(self.associatedSession, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        long rc = libssh2_session_handshake(constructorSession, sock);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        sessionHandshakeComplete = (rc == 0);
        break;
    }
    if (!sessionHandshakeComplete) {
        [self unsafeDisconnect];
        return;
    }
    
    do {
        const char *banner = libssh2_session_banner_get(constructorSession);
        if (banner) {
            NSString *generateBanner = [[NSString alloc] initWithUTF8String:banner];
            self.remoteBanner = generateBanner;
        }
    } while (0);
    
    do {
        const char *hash = libssh2_hostkey_hash(constructorSession, LIBSSH2_HOSTKEY_HASH_SHA1);
        if (hash) {
            NSMutableString *fingerprint = [[NSMutableString alloc]
                                            initWithFormat:@"%02X", (unsigned char)hash[0]];
            for (int i = 1; i < 20; i++) {
                [fingerprint appendFormat:@":%02X", (unsigned char)hash[i]];
            }
            self.remoteFingerPrint = [fingerprint copy];
        }
    } while (0);
    
    // because we are running non-blocking-mode
    // we are responsible for sending the keep alive packet
    // we set the interval value as smallest
    // so wont case other problem (not 1 but 2)
    libssh2_keepalive_config(constructorSession, 0, 2);
    
    self.connected = YES;
    NSLog(@"constructed libssh2 session to %@ with %@", self.remoteHost, self.resolvedRemoteIpAddress);
}

- (void)unsafeDisconnect {
    for (id<NSRemoteOperableObject> object in [self.operableObjects copy]) {
        if (object) { [object unsafeDisconnectAndPrepareForRelease]; }
    }
    self.operableObjects = [[NSMutableArray alloc] init];
    
    [self unsafeSFTPCloseFor:self.associatedSFTP];
    self.associatedSFTP = NULL;
    self.connectedSFTP = NO;
    
    [self unsafeSessionCloseFor:self.associatedSession];
    self.associatedSession = NULL;
    self.connected = NO;
    self.authenticated = NO;
    
    if (self.associatedSocket) {
        [GenericNetworking destroyNativeSocket:self.associatedSocket];
    }
    self.associatedSocket = NULL;
    
    self.resolvedRemoteIpAddress = NULL;
    self.remoteBanner = NULL;
    self.remoteFingerPrint = NULL;
    
    self.keepAliveAttampt = 0;
    self.keepAliveLastSuccessAttampt = NULL;
    
    // any error occurred during connect will result disconnect
    [self unsafeReadLastError];
}

- (void)unsafeDispatchSourceMakeDecision {
    if ([self.operableObjects count] > 0) {
        if (!self.associatedSocketSource) {
            dispatch_source_t socketDataSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                                                        self.associatedSocket,
                                                                        NULL,
                                                                        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
            if (!socketDataSource) {
                NSLog(@"failed to create dispatch source for socket");
                [self unsafeDisconnect];
                return;
            }
            dispatch_source_set_event_handler(socketDataSource, ^{
                [self.associatedLoop explicitRequestHandle];
            });
            dispatch_resume(socketDataSource);
            self.associatedSocketSource = socketDataSource;
        }
    } else {
        if (self.associatedSocketSource) {
            dispatch_source_cancel(self.associatedSocketSource);
            self.associatedSocketSource = NULL;
        }
    }
}

- (void)unsafeKeepAliveCheck {
    // some ssh impl wont accept keep alive if not and may break connection
    if (!(self.isConnected && self.isAuthenicated)) {
        return;
    }
    
    // the session is valid, check if last success attempt is shorter than interval
    if (self.keepAliveLastSuccessAttampt) {
        NSDate *nextRun = [self.keepAliveLastSuccessAttampt dateByAddingTimeInterval:KEEPALIVE_INTERVAL];
        if ([nextRun timeIntervalSinceNow] >= 0) {
            return;
        }
    }
    
    // now sending the keep alive packet
    self.keepAliveAttampt += 1;
    int nextInterval = 0;
    int retVal = libssh2_keepalive_send(self.associatedSession, &nextInterval);
    
    //Returns 0 on success, or LIBSSH2_ERROR_SOCKET_SEND on I/O errors.
    if (retVal == 0) {
        self.keepAliveLastSuccessAttampt = [[NSDate alloc] init];
        self.keepAliveAttampt = 0;
    } else {
        // treat anything else as error and close if retry too much times
        if (self.keepAliveAttampt > KEEPALIVE_ERROR_TOLERANCE_MAX_RETRY) {
            NSLog(@"shell object at %p closing session due to broken pipe", self);
            [self unsafeDisconnect];
            return;
        }
        return;
    }
}

- (void)unsafeReadLastError {
    if (!self.associatedSession) { return; }
    int rv = libssh2_session_last_errno(self.associatedSession);
    if (rv == 0 || rv == LIBSSH2_ERROR_EAGAIN) {
        return; // reset when get
    }
    char *msg;
    int len;
    int rrv = libssh2_session_last_error(self.associatedSession, &msg, &len, 0);
    // clear error since we have it
    libssh2_session_set_last_error(self.associatedSession, 0, NULL);
    NSString *message = [[NSString alloc] initWithUTF8String:msg];
    NSLog(@"shell object at %p setting last error %d %@", self, rrv, message);
    @synchronized (self.lastError) {
        self.lastError = message;
    }
}

- (void)unsafeSFTPCloseFor:(LIBSSH2_SFTP*)sftp {
    if (!sftp) return;
    while (libssh2_sftp_shutdown(sftp) == LIBSSH2_ERROR_EAGAIN) {};
}

- (void)unsafeSessionCloseFor:(LIBSSH2_SESSION*)session {
    if (!session) return;
    while (libssh2_session_disconnect(session, "closed by client") == LIBSSH2_ERROR_EAGAIN) {};
    while (libssh2_session_free(session) == LIBSSH2_ERROR_EAGAIN) {};
}

- (BOOL)unsafeValidateSession {
    do {
        if (!self.associatedSocket) { break; }
        if (!self.associatedSession) { break; }
        if (!self.connected) { break; }
        return YES;
    } while (0);
    [self unsafeDisconnect];
    return NO;
}

- (BOOL)unsafeValidateSessionSFTP {
    do {
        if (!self.associatedSocket) { break; }
        if (!self.associatedSession) { break; }
        if (!self.connected) { break; }
        if (!self.isAuthenicated) { break; }
        if (!self.associatedSFTP) { break; }
        return YES;
    } while (0);
    [self unsafeDisconnect];
    return NO;
}

- (void)unsafeAuthenticateWith:(NSString *)username
                                 andPassword:(NSString *)password {
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        return;
    }
    if (self.authenticated) {
        return;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    BOOL authenticated = NO;
    while (true) {
        int rc = libssh2_userauth_password(session, [username UTF8String], [password UTF8String]);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        authenticated = (rc == 0);
        break;
    }
    [self unsafeReadLastError];
    if (authenticated) {
        self.authenticated = YES;
        NSLog(@"authenticate success");
    }
}

- (void)unsafeAuthenticateWith:(NSString *)username
                                andPublicKey:(NSString *)publicKey
                               andPrivateKey:(NSString *)privateKey
                                 andPassword:(NSString *)password {
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        return;
    }
    if (self.authenticated) {
        return;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    BOOL authenticated = NO;
    while (true) {
        int rc = libssh2_userauth_publickey_frommemory(session,
                                                       [username UTF8String], [username length],
                                                       [publicKey UTF8String] ?: nil, [publicKey length] ?: 0,
                                                       [privateKey UTF8String] ?: nil, [privateKey length] ?: 0,
                                                       [password UTF8String]);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        authenticated = (rc == 0);
        break;
    }
    [self unsafeReadLastError];
    if (authenticated) {
        self.authenticated = YES;
        NSLog(@"authenticate success");
    }
}

- (void)unsafeExecuteRemote:(NSString *)command
                          withExecTimeout:(NSNumber *)timeoutSecond
                             withOnCreate:(dispatch_block_t)withOnCreate
                               withOutput:(void (^)(NSString * _Nonnull))responseDataBlock
                  withContinuationHandler:(BOOL (^)(void))continuationBlock
                          withSetExitCode:(int*)exitCode
                  withCompletionSemaphore:(dispatch_semaphore_t)completionSemaphore
{
    if (exitCode) { *exitCode = 0; }
    
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    if (!self.authenticated) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_CHANNEL *channel = NULL;
    
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(self.associatedSession, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_CHANNEL *channelBuilder = libssh2_channel_open_session(session);
        if (channelBuilder) {
            channel = channelBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!channel) {
        NSLog(@"failed to allocate channel");
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    NSRemoteChannel *channelObject = [[NSRemoteChannel alloc] initWithRepresentedSession:session
                                                                   withRepresentedChanel:channel];
    
    BOOL channelStartupCompleted = NO;
    while (true) {
        long rc = libssh2_channel_exec(channel, [command UTF8String]);
        if (rc == LIBSSH2_ERROR_EAGAIN) { continue; }
        channelStartupCompleted = (rc == 0);
        break;
    }
    if (!channelStartupCompleted) {
        [channelObject unsafeDisconnectAndPrepareForRelease];
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    
    if ([timeoutSecond doubleValue] > 0) {
        [channelObject setChannelTimeoutWith:[timeoutSecond doubleValue]];
    }
    
    if (responseDataBlock) { [channelObject setRecivedDataChain:responseDataBlock]; }
    if (continuationBlock) { [channelObject setContinuationChain:continuationBlock]; }
    
    if (completionSemaphore) {
        [channelObject onTermination:^{
            *exitCode = channelObject.exitStatus;
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        }];
    }
    
    [self.operableObjects addObject:channelObject];
    if (withOnCreate) { withOnCreate(); }
}

- (void)unsafeOpenShellWithTerminal:(nullable NSString*)terminalType
                                 withTerminalSize:(nullable CGSize (^)(void))requestTerminalSize
                                    withWriteData:(nullable NSString* (^)(void))requestWriteData
                                       withOutput:(void (^)(NSString * _Nonnull))responseDataBlock
                                     withOnCreate:(dispatch_block_t)withOnCreate
                          withContinuationHandler:(BOOL (^)(void))continuationBlock
                          withCompletionSemaphore:(dispatch_semaphore_t)completionSemaphore {
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    if (!self.authenticated) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_CHANNEL *channel = NULL;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(self.associatedSession, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_CHANNEL *channelBuilder = libssh2_channel_open_session(session);
        if (channelBuilder) {
            channel = channelBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!channel) {
        NSLog(@"failed to allocate channel");
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    NSRemoteChannel *channelObject = [[NSRemoteChannel alloc] initWithRepresentedSession:session
                                                                   withRepresentedChanel:channel];
    if (requestTerminalSize) { [channelObject setTerminalSizeChain:requestTerminalSize]; }
    if (requestWriteData) { [channelObject setRequestDataChain:requestWriteData]; }
    if (responseDataBlock) { [channelObject setRecivedDataChain:responseDataBlock]; }
    if (continuationBlock) { [channelObject setContinuationChain:continuationBlock]; }
    
    do {
        NSString *requestPseudoTermial = @"xterm";
        if (terminalType) { requestPseudoTermial = terminalType; }
        BOOL requestedPty = NO;
        while (true) {
            long rc = libssh2_channel_request_pty(channel, [requestPseudoTermial UTF8String]);
            if (rc == LIBSSH2_ERROR_EAGAIN) {
                continue;
            }
            requestedPty = (rc == 0);
            break;
        }
        if (!requestedPty) {
            NSLog(@"failed to request pty");
            [channelObject unsafeDisconnectAndPrepareForRelease];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
            return;
        }
    } while (0);
    
    [channelObject unsafeChannelTerminalSizeUpdate];
    
    do {
        BOOL channelStartupCompleted = NO;
        while (true) {
            long rc = libssh2_channel_shell(channel);
            if (rc == LIBSSH2_ERROR_EAGAIN) { continue; }
            channelStartupCompleted = (rc == 0);
            break;
        }
        if (!channelStartupCompleted) {
            [channelObject unsafeDisconnectAndPrepareForRelease];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
            return;
        }
    } while (0);
    
    if (completionSemaphore) {
        [channelObject onTermination:^{
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        }];
    }
    
    [self.operableObjects addObject:channelObject];
    if (withOnCreate) { withOnCreate(); }
}

- (void)unsafeCreatePortForwardWithLocalPort:(NSNumber *)localPort
                                     withForwardTargetHost:(NSString *)targetHost
                                     withForwardTargetPort:(NSNumber *)targetPort
                                              withOnCreate:(dispatch_block_t)withOnCreate
                                   withContinuationHandler:(BOOL (^)(void))continuationBlock
                                   withCompletionSemaphore:(dispatch_semaphore_t)completionSemaphore
{
    NSLog(@"requested port forward from localhost:%@ --tunnel--> %@:%@", [localPort stringValue], targetHost, [targetPort stringValue]);
    BOOL invalid = NO ||
    ![GenericNetworking isValidateWithPort:localPort] ||
    ![GenericNetworking isValidateWithPort:targetPort] ||
    [targetHost isEqualToString:@""];
    if (invalid) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        NSLog(@"invalid parameter was found");
        return;
    }
    
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    if (!self.authenticated) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    
    int sock4 = [GenericNetworking createSocketNonblockingListenerWithLocalPort:localPort];
    if (sock4 <= 0) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    
    NSLog(@"processing channel startup for direct tcpip");
    
    LIBSSH2_SESSION *session = self.associatedSession;
    NSLocalForward *operator = [[NSLocalForward alloc] initWithRepresentedSession:session
                                                            withRepresentedSocket:sock4
                                                                   withTargetHost:targetHost
                                                                   withTargetPort:targetPort
                                                                    withLocalPort:localPort
                                                                      withTimeout:self.operationTimeout
    ];
    
    [operator setContinuationChain:continuationBlock];
    
    if (completionSemaphore) {
        [operator onTermination:^{
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        }];
    }
    
    [self.operableObjects addObject:operator];
    if (withOnCreate) { withOnCreate(); }
}

- (void)unsafeCreatePortForwardWithRemotePort:(NSNumber *)remotePort
                                      withForwardTargetHost:(NSString *)targetHost
                                      withForwardTargetPort:(NSNumber *)targetPort
                                               withOnCreate:(dispatch_block_t)withOnCreate
                                    withContinuationHandler:(BOOL (^)(void))continuationBlock
                                    withCompletionSemaphore:(dispatch_semaphore_t)completionSemaphore
{
    NSLog(@"requested port forward from remote:%@ --tunnel--> %@:%@", [remotePort stringValue], targetHost, [targetPort stringValue]);
    BOOL invalid = NO ||
    ![GenericNetworking isValidateWithPort:remotePort] ||
    ![GenericNetworking isValidateWithPort:targetPort] ||
    [targetHost isEqualToString:@""];
    if (invalid) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        NSLog(@"invalid parameter was found");
        return;
    }
    
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    if (!self.authenticated) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        return;
    }
    
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_LISTENER *listener = NULL;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(self.associatedSession, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_LISTENER *builder = libssh2_channel_forward_listen_ex(session,
                                                                      "127.0.0.1", // for security reason
                                                                      [remotePort intValue],
                                                                      NULL,
                                                                      SOCKET_QUEUE_MAXSIZE);
        if (builder) {
            listener = builder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        // it's a bug
        // looks like libssh2 reading with dirty memory data
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!listener) {
        DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        NSLog(@"libssh2_channel_forward_listen_ex was not able to receive listener");
        return;
    }
    
    NSRemoteForward *operator = [[NSRemoteForward alloc] initWithRepresentedSession:session
                                                            withRepresentedListener:listener
                                                                     withTargetHost:targetHost
                                                                     withTargetPort:targetPort
                                                                        withTimeout:self.operationTimeout];
    [operator setContinuationChain:continuationBlock];
    
    if (completionSemaphore) {
        [operator onTermination:^{
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(completionSemaphore);
        }];
    }
    
    [self.operableObjects addObject:operator];
    if (withOnCreate) { withOnCreate(); }
}

- (void)unsafeConnectSFTPWithCompleteBlock:(dispatch_block_t)withComplete {
    if (![self unsafeValidateSession]) {
        [self unsafeDisconnect];
        if (withComplete) withComplete();
        return;
    }
    if (!self.authenticated) {
        if (withComplete) withComplete();
        return;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = NULL;
    
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(self.associatedSession, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_SFTP *sftpBuilder = libssh2_sftp_init(session);
        if (sftpBuilder) {
            sftp = sftpBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!sftp) {
        if (withComplete) withComplete();
        NSLog(@"libssh2_sftp_init was not able to receive session");
        return;
    }
    
    self.associatedSFTP = sftp;
    self.connectedSFTP = YES;
    NSLog(@"libssh2_sftp_init success");
    if (withComplete) withComplete();
}

- (nullable LIBSSH2_SFTP_HANDLE*)unsafeSFTPOpenDirHandlerWithSession:(LIBSSH2_SESSION*)session
                                                            withSFTP:(LIBSSH2_SFTP*)sftp
                                                            withPath:(NSString*)path
{
    LIBSSH2_SFTP_HANDLE *handler = NULL;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_SFTP_HANDLE *handlerBuilder = libssh2_sftp_opendir(sftp, [path UTF8String]);
        if (handlerBuilder) {
            handler = handlerBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    return handler;
}

- (nullable LIBSSH2_SFTP_HANDLE*)unsafeSFTPOpenFileHandlerWithSession:(LIBSSH2_SESSION*)session
                                                             withSFTP:(LIBSSH2_SFTP*)sftp
                                                             withPath:(NSString*)path
                                                             withFlag:(unsigned long)flags
                                                             withMode:(long)mode
{
    LIBSSH2_SFTP_HANDLE *handler = NULL;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_SFTP_HANDLE *handlerBuilder = libssh2_sftp_open(sftp, [path UTF8String], flags, mode);
        if (handlerBuilder) {
            handler = handlerBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    return handler;
}

- (nullable NSArray<NSRemoteFile*>*)unsafeGetDirFileListAt:(NSString*)withDirPath {
    if (![self unsafeValidateSessionSFTP]) { return NULL; }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedSFTP;
    LIBSSH2_SFTP_HANDLE *handle = [self unsafeSFTPOpenDirHandlerWithSession:session
                                                                   withSFTP:sftp
                                                                   withPath:withDirPath];
    if (!handle) {
        NSLog(@"SFTP failed to open handler for dir: %@", withDirPath);
        return NULL;
    }

    NSArray *ignoredFiles = @[@".", @".."];
    NSMutableArray *contents = [NSMutableArray array];

    int rc = 0;
    do {
        char buffer[512];
        memset(buffer, 0, sizeof(buffer));
        LIBSSH2_SFTP_ATTRIBUTES fileAttributes = { 0 };
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
        while (true) {
            if ([date timeIntervalSinceNow] < 0) {
                libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
                break;
            }
            rc = libssh2_sftp_readdir(handle, buffer, sizeof(buffer), &fileAttributes);
            if (rc >= 0) { break; } // read success
            if (rc == LIBSSH2_ERROR_EAGAIN) { continue; } // go around
            break;
        }
        if (rc > 0) {
            NSString *fileName = [[NSString alloc] initWithBytes:buffer length:rc encoding:NSUTF8StringEncoding];
            if (![ignoredFiles containsObject:fileName]) {
                // Append a "/" at the end of all directories
                NSRemoteFile *file = [[NSRemoteFile alloc] initWithFilename:fileName];
                [file populateAttributes:fileAttributes];
                [contents addObject:file];
            }
        }
    } while (rc > 0);

    if (rc < 0) {
        NSLog(@"SFTP failed to open handler for dir: %@", withDirPath);
        return NULL;
    }
    while (libssh2_sftp_closedir(handle) == LIBSSH2_ERROR_EAGAIN) {};
    [contents sortUsingDescriptors: @[
        [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]
    ]];
    return contents;
}

- (nullable NSRemoteFile*)unsafeGetFileInfo:(NSString*)atPath
{
    if (![self unsafeValidateSessionSFTP]) { return NULL; }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedSFTP;
    LIBSSH2_SFTP_HANDLE *handle = [self unsafeSFTPOpenFileHandlerWithSession:session
                                                                    withSFTP:sftp
                                                                    withPath:atPath
                                                                    withFlag:LIBSSH2_FXF_READ
                                                                    withMode:0];
    if (!handle) {
        NSLog(@"SFTP failed to open handler for file: %@", atPath);
        return NULL;
    }

    LIBSSH2_SFTP_ATTRIBUTES fileAttributes;
    BOOL statSuccess = NO;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        ssize_t rc = libssh2_sftp_fstat(handle, &fileAttributes);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        if (rc == 0) {
            statSuccess = YES;
            break;
        }
        break;
    }
    if (!statSuccess) {
        NSLog(@"SFTP failed to call fstat for file: %@", atPath);
        return NULL;
    }
    
    NSRemoteFile *file = [[NSRemoteFile alloc] initWithFilename:atPath.lastPathComponent];
    [file populateAttributes:fileAttributes];
    
    while (libssh2_sftp_closedir(handle) == LIBSSH2_ERROR_EAGAIN) {};
    
    return file;
}

@end
