//
//  NSRemoteFile.m
//  
//
//  Created by Lakr Aream on 2022/3/14.
//

#import "NSRemoteFile.h"

@interface NSRemoteFile ()

@property (nonatomic, readwrite, nonnull, strong) NSString *name;
@property (nonatomic, readwrite, nullable, strong) NSNumber *size;
@property (nonatomic, readwrite, assign) BOOL isDirectory;
@property (nonatomic, readwrite, nullable, strong) NSDate *modificationDate;
@property (nonatomic, readwrite, nullable, strong) NSDate *lastAccess;
@property (nonatomic, readwrite, assign) unsigned long ownerUID;
@property (nonatomic, readwrite, assign) unsigned long ownerGID;
@property (nonatomic, readwrite, nonnull, strong) NSString *permissionDescription;

@end

@implementation NSRemoteFile

- (instancetype)initWithFilename:(NSString *)filename {
    self = [super init];
    if (self) {
        _name = filename;
        _size = @(0);
        _isDirectory = NO;
        _modificationDate = [[NSDate alloc] init];
        _lastAccess = [[NSDate alloc] init];
        _ownerUID = 0;
        _ownerGID = 0;
        _permissionDescription = @"";
    }
    return self;
}

- (void)populateAttributes:(LIBSSH2_SFTP_ATTRIBUTES)fileAttributes {
    self.modificationDate = [NSDate dateWithTimeIntervalSince1970:fileAttributes.mtime];
    self.lastAccess = [NSDate dateWithTimeIntervalSinceNow:fileAttributes.atime];
    self.size = @(fileAttributes.filesize);
    self.ownerUID = fileAttributes.uid;
    self.ownerGID = fileAttributes.gid;
    self.permissionDescription = [self permissionDescriptionForMode:fileAttributes.permissions];
    self.isDirectory = LIBSSH2_SFTP_S_ISDIR(fileAttributes.permissions);
}

- (NSString *)permissionDescriptionForMode:(unsigned long)mode {
    static char *rwx[] = {"---", "--x", "-w-", "-wx", "r--", "r-x", "rw-", "rwx"};
    char bits[11];
    memset(bits, 0, sizeof(bits));
    bits[0] = [self fileTypeLetterForMode:mode];
    strcpy(&bits[1], rwx[(mode >> 6)& 7]);
    strcpy(&bits[4], rwx[(mode >> 3)& 7]);
    strcpy(&bits[7], rwx[(mode & 7)]);
    if (mode & S_ISUID) { bits[3] = (mode & 0100) ? 's' : 'S'; }
    if (mode & S_ISGID) { bits[6] = (mode & 0010) ? 's' : 'l'; }
    if (mode & S_ISVTX) { bits[9] = (mode & 0100) ? 't' : 'T'; }
    return [NSString stringWithCString:bits encoding:NSUTF8StringEncoding];
}

- (char)fileTypeLetterForMode:(unsigned long)mode {
    char c;
    if (S_ISREG(mode)) { c = '-'; }
    else if (S_ISDIR(mode)) { c = 'd'; }
    else if (S_ISBLK(mode)) { c = 'b'; }
    else if (S_ISCHR(mode)) { c = 'c'; }
    else if (S_ISFIFO(mode)) { c = 'p'; }
    else if (S_ISLNK(mode)) { c = 'l'; }
    else if (S_ISSOCK(mode)) { c = 's'; }
    else { c = '?'; } // you have problem not me
    return c;
}

@end
