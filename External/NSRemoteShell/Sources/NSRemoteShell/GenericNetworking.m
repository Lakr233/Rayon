//
//  GenericNetworking.m
//
//
//  Created by Lakr Aream on 2022/2/5.
//

#import "GenericNetworking.h"

#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>

@implementation GenericNetworking

+ (NSArray *)resolveIpAddressesFor:(NSString*)candidateHost
{
	if (!candidateHost) return [[NSArray alloc] init];
	NSArray<NSString *> *components = [candidateHost componentsSeparatedByString:@":"];
	NSInteger componentsCount = [components count];
	if (!components || componentsCount < 1) {
		return [[NSArray alloc] init];
	};

	// making target address
	NSString *resolvingAddress = components[0];

	// IPv6 Fixup
	if (componentsCount >= 4) {
		// handle case [{IPv6}]:{port}
		NSString *first = [components firstObject];
		NSString *last = [components lastObject];
		if ([first hasPrefix:@"["] && [last hasSuffix:@"]"]) {
			NSRange trailing = [candidateHost rangeOfString:@"]" options:NSBackwardsSearch];
			NSRange subRange = NSMakeRange(1, trailing.location - 1);
			resolvingAddress = [candidateHost substringWithRange:subRange];
		}
	} else if (componentsCount >= 3) {
		// handle case {IPv6}
		resolvingAddress = candidateHost;
	}
	if (!resolvingAddress || [resolvingAddress length] < 1) {
		return [[NSArray alloc] init];
	};

	// create host ref
	CFHostRef foundationHost = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef _Nonnull)(resolvingAddress));
	if (!foundationHost) { return NULL; }

	CFStreamError error;
	NSArray *addressCandidates = nil;

	// resolve host
	int ret = CFHostStartInfoResolution(foundationHost, kCFHostAddresses, &error);
	if (ret) {
		addressCandidates = (__bridge NSArray *)(CFHostGetAddressing(foundationHost, NULL));
	}

	CFRelease(foundationHost);

    if (addressCandidates) {
        return addressCandidates;
    } else {
        return [[NSArray alloc] init];
    }
}

+ (nullable CFSocketRef)connectSocketWith:(id)candidateHostData
                                 withPort:(long)candidatePort
                              withTimeout:(double)candidateTimeout
                            withIpAddress:(NSMutableString*)resolvedAddress
{
    NSString *ipAddress;
    CFDataRef address = NULL;
    SInt32 addressFamily;
    
    if ([candidateHostData length] == sizeof(struct sockaddr_in)) {
        struct sockaddr_in address4;
        [candidateHostData getBytes:&address4 length:sizeof(address4)];
        address4.sin_port = htons(candidatePort);
        char str[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(address4.sin_addr), str, INET_ADDRSTRLEN);
        ipAddress = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        addressFamily = AF_INET;
        address =
        CFDataCreate(kCFAllocatorDefault, (UInt8 *)&address4, sizeof(address4));
    } else if ([candidateHostData length] == sizeof(struct sockaddr_in6)) {
        struct sockaddr_in6 address6;
        [candidateHostData getBytes:&address6 length:sizeof(address6)];
        address6.sin6_port = htons(candidatePort);
        char str[INET6_ADDRSTRLEN];
        inet_ntop(AF_INET6, &(address6.sin6_addr), str, INET6_ADDRSTRLEN);
        ipAddress = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        addressFamily = AF_INET6;
        address =
        CFDataCreate(kCFAllocatorDefault, (UInt8 *)&address6, sizeof(address6));
    } else {
        NSLog(@"unrecognized address candidate size");
        return NULL;
    }
    
    [resolvedAddress setString:ipAddress];
    NSLog(@"creating connection to %@", ipAddress);
    
    CFSocketRef constructingSocket = nil;
    constructingSocket =
    CFSocketCreate(kCFAllocatorDefault, addressFamily, SOCK_STREAM,
                   IPPROTO_IP, kCFSocketNoCallBack, NULL, NULL);
    if (!constructingSocket) {
        CFRelease(address);
        return NULL;
    }
    
    int set = 1;
    // Upon successful completion, the value 0 is returned; otherwise the value -1
    // is returned and the global variable errno is set to indicate the error.
    if (setsockopt(CFSocketGetNative(constructingSocket), SOL_SOCKET,
                   SO_NOSIGPIPE, (void *)&set, sizeof(set))) {
        NSLog(@"failed to set socket option");
        CFRelease(address);
        CFSocketInvalidate(constructingSocket);
        CFRelease(constructingSocket);
        return NULL;
    }
    
    CFSocketError error = CFSocketConnectToAddress(constructingSocket, address, candidateTimeout);
    
    CFRelease(address);
    
    if (error) {
        NSLog(@"failed to connect socket with reason %li", error);
        CFSocketInvalidate(constructingSocket);
        CFRelease(constructingSocket);
        return NULL;
    }
    
    return constructingSocket;
}

@end
