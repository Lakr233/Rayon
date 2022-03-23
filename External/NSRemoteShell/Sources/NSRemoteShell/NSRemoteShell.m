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
@property (nonatomic, readwrite, nullable, strong) NSString *lastFileTransferError;

@property (nonatomic, readwrite, getter=isConnected) BOOL connected;
@property (nonatomic, readwrite, getter=isConnectedFileTransfer) BOOL connectedFileTransfer;
@property (nonatomic, readwrite, getter=isAuthenticated) BOOL authenticated;

@property (nonatomic, readwrite, assign) int associatedSocket;
@property (nonatomic, readwrite, nullable, assign) LIBSSH2_SESSION *associatedSession;
@property (nonatomic, readwrite, nullable, assign) LIBSSH2_SFTP *associatedFileTransfer;
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
        _associatedSocket = 0;
        _associatedSession = NULL;
        _associatedFileTransfer = NULL;
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

- (instancetype)setupConnectionHost:(NSString*)targetHost {
    @synchronized(self) {
        [self setRemoteHost:targetHost];
    }
    return self;
}

- (instancetype)setupConnectionPort:(NSNumber*)targetPort {
    @synchronized(self) {
        [self setRemotePort:targetPort];
    }
    return self;
}

- (instancetype)setupConnectionTimeout:(NSNumber*)timeout {
    if (timeout.doubleValue < 1) {
        NSLog(@"setting timeout value %@ below 1 is not supported", [timeout stringValue]);
#if DEBUG
        NSLog(@"for debug purpose, call ivar setter on operationTimeout with a NSNumber");
#endif
        return self;
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

#pragma control

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
    MakeDispatchSemaphoreWaitWithTimeout(sem)
}

- (void)requestDisconnectAndWait {
    if (self.destroyed) return;
    
    /*
     kill these values so we will clean the things up if in fly
     especially for file transfer
     the loop for read and loop for write will check the connectedFileTransfer
     each time before execution io rw
     so we won't wait too much time before f**k up
     */
    self.connected = NO;
    self.connectedFileTransfer = NO;
    self.authenticated = NO;
    
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

- (void)authenticateWith:(NSString*)username andPassword:(NSString*)password {
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
    MakeDispatchSemaphoreWaitWithTimeout(sem)
}

- (void)authenticateWith:(NSString*)username andPublicKey:(NSString*)publicKey andPrivateKey:(NSString*)privateKey andPassword:(NSString*)password {
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
    MakeDispatchSemaphoreWaitWithTimeout(sem)
}

#pragma exec

- (int)beginExecuteWithCommand:(NSString*)withCommand
                   withTimeout:(NSNumber*)withTimeoutSecond
                  withOnCreate:(dispatch_block_t)withOnCreate
                    withOutput:(nullable void (^)(NSString*))withOutput
       withContinuationHandler:(nullable BOOL (^)(void))withContinuationBlock {
    if (self.destroyed) return 0;
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

#pragma port

- (void)createPortForwardWithLocalPort:(NSNumber*)localPort
                 withForwardTargetHost:(NSString*)targetHost
                 withForwardTargetPort:(NSNumber*)targetPort
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

- (void)createPortForwardWithRemotePort:(NSNumber*)remotePort
                  withForwardTargetHost:(NSString*)targetHost
                  withForwardTargetPort:(NSNumber*)targetPort
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

#pragma sftp

- (void)requestConnectFileTransferAndWait {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    @synchronized (self.requestInvokations) {
        id block = [^{
            [magic unsafeConnectFileTransferWithCompleteBlock:^{
                DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
            }];
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWaitWithTimeout(sem);
}
- (void)requestDisconnectFileTransferAndWait {
    if (self.destroyed) return;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    @synchronized (self.requestInvokations) {
        id block = [^{
            [self unsafeFileTransferCloseFor:self.associatedFileTransfer];
            self.associatedFileTransfer = NULL;
            self.connectedFileTransfer = NO;
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWaitWithTimeout(sem);
}

- (nullable NSArray<NSRemoteFile *>*)requestFileListAt:(NSString*)atDirPath {
    if (self.destroyed) return NULL;
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
    MakeDispatchSemaphoreWaitWithTimeout(sem);
    return result;
}
- (nullable NSRemoteFile*)requestFileInfoAt:(NSString*)atPath {
    if (self.destroyed) return NULL;
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
    MakeDispatchSemaphoreWaitWithTimeout(sem);
    return result;
}

- (BOOL) requestRenameFileAndWait:(NSString *)atPath
                      withNewPath:(NSString *)newPath
{
    if (self.destroyed) return NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block BOOL success = NO;
    @synchronized (self.requestInvokations) {
        id block = [^{
            success = [magic unsafeRenameFileAndWait:atPath
                                         withNewPath:newPath];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWaitWithTimeout(sem);
    return success;
}

- (BOOL)requestUploadForFileAndWait:(NSString*)atPath
                        toDirectory:(NSString*)toDirectory
                         onProgress:(NSRemoteFileTransferProgressBlock _Nonnull)onProgress
            withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (self.destroyed) return NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block BOOL success = NO;
    @synchronized (self.requestInvokations) {
        id block = [^{
            success = [magic unsafeUploadRecursiveForFile:atPath
                                              toDirectory:toDirectory
                                               onProgress:onProgress
                                  withContinuationHandler:continuationBlock
                                                    depth:0];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return success;
}

- (BOOL)requestDeleteForFileAndWait:(NSString*)atPath
                  withProgressBlock:(NSRemoteFileDeleteProgressBlock _Nonnull)onProgress
            withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (self.destroyed) return NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block BOOL success = NO;
    @synchronized (self.requestInvokations) {
        id block = [^{
            success = [magic unsafeDeleteForFile:atPath
                               withProgressBlock:onProgress
                         withContinuationHandler:continuationBlock];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return success;
}

- (BOOL)requestCreateDirAndWait:(NSString*)atPath
{
    if (self.destroyed) return NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block BOOL success = NO;
    @synchronized (self.requestInvokations) {
        id block = [^{
            success = [magic unsafeCreateDirAndWait:atPath];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    MakeDispatchSemaphoreWaitWithTimeout(sem);
    return success;
}

- (BOOL)requestDownloadFromFileAndWait:(NSString*)atPath
                           toLocalPath:(NSString*)toPath
                            onProgress:(NSRemoteFileTransferProgressBlock)onProgress
               withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (self.destroyed) return NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __weak typeof(self) magic = self;
    __block BOOL success = NO;
    @synchronized (self.requestInvokations) {
        id block = [^{
            success = [magic unsafeDownloadRecursiveAtPath:atPath
                                               toLocalPath:toPath
                                                onProgress:onProgress
                                   withContinuationHandler:continuationBlock
                                                     depth:0];
            DISPATCH_SEMAPHORE_CHECK_SIGNLE(sem);
        } copy];
        [self.requestInvokations addObject:block];
    }
    [self.associatedLoop explicitRequestHandle];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return success;
}

// MARK: - HELPER

- (nullable NSString*)getLastError {
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

- (nullable NSString*)getLastFileTransferError {
    NSString *result;
    @synchronized (self.lastFileTransferError) {
        result = self.lastFileTransferError;
        self.lastFileTransferError = NULL;
    }
    if ([result isEqualToString:@""]) {
        return NULL;
    }
    return result;
}

// MARK: - UNCHECKED CONCURRENCY

#pragma control

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
    
    LIBSSH2_SESSION *constructorSession = libssh2_session_init_ex(0, 0, 0, (__bridge void*)(self));
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
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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
    
    [self unsafeFileTransferCloseFor:self.associatedFileTransfer];
    self.associatedFileTransfer = NULL;
    self.connectedFileTransfer = NO;
    
    [self unsafeSessionCloseFor:self.associatedSession];
    self.associatedSession = NULL;
    self.connected = NO;
    self.authenticated = NO;
    
    if (self.associatedSocket) {
        [GenericNetworking destroyNativeSocket:self.associatedSocket];
    }
    self.associatedSocket = 0;
    
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
                                                                        0,
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
    if (!(self.isConnected && self.isAuthenticated)) {
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
    long long rv = libssh2_session_last_errno(self.associatedSession);
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

- (void)unsafeFileTransferCloseFor:(LIBSSH2_SFTP*)sftp {
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
        if (!self.isAuthenticated) { break; }
        if (!self.associatedFileTransfer) { break; }
        return YES;
    } while (0);
    [self unsafeDisconnect];
    return NO;
}

#pragma auth

- (void)unsafeAuthenticateWith:(NSString*)username
                   andPassword:(NSString*)password {
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
        long long rc = libssh2_userauth_password(session, [username UTF8String], [password UTF8String]);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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

- (void)unsafeAuthenticateWith:(NSString*)username
                  andPublicKey:(NSString*)publicKey
                 andPrivateKey:(NSString*)privateKey
                   andPassword:(NSString*)password {
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
        const char *name = username ? [username UTF8String] : NULL;
        unsigned int nl = username ? (unsigned int)strlen(name) : 0;
        const char *pub = publicKey ? [publicKey UTF8String] : NULL;
        unsigned int pul = publicKey ? (unsigned int)strlen(pub): 0;
        const char *pri = privateKey ? [privateKey UTF8String] : NULL;
        unsigned int prl = privateKey ? (unsigned int)strlen(pri) : 0;
        const char *pwd = password ? [password UTF8String] : NULL;
        long long rc = libssh2_userauth_publickey_frommemory(session,
                                                             name, (unsigned int)nl,
                                                             pub, (unsigned int)pul,
                                                             pri, (unsigned int)prl,
                                                             pwd);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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

#pragma exec

- (void)unsafeExecuteRemote:(NSString*)command
            withExecTimeout:(NSNumber*)timeoutSecond
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
            libssh2_session_set_last_error(session, 0, NULL);
            channel = channelBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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
        if (rc == LIBSSH2_ERROR_EAGAIN) { usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT); continue; }
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
            libssh2_session_set_last_error(session, 0, NULL);
            channel = channelBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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
                usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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
            if (rc == LIBSSH2_ERROR_EAGAIN) { usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT); continue; }
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

#pragma forward

- (void)unsafeCreatePortForwardWithLocalPort:(NSNumber*)localPort
                       withForwardTargetHost:(NSString*)targetHost
                       withForwardTargetPort:(NSNumber*)targetPort
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

- (void)unsafeCreatePortForwardWithRemotePort:(NSNumber*)remotePort
                        withForwardTargetHost:(NSString*)targetHost
                        withForwardTargetPort:(NSNumber*)targetPort
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
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
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

#pragma sftp

- (void)unsafeConnectFileTransferWithCompleteBlock:(dispatch_block_t)withComplete {
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
            libssh2_session_set_last_error(session, 0, NULL);
            sftp = sftpBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!sftp) {
        if (withComplete) withComplete();
        [self unsafeFileTransferSetErrorForFile:@"null" pathIsRemote:YES failureReason:@"libssh2_sftp_init was not able to receive session"];
        return;
    }
    
    self.associatedFileTransfer = sftp;
    self.connectedFileTransfer = YES;
    NSLog(@"libssh2_sftp_init success");
    if (withComplete) withComplete();
}

- (nullable LIBSSH2_SFTP_HANDLE*)unsafeFileTransferOpenDirHandlerWithSession:(LIBSSH2_SESSION*)session
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
        const char *cpath = [path UTF8String];
        LIBSSH2_SFTP_HANDLE *handlerBuilder = libssh2_sftp_open_ex(sftp,
                                                                   cpath,
                                                                   (unsigned int)strlen(cpath),
                                                                   0,
                                                                   0,
                                                                   LIBSSH2_SFTP_OPENDIR);
        if (handlerBuilder) {
            libssh2_session_set_last_error(session, 0, NULL);
            handler = handlerBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!handler) {
        [self unsafeFileTransferSetErrorForFile:path pathIsRemote:YES failureReason:@"remote permission denied"];
    }
    return handler;
}

- (nullable LIBSSH2_SFTP_HANDLE*)unsafeFileTransferOpenFileHandlerWithSession:(LIBSSH2_SESSION*)session
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
        const char *cpath = [path UTF8String];
        /*
         by using c path and strlen, utf8 char set with multi length will have the right space
         
         (lldb) po [path length];
         25

         (lldb) po strlen(cpath)
         29
         */
        LIBSSH2_SFTP_HANDLE *handlerBuilder = libssh2_sftp_open_ex(sftp,
                                                                   cpath,
                                                                   (unsigned int)strlen(cpath),
                                                                   flags,
                                                                   mode,
                                                                   LIBSSH2_SFTP_OPENFILE);
        if (handlerBuilder) {
            libssh2_session_set_last_error(session, 0, NULL);
            handler = handlerBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!handler) {
        [self unsafeFileTransferSetErrorForFile:path pathIsRemote:YES failureReason:@"remote permission denied"];
    }
    return handler;
}

- (nullable NSArray<NSRemoteFile*>*)unsafeGetDirFileListAt:(NSString*)withDirPath {
    if (![self unsafeValidateSessionSFTP]) {
        [self unsafeFileTransferSetErrorForFile:withDirPath pathIsRemote:YES failureReason:@"connection broken"];
        return NULL;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedFileTransfer;
    LIBSSH2_SFTP_HANDLE *handle = [self unsafeFileTransferOpenDirHandlerWithSession:session
                                                                           withSFTP:sftp
                                                                           withPath:withDirPath];
    if (!handle) {
        [self unsafeFileTransferSetErrorForFile:withDirPath pathIsRemote:YES failureReason:@"remote permission denied"];
        return NULL;
    }
    
    NSArray *ignoredFiles = @[@".", @".."];
    NSMutableArray *contents = [NSMutableArray array];
    
    long long rc = 0;
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
            if (rc == LIBSSH2_ERROR_EAGAIN) { usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT); continue; } // go around
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
    
    while (libssh2_sftp_closedir(handle) == LIBSSH2_ERROR_EAGAIN) {};
    if (rc < 0) {
        [self unsafeFileTransferSetErrorForFile:withDirPath pathIsRemote:YES failureReason:@"remote permission denied"];
        return NULL;
    }
    [contents sortUsingDescriptors: @[
        [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]
    ]];
    return contents;
}

- (nullable NSRemoteFile*)unsafeGetFileInfo:(NSString*)atPath
{
    if (![self unsafeValidateSessionSFTP]) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"connection broken"];
        return NULL;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedFileTransfer;
    LIBSSH2_SFTP_HANDLE *handle = [self unsafeFileTransferOpenFileHandlerWithSession:session
                                                                            withSFTP:sftp
                                                                            withPath:atPath
                                                                            withFlag:LIBSSH2_FXF_READ
                                                                            withMode:0];
    if (!handle) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"remote permission denied"];
        return NULL;
    }
    
    LIBSSH2_SFTP_ATTRIBUTES fileAttributes = { 0 };
    BOOL statSuccess = NO;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        ssize_t rc = libssh2_sftp_fstat(handle, &fileAttributes);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        if (rc == 0) {
            statSuccess = YES;
            break;
        }
        break;
    }
    
    while (libssh2_sftp_closedir(handle) == LIBSSH2_ERROR_EAGAIN) {};
    
    if (!statSuccess) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"remote permission denied"];
        return NULL;
    }
    NSRemoteFile *file = [[NSRemoteFile alloc] initWithFilename:atPath.lastPathComponent];
    [file populateAttributes:fileAttributes];
    
    return file;
}

- (BOOL)unsafeUploadForFile:(NSString*)atPath
                toDirectory:(NSString*)toDirectory
                 onProgress:(NSRemoteFileTransferProgressBlock _Nonnull)onProgress
    withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    NSString *localPath = [atPath stringByExpandingTildeInPath];
    NSURL *localFile = [[NSURL alloc] initFileURLWithPath:localPath];
    NSURL *remoteFile = [[NSURL alloc] initFileURLWithPath:toDirectory];
    remoteFile = [remoteFile URLByAppendingPathComponent:localFile.lastPathComponent];
    
//    NSLog(@"uploading %@ to %@", localFile.path, remoteFile.path);
    
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:localFile.path isDirectory:&isDir];
    if (!exists) {
        [self unsafeFileTransferSetErrorForFile:localFile.path pathIsRemote:NO failureReason:@"file not found"];
        return NO;
    }
    
    if (![self unsafeValidateSession]) { return NO; }
    LIBSSH2_SESSION *session = self.associatedSession;
    
    if (isDir) {
        [self unsafeFileTransferSetErrorForFile:localFile.path
                                   pathIsRemote:NO
                                  failureReason:@"this function does not support upload directory"];
        return NO;
    }
//    NSLog(@"requesting upload file at %@ to %@", localFile.path, remoteFile.path);
    FILE *f = fopen([localFile.path UTF8String], "rb");
    if (!f) {
        [self unsafeFileTransferSetErrorForFile:localFile.path pathIsRemote:NO failureReason:@"failed to read"];
        return NO;
    }
    struct stat fi;
    memset(&fi, 0, sizeof(fi));
    stat([localFile.path UTF8String], &fi);
    LIBSSH2_CHANNEL *channel = NULL;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_CHANNEL *channelBuilder = libssh2_scp_send64(session,
                                                             [remoteFile.path UTF8String],
                                                             fi.st_mode & 0644,
                                                             (unsigned long)fi.st_size,
                                                             0,
                                                             0);
        if (channelBuilder) {
            libssh2_session_set_last_error(session, 0, NULL);
            channel = channelBuilder;
            break;
        }
        long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!channel) {
        [self unsafeFileTransferSetErrorForFile:localFile.path pathIsRemote:NO failureReason:@"remote permission denied"];
        return NO;
    }
    
    NSDate *begin = [[NSDate alloc] init];
    NSDate *previousProgressSent = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    
//    char *buff = (char*)malloc(SFTP_BUFFER_SIZE);
    char buff[SFTP_BUFFER_SIZE];
    size_t read_size;
    char *ptr;
    NSUInteger sent_size = 0;
    NSUInteger total_size = fi.st_size;
    while (sent_size < total_size) {
        if (continuationBlock && !continuationBlock()) { break; }
        if (!self.isConnectedFileTransfer) { break; }
//        memset(buff, 0, SFTP_BUFFER_SIZE);
        memset(buff, 0, sizeof(buff));
        read_size = fread(buff, 1, sizeof(buff), f);
        if (read_size <= 0) {
            break; // done or error
        }
        ptr = buff;
        long long rc = LIBSSH2_ERROR_EAGAIN;
        // we are not really count the timeout here tho
        while (rc == LIBSSH2_ERROR_EAGAIN || read_size) {
            rc = libssh2_channel_write(channel, ptr, read_size);
            if (rc == LIBSSH2_ERROR_EAGAIN) {
                continue;
            } else if (rc > 0) {
                // rc indicates how many bytes were written this time
                sent_size += rc;
                ptr += rc;
                read_size -= rc;
            } else {
                // has error
                break;
            }
        };
        if (rc < 0 && rc != LIBSSH2_ERROR_EAGAIN) {
            break;
        }
        if (onProgress && [previousProgressSent timeIntervalSinceNow] < -0.2) {
            previousProgressSent = [[NSDate alloc] init];
            NSTimeInterval interval = [[[NSDate alloc] init] timeIntervalSinceDate:begin];
            double speed = 0;
            if (interval != 0) {
                speed = sent_size / interval;
            }
            NSProgress *progress = [[NSProgress alloc] init];
            [progress setTotalUnitCount:total_size];
            [progress setCompletedUnitCount:sent_size];
            dispatch_async(dispatch_get_main_queue(), ^{
                onProgress(atPath, progress, speed);
            });
        }
    };
//    free(buff);
    [self unsafeReadLastError];
    
    if (sent_size < total_size) {
        [self unsafeFileTransferSetErrorForFile:localFile.path
                                   pathIsRemote:NO
                                  failureReason:@"transport sent did not write enough data"];
    }
    
    fclose(f);
    LIBSSH2_CHANNEL_SHUTDOWN(channel);
//    NSLog(@"upload %@ to %@ done", localFile.path, remoteFile.path);
    if (onProgress) {
        NSProgress *progress = [[NSProgress alloc] init];
        [progress setTotalUnitCount:total_size];
        [progress setCompletedUnitCount:total_size];
        NSTimeInterval interval = [[[NSDate alloc] init] timeIntervalSinceDate:begin];
        double speed = 0;
        if (interval != 0) {
            speed = sent_size / interval;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            onProgress(atPath, progress, speed);
        });
    }
    return sent_size == total_size;
}

- (BOOL)unsafeUploadRecursiveForFile:(NSString*)atPath
                         toDirectory:(NSString*)toDirectory
                          onProgress:(NSRemoteFileTransferProgressBlock _Nonnull)onProgress
             withContinuationHandler:(BOOL (^)(void))continuationBlock
                               depth:(int)depth
{
    @autoreleasepool {
        if (depth > SFTP_RECURSIVE_DEPTH) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:NO failureReason:@"too many items inside dir"];
            return NO;
        }
        if (continuationBlock && !continuationBlock()) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:NO failureReason:@"user cancel"];
            return NO;
        }
        BOOL isDir = NO;
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:atPath isDirectory:&isDir];
        if (!exists) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:NO failureReason:@"file not found"];
            return NO;
        }
        
        if (isDir) {
            NSError *error = NULL;
            NSArray *content = [NSFileManager.defaultManager contentsOfDirectoryAtPath:atPath
                                                                                 error:&error];
            if (error) {
                [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:NO failureReason:@"permission denied"];
                return NO;
            }
            NSURL *localBase = [[NSURL alloc] initFileURLWithPath:atPath];
            NSURL *remoteBase = [[[NSURL alloc] initFileURLWithPath:toDirectory]
                                 URLByAppendingPathComponent:localBase.lastPathComponent];
            // now create dir on remote
            if (![self unsafeCreateDirAndWait:remoteBase.path]) {
                [self unsafeFileTransferSetErrorForFile:remoteBase.path pathIsRemote:YES failureReason:@"remote permission denied"];
                return NO;
            }
            for (NSString *file in content) {
                NSURL *atPath = [localBase URLByAppendingPathComponent:file];
                NSURL *toDir = remoteBase;
                BOOL ret = [self unsafeUploadRecursiveForFile:atPath.path
                                                  toDirectory:toDir.path
                                                   onProgress:onProgress
                                      withContinuationHandler:continuationBlock
                                                        depth:depth + 1];
                if (!ret) { return NO; }
            }
            return YES;
        } else {
            return [self unsafeUploadForFile:atPath
                                 toDirectory:toDirectory
                                  onProgress:onProgress
                     withContinuationHandler:continuationBlock];
        }
    }
}

