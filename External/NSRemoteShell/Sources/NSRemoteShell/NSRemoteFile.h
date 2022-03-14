//
//  NSRemoteFile.h
//  
//
//  Created by Lakr Aream on 2022/3/14.
//

#ifndef NSRemoteFile_h
#define NSRemoteFile_h

#import "GenericHeaders.h"

@interface NSRemoteFile : NSObject

@property (nonatomic, readonly, nonnull, strong) NSString *name;
@property (nonatomic, readonly, nullable, strong) NSNumber *size;
@property (nonatomic, readonly, assign) BOOL isDirectory;
@property (nonatomic, readonly, nullable, strong) NSDate *modificationDate;
@property (nonatomic, readonly, nullable, strong) NSDate *lastAccess;
@property (nonatomic, readonly, assign) unsigned long ownerUID;
@property (nonatomic, readonly, assign) unsigned long ownerGID;
@property (nonatomic, readonly, nonnull, strong) NSString *permissionDescription;

- (nonnull instancetype)initWithFilename:(nonnull NSString *)filename;
- (void)populateAttributes:(LIBSSH2_SFTP_ATTRIBUTES)fileAttributes;

@end

#endif /* NSRemoteFile_h */
