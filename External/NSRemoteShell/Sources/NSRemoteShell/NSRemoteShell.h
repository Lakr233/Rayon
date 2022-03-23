//
//  NSRemoteShell.h
//
//
//  Created by Lakr Aream on 2022/2/4.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "NSRemoteFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSRemoteShell : NSObject

@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly, getter=isConnectedFileTransfer) BOOL connectedFileTransfer;
@property (nonatomic, readonly, getter=isAuthenticated) BOOL authenticated;

@property (nonatomic, readonly, strong) NSString *remoteHost;
@property (nonatomic, readonly, strong) NSNumber *remotePort;
@property (nonatomic, readonly, strong) NSNumber *operationTimeout;

@property (nonatomic, readonly, nullable, strong) NSString *resolvedRemoteIpAddress;
@property (nonatomic, readonly, nullable, strong) NSString *remoteBanner;
@property (nonatomic, readonly, nullable, strong) NSString *remoteFingerPrint;

#pragma mark initializer

- (instancetype)init;
- (instancetype)setupConnectionHost:(NSString *)targetHost;
- (instancetype)setupConnectionPort:(NSNumber *)targetPort;
- (instancetype)setupConnectionTimeout:(NSNumber *)timeout;

#pragma mark event loop

- (void)handleRequestsIfNeeded;
- (void)explicitRequestStatusPickup;

#pragma mark connection

- (void)requestConnectAndWait;
- (void)requestDisconnectAndWait;

#pragma mark authenticate

- (void)authenticateWith:(NSString *)username
             andPassword:(NSString *)password;
- (void)authenticateWith:(NSString *)username
            andPublicKey:(nullable NSString *)publicKey
           andPrivateKey:(NSString *)privateKey
             andPassword:(nullable NSString *)password;

#pragma mark helper

- (nullable NSString *)getLastError;
- (nullable NSString*)getLastFileTransferError;

#pragma mark execution

- (int)beginExecuteWithCommand:(NSString*)withCommand
                   withTimeout:(NSNumber*)withTimeoutSecond
                  withOnCreate:(dispatch_block_t)withOnCreate
                    withOutput:(nullable void (^)(NSString*))withOutput
       withContinuationHandler:(nullable BOOL (^)(void))withContinuationBlock;

- (void)beginShellWithTerminalType:(nullable NSString*)withTerminalType
                      withOnCreate:(dispatch_block_t)withOnCreate
                  withTerminalSize:(nullable CGSize (^)(void))withRequestTerminalSize
               withWriteDataBuffer:(nullable NSString* (^)(void))withWriteDataBuffer
              withOutputDataBuffer:(void (^)(NSString * _Nonnull))withOutputDataBuffer
           withContinuationHandler:(BOOL (^)(void))withContinuationBlock;

#pragma mark port map

- (void)createPortForwardWithLocalPort:(NSNumber*)localPort
                 withForwardTargetHost:(NSString*)targetHost
                 withForwardTargetPort:(NSNumber*)targetPort
                          withOnCreate:(dispatch_block_t)withOnCreate
               withContinuationHandler:(BOOL (^)(void))continuationBlock;

- (void)createPortForwardWithRemotePort:(NSNumber*)remotePort
                  withForwardTargetHost:(NSString*)targetHost
                  withForwardTargetPort:(NSNumber*)targetPort
                           withOnCreate:(dispatch_block_t)withOnCreate
                withContinuationHandler:(BOOL (^)(void))continuationBlock;

#pragma mark sftp

typedef void (^NSRemoteFileTransferProgressBlock)(NSString *filename, NSProgress *uploadProgress, long bytesPerSecond);
typedef void (^NSRemoteFileDeleteProgressBlock)(NSString *currentFile);

- (void)requestConnectFileTransferAndWait;
- (void)requestDisconnectFileTransferAndWait;
- (nullable NSArray<NSRemoteFile*>*)requestFileListAt:(NSString*)atDirPath;
- (nullable NSRemoteFile*)requestFileInfoAt:(NSString*)atPath;
- (BOOL)requestRenameFileAndWait:(NSString*)atPath
                     withNewPath:(NSString*)newPath;
- (BOOL)requestUploadForFileAndWait:(NSString*)atPath
                        toDirectory:(NSString*)toDirectory
                         onProgress:(NSRemoteFileTransferProgressBlock _Nonnull)onProgress
            withContinuationHandler:(BOOL (^)(void))continuationBlock;
- (BOOL)requestDeleteForFileAndWait:(NSString*)atPath
                  withProgressBlock:(NSRemoteFileDeleteProgressBlock _Nonnull)onProgress
            withContinuationHandler:(BOOL (^)(void))continuationBlock;
//- (void)requestDeleteUsingRMCommandForFileAndWait:(NSString*)atPath; // how to escape parameters safely?
- (BOOL)requestCreateDirAndWait:(NSString*)atPath;
- (BOOL)requestDownloadFromFileAndWait:(NSString*)atPath
                           toLocalPath:(NSString*)toPath
                            onProgress:(NSRemoteFileTransferProgressBlock _Nonnull)onProgress               withContinuationHandler:(BOOL (^)(void))continuationBlock;

#pragma mark destory

/// This function is used to force shutdown everything, including the run loop and it's associated thread
/// when ARC is not working, call this function
- (void)destroyPermanently;

@end

NS_ASSUME_NONNULL_END
