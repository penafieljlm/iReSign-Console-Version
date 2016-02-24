//
//  main.h
//  resign
//
//  Created by John Lawrence M. Penafiel on 2/6/16.
//  Copyright © 2016 Hewlett Packard Enterprise. All rights reserved.
//

#if __has_feature(objc_arc)
#define MDLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__]);
#else
#define MDLog(format, ...) CFShow([NSString stringWithFormat:format, ## __VA_ARGS__]);
#endif
