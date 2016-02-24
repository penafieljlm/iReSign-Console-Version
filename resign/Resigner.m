#import "main.h"
#import "Resigner.h"

static NSString *kKeyPrefsBundleIDChange            = @"keyBundleIDChange";

static NSString *kKeyBundleIDPlistApp               = @"CFBundleIdentifier";
static NSString *kKeyBundleIDPlistiTunesArtwork     = @"softwareVersionBundleId";
static NSString *kKeyInfoPlistApplicationProperties = @"ApplicationProperties";
static NSString *kKeyInfoPlistApplicationPath       = @"ApplicationPath";
static NSString *kFrameworksDirName                 = @"Frameworks";
static NSString *kPayloadDirName                    = @"Payload";
static NSString *kProductsDirName                   = @"Products";
static NSString *kInfoPlistFilename                 = @"Info.plist";
static NSString *kiTunesMetadataFileName            = @"iTunesMetadata";

@implementation Resigner

@synthesize workingPath;

- (id)initWithPath:(NSString *)path andProvision:(NSString *)provision andEntitlements:(NSString *)entitlements andCertificate:(NSString *)certificate andBundleID:(NSString *)bundleID {
    self = [super init];
    if(self) {
        
        self.pathValue = (path) ? path : @"";
        self.provisionValue = (provision) ? provision : @"";
        self.entitlementsValue = (entitlements) ? entitlements : @"";
        self.certifcateValue = certificate;
        self.bundleIDValue = bundleID;
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"]) {
            MDLog(@"Error: This app cannot run without the zip utility present at /usr/bin/zip");
            exit(1);
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"]) {
            MDLog(@"Error: This app cannot run without the unzip utility present at /usr/bin/unzip");
            exit(1);
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"]) {
            MDLog(@"Error: This app cannot run without the codesign utility present at /usr/bin/codesign");
            exit(1);
        }
    }
    return self;
}


- (void)resign {
    codesigningResult = nil;
    verificationResult = nil;
    
    sourcePath = self.pathValue;
    workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.appulize.iresign"];
    
    if (self.certifcateValue) {
        if (([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) ||
            ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"xcarchive"])) {
            
            MDLog(@"Setting up working directory in %@",workingPath);
            
            [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
            
            [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:TRUE attributes:nil error:nil];
            
            if ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
                if (sourcePath && [sourcePath length] > 0) {
                    MDLog(@"Unzipping %@",sourcePath);
                }
                
                unzipTask = [[NSTask alloc] init];
                [unzipTask setLaunchPath:@"/usr/bin/unzip"];
                [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", sourcePath, @"-d", workingPath, nil]];
                
                [unzipTask launch];
                [unzipTask waitUntilExit];
                
                [self checkUnzip];
            }
            else {
                NSString* payloadPath = [workingPath stringByAppendingPathComponent:kPayloadDirName];
                
                MDLog(@"Setting up %@ path in %@", kPayloadDirName, payloadPath);
                
                [[NSFileManager defaultManager] createDirectoryAtPath:payloadPath withIntermediateDirectories:TRUE attributes:nil error:nil];
                
                MDLog(@"Retrieving %@", kInfoPlistFilename);
                NSString* infoPListPath = [sourcePath stringByAppendingPathComponent:kInfoPlistFilename];
                
                NSDictionary* infoPListDict = [NSDictionary dictionaryWithContentsOfFile:infoPListPath];
                
                if (infoPListDict != nil) {
                    NSString* applicationPath = nil;
                    
                    NSDictionary* applicationPropertiesDict = [infoPListDict objectForKey:kKeyInfoPlistApplicationProperties];
                    
                    if (applicationPropertiesDict != nil) {
                        applicationPath = [applicationPropertiesDict objectForKey:kKeyInfoPlistApplicationPath];
                    }
                    
                    if (applicationPath != nil) {
                        applicationPath = [[sourcePath stringByAppendingPathComponent:kProductsDirName] stringByAppendingPathComponent:applicationPath];
                        
                        MDLog(@"Copying %@ to %@ path in %@", applicationPath, kPayloadDirName, payloadPath);
                        
                        copyTask = [[NSTask alloc] init];
                        [copyTask setLaunchPath:@"/bin/cp"];
                        [copyTask setArguments:[NSArray arrayWithObjects:@"-r", applicationPath, payloadPath, nil]];
                        
                        [copyTask launch];
                        [copyTask waitUntilExit];
                        
                        [self checkCopy];
                    }
                    else {
                        MDLog(@"Error: Unable to parse %@", kInfoPlistFilename);
                        exit(1);
                    }
                }
                else {
                    MDLog(@"Error: Retrieve %@ failed", kInfoPlistFilename);
                    exit(1);
                }
            }
        }
        else {
            MDLog(@"Error: You must choose an *.ipa or *.xcarchive file");
            exit(1);
        }
    } else {
        MDLog(@"Error: You must choose an signing certificate from dropdown.");
        exit(1);
    }
}