- (BOOL)unsafeDeleteForFile:(NSString*)atPath
          withProgressBlock:(NSRemoteFileDeleteProgressBlock _Nonnull)onProgress
    withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (![atPath hasPrefix:@"/"] || atPath.length < 1) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"invalid parameters"];
        return NO;
    }
    
#if DEBUG
    assert(atPath.length > 1);
#endif
    
    if (![self unsafeValidateSessionSFTP]) { return NO; }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedFileTransfer;
//    NSLog(@"removing file %@", atPath);
    
    return [self unsafeDeleteRecursivelyForPathAndReturnContinue:atPath
                                                     withSession:session
                                         withFileTransferHandler:sftp
                                                           depth:0
                                               withProgressBlock:onProgress
                                         withContinuationHandler:continuationBlock];
}

- (BOOL)unsafeCreateDirAndWait:(NSString*)atPath
{
    if (![atPath hasPrefix:@"/"] || atPath.length < 1) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"invalid parameter"];
        return NO;
    }
    
#if DEBUG
    assert(atPath.length > 1);
#endif
    
    if (![self unsafeValidateSessionSFTP]) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"connection broken"];
        return NO;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedFileTransfer;
//    NSLog(@"creating dir %@", atPath);
    
    // before we create, ask to check if already exists
    NSRemoteFile *file = [self unsafeGetFileInfo:atPath];
    if (file) {
        if (file.isDirectory) { return YES; } // already exists
        // otherwise error later on
    }
    
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    long long rc = 0;
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        int mode = 0
        | LIBSSH2_SFTP_S_IRWXU
        | LIBSSH2_SFTP_S_IRGRP
        | LIBSSH2_SFTP_S_IXGRP
        | LIBSSH2_SFTP_S_IROTH
        | LIBSSH2_SFTP_S_IXOTH;
        const char *cpath = [atPath UTF8String];
        rc = libssh2_sftp_mkdir_ex(sftp, cpath, (unsigned int)strlen(cpath), mode);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (rc != 0) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"remote permission denied"];
        return NO;
    }
    return YES;
}

