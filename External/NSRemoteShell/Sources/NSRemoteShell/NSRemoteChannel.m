//
//  NSRemoteChannel.m
//  
//
//  Created by Lakr Aream on 2022/2/6.
//

#import "NSRemoteChannel.h"

@interface NSRemoteChannel ()

@property (nonatomic, nullable, strong) NSRemoteChannelRequestDataBlock requestDataBlock;
@property (nonatomic, nullable, strong) NSRemoteChannelReceiveDataBlock receiveDataBlock;
@property (nonatomic, nullable, strong) NSRemoteChannelContinuationBlock continuationDecisionBlock;
@property (nonatomic, nullable, strong) NSRemoteChannelTerminalSizeBlock requestTerminalSizeBlock;

@property (nonatomic) CGSize currentTerminalSize;

@property (nonatomic, nullable, strong) NSDate *scheduledTermination;
@property (nonatomic, nullable, strong) dispatch_block_t terminationBlock;

@property (nonatomic, readwrite) BOOL channelCompleted;

@end

@implementation NSRemoteChannel

// MARK: - LIFE CYCLE

- (instancetype)initWithRepresentedSession:(LIBSSH2_SESSION *)representedSession
                     withRepresentedChanel:(LIBSSH2_CHANNEL *)representedChannel
{
    self = [super init];
    if (self) {
        _representedSession = representedSession;
        _representedChannel = representedChannel;
        _channelCompleted = NO;
        _currentTerminalSize = CGSizeMake(0, 0);
    }
    return self;
}

- (void)dealloc {
    NSLog(@"channel object at %p deallocating", self);
    [self uncheckedConcurrencyChannelCloseIfNeeded];
}

// MARK: - EVENT LOOP

- (void)insanityUncheckedEventLoop {
    if (self.channelCompleted) { return; }
    if (![self seatbeltCheckPassed]) { return; }
    [self uncheckedConcurrencyChannelRead];
    [self uncheckedConcurrencyChannelTerminalSizeUpdate];
    [self uncheckedConcurrencyChannelWrite];
    [self uncheckedConcurrencyChannelShouldTerminate];
}

// MARK: - SETUP

- (void)onTermination:(dispatch_block_t)terminationHandler {
    if (terminationHandler) {
        self.terminationBlock = terminationHandler;
    } else {
        self.terminationBlock = NULL;
    }
}

- (void)setRequestDataChain:(NSRemoteChannelRequestDataBlock _Nonnull)requestData {
    if (!requestData) {
        self.requestDataBlock = NULL;
    } else {
        self.requestDataBlock = requestData;
    }
}

- (void)setRecivedDataChain:(NSRemoteChannelReceiveDataBlock _Nonnull)receiveData {
    if (!receiveData) {
        self.receiveDataBlock = NULL;
    } else {
        self.receiveDataBlock = receiveData;
    }
}

- (void)setContinuationChain:(NSRemoteChannelContinuationBlock _Nonnull)continuation {
    if (!continuation) {
        self.continuationDecisionBlock = NULL;
    } else {
        self.continuationDecisionBlock = continuation;
    }
}

- (void)setTerminalSizeChain:(NSRemoteChannelTerminalSizeBlock _Nonnull)terminalSize {
    if (terminalSize) {
        self.requestTerminalSizeBlock = terminalSize;
    } else {
        self.requestTerminalSizeBlock = NULL;
    }
}

- (void)setChannelTimeoutWith:(double)timeoutValueFromNowInSecond {
    if (timeoutValueFromNowInSecond <= 0) {
        return;
    }
    NSDate *schedule = [[NSDate alloc] initWithTimeIntervalSinceNow:timeoutValueFromNowInSecond];
    [self setChannelTimeoutWithScheduled:schedule];
}

- (void)setChannelTimeoutWithScheduled:(NSDate*)timeoutDate {
    self.scheduledTermination = timeoutDate;
}

- (void)setChannelCompleted:(BOOL)channelCompleted {
    if (_channelCompleted != channelCompleted) {
        _channelCompleted = channelCompleted;
        [self uncheckedConcurrencyChannelCloseIfNeeded];
    }
}

// MARK: - EXEC

- (BOOL)seatbeltCheckPassed {
    if (!self.representedSession) { self.channelCompleted = YES; return NO; }
    if (!self.representedChannel) { self.channelCompleted = YES; return NO; }
    return YES;
}