- (void)checkUnzip {
    if ([unzipTask isRunning] == 0) {
        unzipTask = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName]]) {
            MDLog(@"Unzipping done");
            
            if (self.bundleIDValue) {
                [self doBundleIDChange:self.bundleIDValue];
            }
            
            if ([self.provisionValue isEqualTo:@""]) {
                [self doCodeSigning];
            } else {
                [self doProvisioning];
            }
        } else {
            MDLog(@"Error: Unzip failed");
            exit(1);
        }
    }
}

- (void)checkCopy {
    if ([copyTask isRunning] == 0) {
        copyTask = nil;
        
        MDLog(@"Copy done");
        
        if (self.bundleIDValue) {
            [self doBundleIDChange:self.bundleIDValue];
        }
        
        if ([self.provisionValue isEqualTo:@""]) {
            [self doCodeSigning];
        } else {
            [self doProvisioning];
        }
    }
}

- (BOOL)doBundleIDChange:(NSString *)newBundleID {
    BOOL success = YES;
    
    success &= [self doAppBundleIDChange:newBundleID];
    success &= [self doITunesMetadataBundleIDChange:newBundleID];
    
    return success;
}


- (BOOL)doITunesMetadataBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingPath error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            infoPlistPath = [workingPath stringByAppendingPathComponent:file];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistiTunesArtwork newBundleID:newBundleID plistOutOptions:NSPropertyListXMLFormat_v1_0];
    
}

- (BOOL)doAppBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            infoPlistPath = [[[workingPath stringByAppendingPathComponent:kPayloadDirName]
                              stringByAppendingPathComponent:file]
                             stringByAppendingPathComponent:kInfoPlistFilename];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:newBundleID plistOutOptions:NSPropertyListBinaryFormat_v1_0];
}

- (BOOL)changeBundleIDForFile:(NSString *)filePath bundleIDKey:(NSString *)bundleIDKey newBundleID:(NSString *)newBundleID plistOutOptions:(NSPropertyListWriteOptions)options {
    
    NSMutableDictionary *plist = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        plist = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        [plist setObject:newBundleID forKey:bundleIDKey];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:options options:kCFPropertyListImmutable error:nil];
        
        return [xmlData writeToFile:filePath atomically:YES];
        
    }
    
    return NO;
}


- (void)doProvisioning {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                MDLog(@"Found embedded.mobileprovision, deleting.");
                [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] error:nil];
            }
            break;
        }
    }
    
    NSString *targetPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    
    provisioningTask = [[NSTask alloc] init];
    [provisioningTask setLaunchPath:@"/bin/cp"];
    [provisioningTask setArguments:[NSArray arrayWithObjects:self.provisionValue, targetPath, nil]];
    
    [provisioningTask launch];
    [provisioningTask waitUntilExit];
    
    [self checkProvisioning];
}

- (void)checkProvisioning {
    if ([provisioningTask isRunning] == 0) {
        provisioningTask = nil;
        
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
        
        for (NSString *file in dirContents) {
            if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
                if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                    
                    BOOL identifierOK = FALSE;
                    NSString *identifierInProvisioning = @"";
                    
                    NSString *embeddedProvisioning = [NSString stringWithContentsOfFile:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] encoding:NSASCIIStringEncoding error:nil];
                    NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet:
                                                          [NSCharacterSet newlineCharacterSet]];
                    
                    for (int i = 0; i < [embeddedProvisioningLines count]; i++) {
                        if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound) {
                            
                            NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
                            
                            NSInteger toPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
                            
                            NSRange range;
                            range.location = fromPosition;
                            range.length = toPosition-fromPosition;
                            
                            NSString *fullIdentifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
                            
                            NSArray *identifierComponents = [fullIdentifier componentsSeparatedByString:@"."];
                            
                            if ([[identifierComponents lastObject] isEqualTo:@"*"]) {
                                identifierOK = TRUE;
                            }
                            
                            for (int i = 1; i < [identifierComponents count]; i++) {
                                identifierInProvisioning = [identifierInProvisioning stringByAppendingString:[identifierComponents objectAtIndex:i]];
                                if (i < [identifierComponents count]-1) {
                                    identifierInProvisioning = [identifierInProvisioning stringByAppendingString:@"."];
                                }
                            }
                            break;
                        }
                    }
                    
                    MDLog(@"Mobileprovision identifier: %@",identifierInProvisioning);
                    
                    NSDictionary *infoplist = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
                    if ([identifierInProvisioning isEqualTo:[infoplist objectForKey:kKeyBundleIDPlistApp]]) {
                        MDLog(@"Identifiers match");
                        identifierOK = TRUE;
                    }
                    
                    if (identifierOK) {
                        MDLog(@"Provisioning completed.");
                        [self doEntitlementsFixing];
                    } else {
                        MDLog(@"Error: Product identifiers don't match");
                        exit(1);
                    }
                } else {
                    MDLog(@"Error: Provisioning failed");
                    exit(1);
                }
                break;
            }
        }
    }
}

