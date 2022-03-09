//
//  TSEventLoop.h
//  
//
//  Created by Lakr Aream on 2022/2/5.
//

#import <Foundation/Foundation.h>

#import "GenericHeaders.h"
#import "NSRemoteShell.h"

NS_ASSUME_NONNULL_BEGIN

@interface TSEventLoop : NSObject <NSPortDelegate>

- (instancetype)initWithParent:(__weak NSRemoteShell*)parent;
- (void)explicitRequestHandle;
- (void)destroyLoop;

@end

NS_ASSUME_NONNULL_END