- (BOOL)unsafeDeleteRecursivelyForPathAndReturnContinue:(NSString*)atPath
                                            withSession:(LIBSSH2_SESSION*)session
                                withFileTransferHandler:(LIBSSH2_SFTP*)sftp
                                                  depth:(int)depth
                                      withProgressBlock:(NSRemoteFileDeleteProgressBlock _Nonnull)onProgress
                                withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    if (depth > SFTP_RECURSIVE_DEPTH) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"too many items inside dir"];
        return NO;
    }
    if (continuationBlock && !continuationBlock()) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"user cancel"];
        return NO;
    }
    
    // get file info at path
    NSRemoteFile *file = [self unsafeGetFileInfo:atPath];
    // note that we are unable to get handler for fstat with a dead link
    // call unlink is still possible, but we are unable to check for isDir
    if (file && file.isDirectory) {
        NSURL *curr = [[NSURL alloc] initFileURLWithPath:atPath];
        NSArray<NSRemoteFile*> *array = [self unsafeGetDirFileListAt:curr.path];
        for (NSRemoteFile *file in array) {
            NSURL *res = [curr URLByAppendingPathComponent:file.name];
            BOOL ret = [self unsafeDeleteRecursivelyForPathAndReturnContinue:res.path
                                                                 withSession:session
                                                     withFileTransferHandler:sftp
                                                                       depth:depth + 1
                                                           withProgressBlock:onProgress
                                                     withContinuationHandler:continuationBlock];
            if (!ret) { return NO; }
        }
//        NSLog(@"calling rmdir at %@", atPath);
        if (onProgress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onProgress(atPath);
            });
        }
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
        long long rc = 0;
        while (true) {
            if ([date timeIntervalSinceNow] < 0) {
                libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
                break;
            }
            const char *cpath = [atPath UTF8String];
            rc = libssh2_sftp_rmdir_ex(sftp, cpath, (unsigned int)strlen(cpath));
            if (rc == LIBSSH2_ERROR_EAGAIN) {
                usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
                continue;
            }
            break;
        }
        [self unsafeReadLastError];
        if (rc != 0) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"remote permission denied"];
            return NO;
        }
        return YES;
    } else {
//        NSLog(@"calling unlink at %@", atPath);
        if (onProgress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onProgress(atPath);
            });
        }
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
        long long rc = 0;
        while (true) {
            if ([date timeIntervalSinceNow] < 0) {
                libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
                break;
            }
            const char *cpath = [atPath UTF8String];
            rc = libssh2_sftp_unlink_ex(sftp, cpath, (unsigned int)strlen(cpath));
            if (rc == LIBSSH2_ERROR_EAGAIN) {
                usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
                continue;
            }
            break;
        }
        [self unsafeReadLastError];
        if (rc != 0) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"remote permission denied"];
            return NO;
        }
        return YES;
    }
}

