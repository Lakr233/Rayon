//
//  NSRemoteChannelSocketPair.m
//  
//
//  Created by Lakr Aream on 2022/3/9.
//

#import "NSRemoteChannelSocketPair.h"

@implementation NSRemoteChannelSocketPair

- (instancetype)initWithSocket:(int)socket
                   withChannel:(LIBSSH2_CHANNEL*)channel
{
    self = [super init];
    if (self) {
        _socket = socket;
        _channel = channel;
        _completed = NO;
    }
    return self;
}

- (void)uncheckedConcurrencyCallNonblockingOperations {
    if (self.completed) { return; }
    if (![self seatbeltCheckPassed]) { return; }
    [self uncheckedConcurrencyProcessReadWrite];
}

- (void)uncheckedConcurrencyProcessReadWrite {
    do {
        long len = 0;
        char buf[BUFFER_SIZE];
        memset(buf, 0, sizeof(buf));
        len = recv(self.socket, buf, sizeof(buf), 0);
        if (len > 0) {
            long wr = 0;
            while(wr < len) {
                long i = libssh2_channel_write(self.channel, buf + wr, len - wr);
                if (LIBSSH2_ERROR_EAGAIN == i) { continue; }
                if (i <= 0) {
                    NSLog(@"libssh2_channel_write returns failure %ld", len);
                    self.completed = YES;
                    return;
                }
                wr += i;
            }
        }
    } while (0);
    do {
        char buf[BUFFER_SIZE];
        memset(buf, 0, sizeof(buf));
        long len = 0;
        len = libssh2_channel_read(self.channel, buf, sizeof(buf));
        if (len > 0) {
            long wr = 0;
            while(wr < len) {
                long i = send(self.socket, buf + wr, len - wr, 0);
                if (i <= 0) { self.completed = YES; return; }
                wr += i;
            }
        } else if (len != LIBSSH2_ERROR_EAGAIN) {
            NSLog(@"libssh2_channel_read returns failure %ld", len);
            self.completed = YES;
            return;
        }
    } while (0);
    // connection may send 0 tcp packet data but still keep alive
    // so only check eof
}

- (void)setCompleted:(BOOL)completed {
    if (_completed != completed) {
        _completed = completed;
        [self uncheckedConcurrencyDisconnectAndPrepareForRelease];
    }
}

- (BOOL)seatbeltCheckPassed {
    if (!self.channel) { self.completed = YES; return NO; }
    if (!self.socket) { self.completed = YES; return NO; }
    return YES;
}

- (BOOL)uncheckedConcurrencyInsanityCheckAndReturnDidSuccess {
    do {
        if (self.completed) { break; }
        if (![self seatbeltCheckPassed]) { break; }
        if (libssh2_channel_eof(self.channel)) { break; }
        return YES;
    } while (0);
    return NO;
}

- (void)uncheckedConcurrencyDisconnectAndPrepareForRelease {
    if (!self.completed) { self.completed = YES; }
    if (!self.channel) { return; }
    if (!self.socket) { return; }
    LIBSSH2_CHANNEL *channel = self.channel;
    [GenericNetworking destroyNativeSocket:self.socket];
    self.channel = NULL;
    self.socket = 0;
    LIBSSH2_CHANNEL_SHUTDOWN(channel);
}

@end