- (void)uncheckedConcurrencyChannelRead {
    char buffer[BUFFER_SIZE];
    char errorBuffer[BUFFER_SIZE];
    memset(buffer, 0, sizeof(buffer));
    memset(errorBuffer, 0, sizeof(errorBuffer));
    
    long rcout = libssh2_channel_read(self.representedChannel, buffer, (ssize_t)sizeof(buffer));
    long rcerr = libssh2_channel_read_stderr(self.representedChannel, errorBuffer, (ssize_t)sizeof(errorBuffer));
    
    if (rcout != LIBSSH2_ERROR_EAGAIN && rcout > 0) {
        NSString *read = [[NSString alloc] initWithUTF8String:buffer];
        if (self.receiveDataBlock) {
            self.receiveDataBlock(read);
        }
    }
    if (rcerr != LIBSSH2_ERROR_EAGAIN && rcerr > 0) {
        NSString *read = [[NSString alloc] initWithUTF8String:errorBuffer];
        if (self.receiveDataBlock) {
            self.receiveDataBlock(read);
        }
    }
}

- (void)uncheckedConcurrencyChannelWrite {
    if (!self.requestDataBlock) {
        return;
    }
    NSString *requestedBuffer = self.requestDataBlock();
    if (!requestedBuffer || [requestedBuffer length] < 1) {
        return;
    }
    NSData *data = [requestedBuffer dataUsingEncoding:NSUTF8StringEncoding];
    if (!data || [data length] < 1) {
        NSLog(@"error occurred during message encode, ignoring empty data");
        return;
    }
    while (true) {
        if ([self uncheckedConcurrencyChannelShouldTerminate]) {
            break;
        }
        // Actual number of bytes written or negative on failure.
        long rc = libssh2_channel_write(self.representedChannel, [data bytes], [data length]);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        if (rc < 0) {
            NSLog(@"error occurred during message write, consider terminated channel");
            break;
        }
        if (rc != [data length]) {
            NSLog(@"written data was smaller than giving, data might broke");
            break;
        }
        // do not deal with error?
        break;
    }
}

- (BOOL)uncheckedConcurrencyChannelShouldTerminate {
    do {
        if (self.scheduledTermination && [self.scheduledTermination timeIntervalSinceNow] < 0) {
            NSLog(@"channel terminating due to timeout schedule");
            break;
        }
        if (self.continuationDecisionBlock && !self.continuationDecisionBlock()) {
            break;
        }
        long rc = libssh2_channel_eof(self.representedChannel);
        if (rc == 1) {
            break;
        }
        if (rc < 0 && rc != LIBSSH2_ERROR_EAGAIN) {
            break;
        }
        return NO;
    } while (0);
    self.channelCompleted = YES;
    return YES;
}

- (void)uncheckedConcurrencyChannelTerminalSizeUpdate {
    // may called from outside
    if (![self seatbeltCheckPassed]) { return; }
    if (!self.requestTerminalSizeBlock) {
        return;
    }
    CGSize targetSize = self.requestTerminalSizeBlock();
    if (CGSizeEqualToSize(targetSize, self.currentTerminalSize)) {
        return;
    }
    self.currentTerminalSize = targetSize;
    while (true) {
        long rc = libssh2_channel_request_pty_size(self.representedChannel,
                                                   targetSize.width,
                                                   targetSize.height);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            continue;
        }
        // don't check error here?
        break;
    }
}

- (void)uncheckedConcurrencyChannelCloseIfNeeded {
    // may called from outside, and don't loop here
//    if (![self seatbeltCheckPassed]) { return; }
    if (!self.representedSession) { return; }
    if (!self.representedChannel) { return; }
    if (!self.channelCompleted) { self.channelCompleted = YES; }
    LIBSSH2_CHANNEL *channel = self.representedChannel;
    self.representedChannel = NULL;
    self.representedSession = NULL;
    while (libssh2_channel_send_eof(channel) == LIBSSH2_ERROR_EAGAIN) {};
    while (libssh2_channel_close(channel) == LIBSSH2_ERROR_EAGAIN) {};
    while (libssh2_channel_wait_closed(channel) == LIBSSH2_ERROR_EAGAIN) {};
    while (libssh2_channel_free(channel) == LIBSSH2_ERROR_EAGAIN) {};
    if (self.terminationBlock) {
        self.terminationBlock();
    }
    self.terminationBlock = NULL;
}
@end
