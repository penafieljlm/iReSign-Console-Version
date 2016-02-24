#import "main.h"

#import <libgen.h>
#import <Foundation/Foundation.h>

#import "Resigner.h"

NSString* abspath(NSString* path) {
    if(path == nil) return nil;
    if(![path hasPrefix:@"/"] && ![path hasPrefix:@"~/"]) {
        NSFileManager* manager = [[NSFileManager alloc] init];
        path = [NSString stringWithFormat:@"%@/%@", [manager currentDirectoryPath], path];
    }
    return path;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        // acquire program name
        NSString* program = [[NSString alloc] initWithCString:basename(argv[0]) encoding:NSUTF8StringEncoding];
        
        // calculate usage string
        NSString* usage = [NSString stringWithFormat:@"Usage: %@ [[-p|--provision] PROVISION] [[-e|--entitlements] ENTITLEMENTS] [[-i|--bundleid] BUNDLEID] PATH CERTIFICATE", program];
        
        // validate parameter counts
        if(argc != 3 && argc != 5 && argc != 7 && argc != 9) {
            MDLog(@"%@", usage);
            exit(1);
        }
        
        // declare temporary buffers
        NSString* buffer = nil;
        NSInteger index = argc;
        
        // acquire certificate parameter
        NSString* certificate = nil;
        index = argc-1;
        if(index-1 >= 1) {
            buffer = [[NSString alloc] initWithCString:argv[index-1] encoding:NSUTF8StringEncoding];
            if([buffer isEqualTo:@"-p"] || [buffer isEqualTo:@"--provision"] ||
               [buffer isEqualTo:@"-e"] || [buffer isEqualTo:@"--entitlements"] ||
               [buffer isEqualTo:@"-i"] || [buffer isEqualTo:@"--bundleid"]) {
                MDLog(@"%@", usage);
                exit(1);
            }
        }
        buffer = [[NSString alloc] initWithCString:argv[index] encoding:NSUTF8StringEncoding];
        certificate = buffer;
        
        // acquire target path parameter
        NSString* path = nil;
        index = argc-2;
        if(index-1 >= 1) {
            buffer = [[NSString alloc] initWithCString:argv[index-1] encoding:NSUTF8StringEncoding];
            if([buffer isEqualTo:@"-p"] || [buffer isEqualTo:@"--provision"] ||
               [buffer isEqualTo:@"-e"] || [buffer isEqualTo:@"--entitlements"] ||
               [buffer isEqualTo:@"-i"] || [buffer isEqualTo:@"--bundleid"]) {
                MDLog(@"%@", usage);
                exit(1);
            }
        }
        buffer = [[NSString alloc] initWithCString:argv[index] encoding:NSUTF8StringEncoding];
        path = buffer;
        
        // acquire other optional parameters
        NSString* provision = nil;
        NSString* entitlements = nil;
        NSString* bundleid = nil;
        if(argc > 3) {
            for(int i = 1 ; (i + 1) <= (argc - 3) ; i += 2) {
                NSString* key = [[NSString alloc] initWithCString:argv[i] encoding:NSUTF8StringEncoding];
                NSString* value = [[NSString alloc] initWithCString:argv[i+1] encoding:NSUTF8StringEncoding];
                if([key isEqualTo:@"-p"] || [key isEqualTo:@"--provision"]) {
                    provision = value;
                    continue;
                }
                if([key isEqualTo:@"-e"] || [key isEqualTo:@"--entitlements"]) {
                    entitlements = value;
                    continue;
                }
                if([key isEqualTo:@"-i"] || [key isEqualTo:@"--bundleid"]) {
                    bundleid = value;
                    continue;
                }
                MDLog(@"%@", usage);
                exit(1);
            }
        }
        
        // make paths absolute
        path = abspath(path);
        provision = abspath(provision);
        entitlements = abspath(entitlements);
        
        // perform actual resign process
        Resigner* state = [[Resigner alloc] initWithPath:path andProvision:provision andEntitlements:entitlements andCertificate:certificate andBundleID:bundleid];
        [state resign];
    }
    return 0;
}