//
//  GenericHeaders.h
//  
//
//  Created by Lakr Aream on 2022/2/4.
//

#import <libssh2.h>
#import <libssh2_sftp.h>
#import <libssh2_publickey.h>

#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <netdb.h>

#import <Foundation/Foundation.h>

/*
 the buffer size define the size that should read from a socket at a time
 is required to be larger then socket opt size
 
 the default size of it is set by system and can be find by
 > sysctl -a | grep net.inet.tcp
 net.inet.tcp.sendspace: 131072
 net.inet.tcp.recvspace: 131072
 
 TODO: FIXME:
 this is a workaround for data being cut in half
 */
#define BUFFER_SIZE 131072

/*
 the interval for sending keep alive packet, count in second
 [NSRemoteShell unsafeKeepAliveCheck] will skip
 if last success attempt was within the interval
 */
#define KEEPALIVE_INTERVAL 1

/*
 represent how many failure sending keep alive packet shall we ignore
 before cutting down the connection on client (our) side
 */
#define KEEPALIVE_ERROR_TOLERANCE_MAX_RETRY 8

/*
 represent max wait time of an operation with dispatch semaphore can wait
 counted in second, most used in requestXxxAndWait
 DONT USE IN RUNNING SESSION/CHANNEL
 */
#define DISPATCH_SEMAPHORE_MAX_WAIT 30
#define MakeDispatchSemaphoreWaitWithTimeout(SEM) do { \
dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, DISPATCH_SEMAPHORE_MAX_WAIT * NSEC_PER_SEC); \
if (dispatch_semaphore_wait((SEM), timeout)) { \
NSLog(@"dispatch semaphore wait timeout for %d second, exiting blocked operation", DISPATCH_SEMAPHORE_MAX_WAIT); \
} \
} while (0);

#define DISPATCH_SEMAPHORE_CHECK_SIGNLE(SEM) do { \
if ((SEM)) { dispatch_semaphore_signal((SEM)); } \
} while (0);

/*
 common used libssh2 channel gracefully shutdown all in one
 */
#define LIBSSH2_CHANNEL_SHUTDOWN(CHANNEL) do { \
while (libssh2_channel_send_eof(CHANNEL) == LIBSSH2_ERROR_EAGAIN) {}; \
while (libssh2_channel_close(CHANNEL) == LIBSSH2_ERROR_EAGAIN) {}; \
while (libssh2_channel_wait_closed(CHANNEL) == LIBSSH2_ERROR_EAGAIN) {}; \
while (libssh2_channel_free(CHANNEL) == LIBSSH2_ERROR_EAGAIN) {}; \
} while (0);

/*
 represent socket option at queue_maxsize, can be any size
 
 but libssh2 has this defined so might just use 16 to balance
 #define libssh2_channel_forward_listen(session, port) \
 libssh2_channel_forward_listen_ex((session), NULL, (port), NULL, 16)
 */
#define SOCKET_QUEUE_MAXSIZE 16

/*
 represent how much data shall we send per scp request
 */
#define SFTP_BUFFER_SIZE (BUFFER_SIZE)

/*
 represent how deep we can go while using sftp delete
 used to prevent app from crash
 */
#define SFTP_RECURSIVE_DEPTH 20 // don't use our app to do heavy task!

/*
 defines the event loop handler class for NSRemoteShell
 */
@protocol NSRemoteOperableObject

// used in event loop call, it's time to handle operations inside this object
// eg: NSRemoteChannel should read/write to socket, set changes and do anything else
// is designed to be thread safe when calling
- (void)unsafeCallNonblockingOperations;

// used to evaluate if this object should be close and release
// if a check failed, disconnect is immediately called
- (BOOL)unsafeInsanityCheckAndReturnDidSuccess;

// shutdown any associated resources and will soon be release
- (void)unsafeDisconnectAndPrepareForRelease;

@end