- (BOOL)unsafeDownloadFromFileAndWait:(NSString*)atFullPath // full path
                          toLocalPath:(NSString*)toFullPath // full path
                           onProgress:(NSRemoteFileTransferProgressBlock)onProgress
              withContinuationHandler:(BOOL (^)(void))continuationBlock
{
    // we are not in charge to fix any stuff related to path
    // we are called from ourselves
    NSString *atPath = atFullPath;
    NSURL *localFile = [[NSURL alloc] initFileURLWithPath:toFullPath];
//    NSString *toPath = toFullPath;
    NSURL *remoteFile = [[NSURL alloc] initFileURLWithPath:atFullPath];
    
    //    NSLog(@"%@ to %@", remoteFile.path, localFile.path);
    
    if (![self unsafeValidateSessionSFTP]) {
        [self unsafeFileTransferSetErrorForFile:atFullPath pathIsRemote:YES failureReason:@"broken connection"];
        return NO;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedFileTransfer;
    LIBSSH2_SFTP_HANDLE *handle = [self unsafeFileTransferOpenFileHandlerWithSession:session
                                                                            withSFTP:sftp
                                                                            withPath:atPath
                                                                            withFlag:LIBSSH2_FXF_READ
                                                                            withMode:0];
    if (!handle) {
        [self unsafeFileTransferSetErrorForFile:atFullPath pathIsRemote:YES failureReason:@"broken connection"];
        return NO;
    }
//    NSLog(@"downloading file %@ to %@", atPath, toPath);
    
    struct stat fi;
    memset(&fi, 0, sizeof(fi));
    LIBSSH2_CHANNEL *channel = NULL;
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        LIBSSH2_CHANNEL *channelBuilder = libssh2_scp_recv(session, [atPath UTF8String], &fi);
        if (channelBuilder) {
            libssh2_session_set_last_error(session, 0, NULL);
            channel = channelBuilder;
            break;
        }
        long long rc = libssh2_session_last_errno(session);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (!channel) {
        libssh2_sftp_close_handle(handle);
        [self unsafeFileTransferSetErrorForFile:atFullPath pathIsRemote:YES failureReason:@"broken connection"];
        return NO;
    }
    
    int f = open([localFile.path UTF8String], O_WRONLY | O_CREAT, 0644);
    if (!f) {
        LIBSSH2_CHANNEL_SHUTDOWN(channel);
        libssh2_sftp_close_handle(handle);
        [self unsafeFileTransferSetErrorForFile:atFullPath pathIsRemote:YES failureReason:@"broken connection"];
        return NO;
    }
    
    NSDate *begin = [[NSDate alloc] init];
    NSDate *lastProgress = [[NSDate alloc] initWithTimeIntervalSince1970:0];
    
    // do note that the file could be empty
    // fi.st_size may be zero, the entire loop is going to be skipped
    long long recv_size = 0;
//    char *buff = (char*)malloc(SFTP_BUFFER_SIZE);
    char buff[SFTP_BUFFER_SIZE];
    while (recv_size < fi.st_size) {
        if (continuationBlock && !continuationBlock()) { break; }
        if (!self.isConnectedFileTransfer) { break; }
        long long recv_decision = sizeof(buff);
//        memset(buff, 0, SFTP_BUFFER_SIZE);
        memset(buff, 0, sizeof(buff));
        if ((fi.st_size - recv_size) < recv_decision) {
            // do not write over!
            // libssh2_channel_read may have dirty data
            recv_decision = (size_t)(fi.st_size - recv_size);
        }
        long long recv_write_size = libssh2_channel_read(channel, buff, recv_decision);
        if (recv_write_size < 0) {
            if (recv_write_size == LIBSSH2_ERROR_EAGAIN) {
                // do not change anything
                continue;
            }
            // error occurred
            break;
        }
        if (recv_write_size > 0) {
            long long f_write_size = write(f, buff, recv_write_size);
            if (f_write_size < 0) {
                NSLog(@"failed to write returns %lld", f_write_size);
                break;
            }
            if (f_write_size < recv_write_size) {
                NSLog(@"write call failed to write all buffer, required %lld returns %lld",
                      f_write_size,
                      recv_write_size);
                break;
            }
            recv_size += f_write_size;
        }
        if (onProgress) {
            NSDate *now = [[NSDate alloc] init];
            if ([now timeIntervalSinceDate:lastProgress] > 0.1) {
                lastProgress = now;
                NSTimeInterval interval = [now timeIntervalSinceDate:begin];
                long long speed = 0;
                if (interval) {
                    speed = recv_size / interval;
                }
                NSProgress *progress = [[NSProgress alloc] init];
                [progress setTotalUnitCount:fi.st_size];
                [progress setCompletedUnitCount:recv_size];
                dispatch_async(dispatch_get_main_queue(), ^{
                    onProgress(remoteFile.path, progress, speed);
                });
            }
        }
    }
//    free(buff);
    [self unsafeReadLastError];
    if (onProgress) {
        NSProgress *progress = [[NSProgress alloc] init];
        [progress setTotalUnitCount:fi.st_size];
        [progress setCompletedUnitCount:recv_size];
        NSTimeInterval interval = [[[NSDate alloc] init] timeIntervalSinceDate:begin];
        long long speed = 0;
        if (interval) {
            speed = recv_size / interval;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            onProgress(remoteFile.path, progress, speed);
        });
    }
    if (recv_size != fi.st_size) {
        [self unsafeFileTransferSetErrorForFile:atFullPath
                                   pathIsRemote:YES
                                  failureReason:@"transport receive did not write full data"];
    }
    [self unsafeReadLastError];
    
    close(f);
    LIBSSH2_CHANNEL_SHUTDOWN(channel);
    libssh2_sftp_close_handle(handle);
    return recv_size == fi.st_size;
}

