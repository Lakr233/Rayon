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

__attribute__((constructor)) void libssh2_constructor() {
    int ret = libssh2_init(0); // flag 1 == no crypto
    if (ret == 0) {
        kLIBSSH2_CONSTRUCTOR_SUCCESS = 1;
        NSLog(@"libssh2 init success");
    }
    [TSEventLoop sharedLoop];
}

__attribute__((destructor)) void libssh2_destructor() {
    if (kLIBSSH2_CONSTRUCTOR_SUCCESS) {
        libssh2_exit();
    }
}

int libssh2_init_check() {
    return kLIBSSH2_CONSTRUCTOR_SUCCESS;
}
