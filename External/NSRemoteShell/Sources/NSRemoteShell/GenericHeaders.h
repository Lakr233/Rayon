//
//  GenericHeaders.h
//  
//
//  Created by Lakr Aream on 2022/2/4.
//

#import <libssh2.h>
#import <libssh2_sftp.h>
#import <libssh2_publickey.h>

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
 [NSRemoteShell uncheckedConcurrencyKeepAliveCheck] will skip
 if last success attempt was within the interval
 */
#define KEEPALIVE_INTERVAL 1

/*
 represent how many failure sending keep alive packet shall we ignore
 before cutting down the connection on client (our) side
 */
#define KEEPALIVE_ERROR_TOLERANCE_MAX_RETRY 8
