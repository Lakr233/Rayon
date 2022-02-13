//
//  NSRemoteChannel.h
//  
//
//  Created by Lakr Aream on 2022/2/6.
//

#import <Foundation/Foundation.h>

#import "GenericHeaders.h"
#import "NSRemoteShell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSRemoteChannel : NSObject

typedef NSString* _Nonnull (^NSRemoteChannelRequestDataBlock)(void);
typedef void (^NSRemoteChannelReceiveDataBlock)(NSString *);
typedef BOOL (^NSRemoteChannelContinuationBlock)(void);
typedef CGSize (^NSRemoteChannelTerminalSizeBlock)(void);

@property (nonatomic, nullable, assign) LIBSSH2_SESSION *representedSession;
@property (nonatomic, nullable, assign) LIBSSH2_CHANNEL *representedChannel;

@property (nonatomic, readonly) BOOL channelCompleted;

- (instancetype)initWithRepresentedSession:(LIBSSH2_SESSION*)representedSession
                    withRepresentedChanel:(LIBSSH2_CHANNEL*)representedChannel;

- (void)insanityUncheckedEventLoop;

- (void)onTermination:(dispatch_block_t)terminationHandler;

- (void)setRequestDataChain:(NSRemoteChannelRequestDataBlock _Nonnull)requestData;
- (void)setRecivedDataChain:(NSRemoteChannelReceiveDataBlock _Nonnull)receiveData;
- (void)setContinuationChain:(NSRemoteChannelContinuationBlock _Nonnull)continuation;
- (void)setTerminalSizeChain:(NSRemoteChannelTerminalSizeBlock _Nonnull)terminalSize;

- (void)setChannelTimeoutWith:(double)timeoutValueFromNowInSecond;
- (void)setChannelTimeoutWithScheduled:(NSDate*)timeoutDate;

- (void)uncheckedConcurrencyChannelTerminalSizeUpdate;
- (void)uncheckedConcurrencyChannelCloseIfNeeded;

@end

NS_ASSUME_NONNULL_END