- (BOOL)unsafeDownloadRecursiveAtPath:(NSString*)atPath
                          toLocalPath:(NSString*)toPath // target path, full path or inherit name from target
                           onProgress:(NSRemoteFileTransferProgressBlock)onProgress
              withContinuationHandler:(BOOL (^)(void))continuationBlock
                                depth:(int)depth
{
    @autoreleasepool {
        if (depth > SFTP_RECURSIVE_DEPTH) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"too many items inside dir"];
            return NO;
        }
        if (continuationBlock && !continuationBlock()) {
            [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"user canceled"];
            return NO;
        }
        
        atPath = [atPath stringByExpandingTildeInPath];
        
        NSURL *remoteFile = [[NSURL alloc] initFileURLWithPath:atPath];
        NSURL *localFile = [[NSURL alloc] initFileURLWithPath:toPath];
        
        // inherit filename from remote file path
        if ([toPath hasSuffix:@"/"]) {
            localFile = [localFile URLByAppendingPathComponent:atPath.lastPathComponent];
        }
        
        // now make sure the dir exists
        do {
            NSURL *dir = [localFile URLByDeletingLastPathComponent];
            [NSFileManager.defaultManager createDirectoryAtURL:dir
                                   withIntermediateDirectories:YES
                                                    attributes:NULL
                                                         error:NULL];
            BOOL isDir;
            BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:dir.path
                                                             isDirectory:&isDir];
            if (!exists || !isDir) {
                [self unsafeFileTransferSetErrorForFile:dir.path pathIsRemote:NO failureReason:@"permission denied"];
                return NO;
            }
        } while (false);
        
        // get list from remote
        NSRemoteFile *file = [self unsafeGetFileInfo:atPath];
        if (file && file.isDirectory) {
            NSArray<NSRemoteFile*> *array = [self unsafeGetDirFileListAt:atPath];
            if (!array) {
                [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"failed to retrieve information"];
                return NO;
            }
            // now because it is a directory, we create one on our local path
            NSURL *localBase = localFile; // don't remove this, it will make code cleaner
            // TODO: Copy All File Attribute
//            NSLog(@"creating dir %@ to %@", remoteFile.path, localBase.path);
            [NSFileManager.defaultManager createDirectoryAtURL:localBase
                                   withIntermediateDirectories:YES
                                                    attributes:NULL
                                                         error:NULL];
            BOOL isDir = NO;
            BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:localBase.path isDirectory:&isDir];
            if (!exists || !isDir) {
                [self unsafeFileTransferSetErrorForFile:localBase.path pathIsRemote:NO failureReason:@"permission denied"];
                return NO;
            }
            NSURL *base = [[NSURL alloc] initFileURLWithPath:atPath];
            for (NSRemoteFile *file in array) {
                NSURL *targetPath = [base URLByAppendingPathComponent:file.name];
                NSURL *localTargetPath = [localBase URLByAppendingPathComponent:file.name];
                int ret = [self unsafeDownloadRecursiveAtPath:targetPath.path
                                                  toLocalPath:localTargetPath.path
                                                   onProgress:onProgress
                                      withContinuationHandler:continuationBlock
                                                        depth:depth + 1];
                if (!ret) { return NO; }
            }
            return YES;
        } else {
            // treat anything else as regular file or we will handle error later on
            // now because it is a "regular" file, overwrite requires to remove it
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:localFile.path];
            if (exists) {
                NSError *error = NULL;
                [NSFileManager.defaultManager removeItemAtURL:localFile error:&error];
                if (error) {
                    [self unsafeFileTransferSetErrorForFile:localFile.path pathIsRemote:NO failureReason:@"permission denied"];
                    return NO;
                }
            }
            return [self unsafeDownloadFromFileAndWait:remoteFile.path
                                           toLocalPath:localFile.path
                                            onProgress:onProgress
                               withContinuationHandler:continuationBlock];
        }
    }
}

