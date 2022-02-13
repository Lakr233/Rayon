//
//  GenericNetworking.h
//  
//
//  Created by Lakr Aream on 2022/2/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GenericNetworking : NSObject

+ (NSArray *)resolveIpAddressesFor:(NSString*)candidateHost;

+ (nullable CFSocketRef)connectSocketWith:(id)candidateHostData
                                 withPort:(long)candidatePort
                              withTimeout:(double)candidateTimeout
                            withIpAddress:(NSMutableString*)resolvedAddress;

@end

NS_ASSUME_NONNULL_END