- (void)doEntitlementsFixing
{
    if (![self.entitlementsValue isEqualToString:@""] || [self.provisionValue isEqualToString:@""]) {
        [self doCodeSigning];
        return; // Using a pre-made entitlements file or we're not re-provisioning.
    }
    
    MDLog(@"Generating entitlements");
    
    if (appPath) {
        generateEntitlementsTask = [[NSTask alloc] init];
        [generateEntitlementsTask setLaunchPath:@"/usr/bin/security"];
        [generateEntitlementsTask setArguments:@[@"cms", @"-D", @"-i", self.provisionValue]];
        [generateEntitlementsTask setCurrentDirectoryPath:workingPath];
        
        NSPipe *pipe=[NSPipe pipe];
        [generateEntitlementsTask setStandardOutput:pipe];
        [generateEntitlementsTask setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];
        
        [generateEntitlementsTask launch];
        [generateEntitlementsTask waitUntilExit];
        
        entitlementsResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        
        [self checkEntitlementsFix];
    }
}

- (void)checkEntitlementsFix {
    if ([generateEntitlementsTask isRunning] == 0) {
        generateEntitlementsTask = nil;
        MDLog(@"Entitlements fixed done");
        [self doEntitlementsEdit];
    }
}

- (void)doEntitlementsEdit
{
    NSDictionary* entitlements = entitlementsResult.propertyList;
    entitlements = entitlements[@"Entitlements"];
    NSString* filePath = [workingPath stringByAppendingPathComponent:@"entitlements.plist"];
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlements format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
    if(![xmlData writeToFile:filePath atomically:YES]) {
        MDLog(@"Error writing entitlements file.");
        exit(1);
    }
    else {
        self.entitlementsValue = filePath;
        [self doCodeSigning];
    }
}

- (void)doCodeSigning {
    appPath = nil;
    frameworksDirPath = nil;
    hasFrameworks = NO;
    frameworks = [[NSMutableArray alloc] init];
    
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            frameworksDirPath = [appPath stringByAppendingPathComponent:kFrameworksDirName];
            MDLog(@"Found %@",appPath);
            appName = file;
            if ([[NSFileManager defaultManager] fileExistsAtPath:frameworksDirPath]) {
                MDLog(@"Found %@",frameworksDirPath);
                hasFrameworks = YES;
                NSArray *frameworksContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:frameworksDirPath error:nil];
                for (NSString *frameworkFile in frameworksContents) {
                    NSString *extension = [[frameworkFile pathExtension] lowercaseString];
                    if ([extension isEqualTo:@"framework"] || [extension isEqualTo:@"dylib"]) {
                        frameworkPath = [frameworksDirPath stringByAppendingPathComponent:frameworkFile];
                        MDLog(@"Found %@",frameworkPath);
                        [frameworks addObject:frameworkPath];
                    }
                }
            }
            MDLog(@"Codesigning %@",file);
            break;
        }
    }
    
    if (appPath) {
        if (hasFrameworks) {
            [self signFile:[frameworks lastObject]];
            [frameworks removeLastObject];
        } else {
            [self signFile:appPath];
        }
    }
}