- (BOOL)unsafeRenameFileAndWait:(NSString *)atPath
                    withNewPath:(NSString *)newPath
{
    if (![atPath hasPrefix:@"/"] || atPath.length < 1 || ![newPath hasPrefix:@"/"] || newPath.length < 1) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"invalid parameter"];
        return NO;
    }
    
#if DEBUG
    assert(atPath.length > 1);
    assert(newPath.length > 1);
#endif
    
    if (![self unsafeValidateSessionSFTP]) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"connection broken"];
        return NO;
    }
    LIBSSH2_SESSION *session = self.associatedSession;
    LIBSSH2_SFTP *sftp = self.associatedFileTransfer;
//    NSLog(@"rename %@ to %@", atPath, newPath);
    
    NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:[self.operationTimeout intValue]];
    long long rc = 0;
    while (true) {
        if ([date timeIntervalSinceNow] < 0) {
            libssh2_session_set_last_error(session, LIBSSH2_ERROR_TIMEOUT, NULL);
            break;
        }
        int mode = 0
        | LIBSSH2_SFTP_RENAME_OVERWRITE
        | LIBSSH2_SFTP_RENAME_ATOMIC
        | LIBSSH2_SFTP_RENAME_NATIVE;
        const char *acp = [atPath UTF8String];
        const char *ncp = [newPath UTF8String];
        rc = libssh2_sftp_rename_ex(sftp,
                                    acp,
                                    (unsigned int)strlen(acp),
                                    newPath.UTF8String,
                                    (unsigned int)strlen(ncp),
                                    mode);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            usleep(LIBSSH2_CONTINUE_EAGAIN_WAIT);
            continue;
        }
        break;
    }
    [self unsafeReadLastError];
    if (rc != 0) {
        [self unsafeFileTransferSetErrorForFile:atPath pathIsRemote:YES failureReason:@"remote permission denied"];
        return NO;
    }
    return YES;
}

- (void)unsafeFileTransferSetErrorForFile:(NSString*)filePath
                             pathIsRemote:(BOOL)pathIsRemote
                            failureReason:(NSString*)failureReason
{
    NSString *description = [[NSString alloc] initWithFormat:@"%@ raising error %@ with file at path %@",
                             pathIsRemote ? @"remote" : @"local",
                             failureReason,
                             filePath];
    NSLog(@"%@", description);
    @synchronized (self.lastFileTransferError) {
        self.lastFileTransferError = description;
    }
}

@end
