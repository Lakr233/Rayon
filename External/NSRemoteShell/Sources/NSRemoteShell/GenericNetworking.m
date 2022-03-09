//
//  GenericNetworking.m
//
//
//  Created by Lakr Aream on 2022/2/5.
//

#import "GenericNetworking.h"

@implementation GenericNetworking

+ (NSArray *)resolveIpAddressesFor:(NSString*)candidateHost
{
	if (!candidateHost) return [[NSArray alloc] init];
    NSArray<NSData*> *candidateHostData = [[NSArray alloc] init];
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;        // PF_INET if you want only IPv4 addresses
    hints.ai_protocol = IPPROTO_TCP;
    struct addrinfo *addrs, *addr;
    getaddrinfo([candidateHost UTF8String], NULL, &hints, &addrs);
    for (addr = addrs; addr; addr = addr->ai_next) {
        char host[NI_MAXHOST];
        getnameinfo(addr->ai_addr, addr->ai_addrlen, host, sizeof(host), NULL, 0, NI_NUMERICHOST);
        if (strlen(host) <= 0) { continue; }
        NSString *hostStr = [[NSString alloc] initWithUTF8String:host];
        NSLog(@"resolving host %@ loading result: %@", candidateHost, hostStr);
        NSData *build = [[NSData alloc] initWithBytes:addr->ai_addr length: addr->ai_addrlen];
        candidateHostData = [candidateHostData arrayByAddingObject:build];
    }
    freeaddrinfo(addrs);
    return candidateHostData;
}

+ (BOOL)isValidateWithPort:(NSNumber*)port {
    int p = [port intValue];
    // we are treating 0 as a valid port and technically it should work!
    if (p >= 0 && p <= 65535) {
        return YES;
    }
    return NO;
}

+ (int)createSocketNonblockingListenerWithLocalPort:(NSNumber*)localPort
{
    if (![GenericNetworking isValidateWithPort:localPort]) {
        NSLog(@"invalid port %@", [localPort stringValue]);
        return;
    }

    int port = [localPort intValue];
    struct sockaddr_in server4;
    int socket_desc4 = socket(AF_INET, SOCK_STREAM, 0);
    if (socket_desc4 <= 0) {
        NSLog(@"failed to create socket for ipv4 at port %d", port);
        return 0;
    }
    server4.sin_family = AF_INET;
    server4.sin_addr.s_addr = inet_addr("127.0.0.1"); // for security?
    server4.sin_port = htons(port);
    if (setsockopt(socket_desc4, SOL_SOCKET, SO_REUSEPORT, &(int){1}, sizeof(int)) == -1) {
        NSLog(@"failed to setsockopt for ipv4 at port %d", port);
        close(socket_desc4);
        return 0;
    }
    if (bind(socket_desc4, (struct sockaddr*)&server4, sizeof(server4)) < 0) {
        NSLog(@"failed to bind socket for ipv4 at port %d", port);
        close(socket_desc4);
        return 0;
    } else {
        NSLog(@"bound listener v4 for port %d", port);
    }
    if (fcntl(socket_desc4, F_SETFL, fcntl(socket_desc4, F_GETFL, 0) | O_NONBLOCK) == -1) {
        NSLog(@"failed to call fcntl for none-blocking ipv4 at port %d", port);
        close(socket_desc4);
        return 0;
    }
    if (listen(socket_desc4, SOCKET_QUEUE_MAXSIZE) == -1) {
        NSLog(@"failed to call fcntl for none-blocking ipv6 at port %d", port);
        close(socket_desc4);
        return 0;
    }
    
    NSLog(@"socket listener for port %d booted", port);
    return socket_desc4;
}

+ (int)createSocketWithTargetHost:(NSString *)targetHost
                   withTargetPort:(NSNumber *)targetPort
             requireNonblockingIO:(BOOL)useNonblocking
{
    if (![self isValidateWithPort:targetPort]) { return; }
    int candidatePort = [targetPort intValue];
    NSArray *addrData = [self resolveIpAddressesFor:targetHost];
    if (!addrData) { return 0; }
    for (id candidateHostData in addrData) {
        if ([candidateHostData length] == sizeof(struct sockaddr_in)) {
            struct sockaddr_in address4;
            [candidateHostData getBytes:&address4 length:sizeof(address4)];
            address4.sin_port = htons(candidatePort);
            char str[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(address4.sin_addr), str, INET_ADDRSTRLEN);
            int forwardsock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
            if (forwardsock <= 0) {
                NSLog(@"socket failed to create, trying next");
                continue;
            }
            int rv = connect(forwardsock, (struct sockaddr*)&address4, sizeof(struct sockaddr_in));
            if (rv != 0) {
                NSLog(@"socket failed to connect, trying next address");
                close(forwardsock);
                continue;
            }
            if (useNonblocking && fcntl(forwardsock, F_SETFL, fcntl(forwardsock, F_GETFL, 0) | O_NONBLOCK) == -1) {
                NSLog(@"failed to call fcntl for none-blocking for socket %d", forwardsock);
                close(forwardsock);
                continue;
            }
            NSLog(@"created socket %d", forwardsock);
            return forwardsock;
        } else if ([candidateHostData length] == sizeof(struct sockaddr_in6)) {
            struct sockaddr_in6 address6;
            [candidateHostData getBytes:&address6 length:sizeof(address6)];
            address6.sin6_port = htons(candidatePort);
            char str[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &(address6.sin6_addr), str, INET6_ADDRSTRLEN);
            int forwardsock = socket(PF_INET6, SOCK_STREAM, IPPROTO_TCP);
            if (forwardsock <= 0) {
                NSLog(@"socket failed to create, trying next");
                continue;
            }
            int rv = connect(forwardsock, (struct sockaddr*)&address6, sizeof(struct sockaddr_in6));
            if (rv != 0) {
                NSLog(@"socket failed to connect, trying next address");
                close(forwardsock);
                continue;
            }
            if (useNonblocking && fcntl(forwardsock, F_SETFL, fcntl(forwardsock, F_GETFL, 0) | O_NONBLOCK) == -1) {
                NSLog(@"failed to call fcntl for none-blocking for socket %d", forwardsock);
                close(forwardsock);
                continue;
            }
            NSLog(@"created socket %d", forwardsock);
            return forwardsock;
        } else {
            NSLog(@"unrecognized address candidate size");
            continue;
        }
    }
    return 0;
}

+ (void)destroyNativeSocket:(int)socketDescriptor {
    if (socketDescriptor > 0) {
        NSLog(@"closing socket fd %d", socketDescriptor);
        close(socketDescriptor);
    }
}

+ (NSString*)getResolvedIpAddressWith:(int)socket {
    if (!socket) { return @""; }
    struct sockaddr_in sin;
    socklen_t len = sizeof(sin);
    getpeername(socket, (struct sockaddr*)&sin, &len);
    char buf[255];
    memset(buf, 0, sizeof(buf));
    switch(sin.sin_family) {
        case AF_INET: {
            struct sockaddr_in *addr_in = (struct sockaddr_in *)&sin;
            inet_ntop(AF_INET, &(addr_in->sin_addr), buf, INET_ADDRSTRLEN);
            break;
        }
        case AF_INET6: {
            struct sockaddr_in6 *addr_in6 = (struct sockaddr_in6 *)&sin;
            inet_ntop(AF_INET6, &(addr_in6->sin6_addr), buf, INET6_ADDRSTRLEN);
            break;
        }
        default:
            break;
    }
    return [[NSString alloc] initWithUTF8String:buf];
}

@end