- (void)signFile:(NSString*)filePath {
    MDLog(@"Codesigning %@", filePath);
    
    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-fs", self.certifcateValue, nil];
    NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    NSString * systemVersion = [systemVersionDictionary objectForKey:@"ProductVersion"];
    NSArray * version = [systemVersion componentsSeparatedByString:@"."];
    if ([version[0] intValue]<10 || ([version[0] intValue]==10 && ([version[1] intValue]<9 || ([version[1] intValue]==9 && [version[2] intValue]<5)))) {
        
        /*
         Before OSX 10.9, code signing requires a version 1 signature.
         The resource envelope is necessary.
         To ensure it is added, append the resource flag to the arguments.
         */
        
        NSString *resourceRulesPath = [[NSBundle mainBundle] pathForResource:@"ResourceRules" ofType:@"plist"];
        NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
        [arguments addObject:resourceRulesArgument];
    } else {
        
        /*
         For OSX 10.9 and later, code signing requires a version 2 signature.
         The resource envelope is obsolete.
         To ensure it is ignored, remove the resource key from the Info.plist file.
         */
        
        NSString *infoPath = [NSString stringWithFormat:@"%@/Info.plist", filePath];
        NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
        [infoDict removeObjectForKey:@"CFBundleResourceSpecification"];
        [infoDict writeToFile:infoPath atomically:YES];
        [arguments addObject:@"--no-strict"]; // http://stackoverflow.com/a/26204757
    }
    
    if (![self.entitlementsValue isEqualToString:@""]) {
        [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@", self.entitlementsValue]];
    }
    
    [arguments addObjectsFromArray:[NSArray arrayWithObjects:filePath, nil]];
    
    codesignTask = [[NSTask alloc] init];
    [codesignTask setLaunchPath:@"/usr/bin/codesign"];
    [codesignTask setArguments:arguments];
    
    NSPipe *pipe=[NSPipe pipe];
    [codesignTask setStandardOutput:pipe];
    [codesignTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [codesignTask launch];
    [codesignTask waitUntilExit];
 
    codesigningResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    
    [self checkCodesigning];
}

- (void)checkCodesigning {
    if ([codesignTask isRunning] == 0) {
        codesignTask = nil;
        if (frameworks.count > 0) {
            [self signFile:[frameworks lastObject]];
            [frameworks removeLastObject];
        } else if (hasFrameworks) {
            hasFrameworks = NO;
            [self signFile:appPath];
        } else {
            MDLog(@"Codesigning done");
            [self doVerifySignature];
        }
    }
}

- (void)doVerifySignature {
    if (appPath) {
        verifyTask = [[NSTask alloc] init];
        [verifyTask setLaunchPath:@"/usr/bin/codesign"];
        [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", appPath, nil]];
        
        MDLog(@"Verifying %@",appPath);
        
        NSPipe *pipe=[NSPipe pipe];
        [verifyTask setStandardOutput:pipe];
        [verifyTask setStandardError:pipe];
        NSFileHandle *handle=[pipe fileHandleForReading];
        
        [verifyTask launch];
        [verifyTask waitUntilExit];
        
        verificationResult = [[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        
        [self checkVerificationProcess];
    }
}

- (void)checkVerificationProcess {
    if ([verifyTask isRunning] == 0) {
        verifyTask = nil;
        if ([verificationResult length] == 0) {
            MDLog(@"Verification done");
            [self doZip];
        } else {
            NSString *error = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
            MDLog(@"Error: Signing failed %@", error);
            MDLog(@"Please try again");
            exit(1);
        }
    }
}

- (void)doZip {
    if (appPath) {
        NSArray *destinationPathComponents = [sourcePath pathComponents];
        NSString *destinationPath = @"";
        
        for (int i = 0; i < ([destinationPathComponents count]-1); i++) {
            destinationPath = [destinationPath stringByAppendingPathComponent:[destinationPathComponents objectAtIndex:i]];
        }
        
        fileName = [sourcePath lastPathComponent];
        fileName = [fileName substringToIndex:([fileName length] - ([[sourcePath pathExtension] length] + 1))];
        fileName = [fileName stringByAppendingString:@"-resigned"];
        fileName = [fileName stringByAppendingPathExtension:@"ipa"];
        
        destinationPath = [destinationPath stringByAppendingPathComponent:fileName];
        
        MDLog(@"Dest: %@",destinationPath);
        
        zipTask = [[NSTask alloc] init];
        [zipTask setLaunchPath:@"/usr/bin/zip"];
        [zipTask setCurrentDirectoryPath:workingPath];
        [zipTask setArguments:[NSArray arrayWithObjects:@"-qry", destinationPath, @".", nil]];
        
        MDLog(@"Zipping %@", destinationPath);
        
        [zipTask launch];
        [zipTask waitUntilExit];
        
        [self checkZip];
    }
}

- (void)checkZip {
    if ([zipTask isRunning] == 0) {
        zipTask = nil;
        MDLog(@"Zipping done");
        
        [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
        
        NSString *result = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
        MDLog(@"Codesigning result: %@",result);
    }
}

@end
