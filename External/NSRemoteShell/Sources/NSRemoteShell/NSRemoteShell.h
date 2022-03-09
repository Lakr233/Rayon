//
//  NSRemoteShell.h
//
//
//  Created by Lakr Aream on 2022/2/4.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSRemoteShell : NSObject

@property (nonatomic, readonly, getter=isConnected) BOOL connected;
@property (nonatomic, readonly, getter=isAuthenicated) BOOL authenticated;

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

- (instancetype)requestConnectAndWait;
- (instancetype)requestDisconnectAndWait;

#pragma mark authenticate

- (instancetype)authenticateWith:(NSString *)username
                     andPassword:(NSString *)password;
- (instancetype)authenticateWith:(NSString *)username
                    andPublicKey:(nullable NSString *)publicKey
                   andPrivateKey:(NSString *)privateKey
                     andPassword:(nullable NSString *)password;

#pragma mark helper

- (nullable NSString *)getLastError;

#pragma mark execution

- (instancetype)executeRemote:(NSString*)command
             withExecTimeout:(NSNumber*)timeoutSecond
                  withOutput:(nullable void (^)(NSString*))responseDataBlock
     withContinuationHandler:(nullable BOOL (^)(void))continuationBlock;

- (instancetype)openShellWithTerminal:(nullable NSString*)terminalType
                     withTerminalSize:(nullable CGSize (^)(void))requestTerminalSize
                        withWriteData:(nullable NSString* (^)(void))requestWriteData
                           withOutput:(void (^)(NSString * _Nonnull))responseDataBlock
              withContinuationHandler:(BOOL (^)(void))continuationBlock;

#pragma mark port map

- (instancetype)createPortForwardWithLocalPort:(NSNumber*)localPort
                         withForwardTargetHost:(NSString*)targetHost
                         withForwardTargetPort:(NSNumber*)targetPort
                       withContinuationHandler:(BOOL (^)(void))continuationBlock;

- (instancetype)createPortForwardWithRemotePort:(NSNumber*)remotePort
                          withForwardTargetHost:(NSString*)targetHost
                          withForwardTargetPort:(NSNumber*)targetPort
                        withContinuationHandler:(BOOL (^)(void))continuationBlock;

@end

NS_ASSUME_NONNULL_END
