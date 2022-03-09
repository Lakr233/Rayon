//
//  NSRemoteChannleSocketPair.h
//  
//
//  Created by Lakr Aream on 2022/3/9.
//

#import "GenericHeaders.h"
#import "GenericNetworking.h"
#import "NSRemoteShell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSRemoteChannleSocketPair : NSObject <NSRemoteOperableObject>

@property (nonatomic, readwrite, assign) int socket;
@property (nonatomic, readwrite, nullable, assign) LIBSSH2_CHANNEL *channel;
@property (nonatomic, readwrite, assign) BOOL completed;
@property (nonatomic, readwrite, nonnull, strong) NSDate *lastDataAvailable;
@property (nonatomic, readwrite, nonnull, strong) NSNumber *timeout;

- (instancetype)initWithSocket:(int)socket
                   withChannel:(LIBSSH2_CHANNEL*)channel
                   withTimeout:(NSNumber*)timeout;

@end

NS_ASSUME_NONNULL_END
