//
//  Constructor.m
//  
//
//  Created by Lakr Aream on 2022/2/5.
//

#import "Constructor.h"
#import "GenericHeaders.h"
#import "TSEventLoop.h"

#import <Foundation/Foundation.h>

int kLIBSSH2_CONSTRUCTOR_SUCCESS = 0;

#if TARGET_OS_MAC

/*
 
 https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html
 
 App Nap will make our Timer inside CFRunLoop not waking up on schedule
 which will then cause a port forward to die
 
 we are here to disable it on macOS
 
 */
NSObject *activity = NULL;

#endif

__attribute__((constructor)) void libssh2_constructor(void) {
    int ret = libssh2_init(0); // flag 1 == no crypto
    if (ret == 0) {
        kLIBSSH2_CONSTRUCTOR_SUCCESS = 1;
        NSLog(@"libssh2 init success");
    }
#if TARGET_OS_MAC
    activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityLatencyCritical reason:@"NSRemoteShell is latency critical"];
#endif
}

__attribute__((destructor)) void libssh2_destructor(void) {
    if (kLIBSSH2_CONSTRUCTOR_SUCCESS) {
        libssh2_exit();
    }
#if TARGET_OS_MAC
    if (activity) {
        [[NSProcessInfo processInfo] endActivity:activity];
    }
#endif
}

int libssh2_init_check() {
    return kLIBSSH2_CONSTRUCTOR_SUCCESS;
}

/*
 used for our CI machine, don't remove this if making contribute
 */
NSString *NSRemoteShellVersion = @"k.S-BrGcrAzymeD6jQ7FdFw6stCZW";
