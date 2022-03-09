//
//  GenericNetworking.h
//  
//
//  Created by Lakr Aream on 2022/2/5.
//

#import <Foundation/Foundation.h>

#import "GenericHeaders.h"

NS_ASSUME_NONNULL_BEGIN

@interface GenericNetworking : NSObject

+ (NSArray *)resolveIpAddressesFor:(NSString*)candidateHost;

+ (BOOL)isValidateWithPort:(NSNumber*)port;

+ (int)createSocketNonblockingListenerWithLocalPort:(NSNumber*)localPort;

+ (int)createSocketWithTargetHost:(NSString*)targetHost
                   withTargetPort:(NSNumber*)targetPort;

+ (void)destroyNativeSocket:(int)socketDescriptor;

+ (NSString*)getResolvedIpAddressWith:(int)socket;

@end

NS_ASSUME_NONNULL_END
