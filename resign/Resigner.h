#import <Cocoa/Cocoa.h>

@interface Resigner : NSObject {
@private
    
    NSTask* unzipTask;
    NSTask* copyTask;
    NSTask* provisioningTask;
    NSTask* codesignTask;
    NSTask* generateEntitlementsTask;
    NSTask* verifyTask;
    NSTask* zipTask;
    NSString* sourcePath;
    NSString* appPath;
    NSString* frameworksDirPath;
    NSString* frameworkPath;
    NSString* workingPath;
    NSString* appName;
    NSString* fileName;
    
    NSString* entitlementsResult;
    NSString* codesigningResult;
    NSString* verificationResult;
    
    NSMutableArray* frameworks;
    Boolean hasFrameworks;
    
}

@property (nonatomic, strong) NSString* workingPath;

@property (nonatomic, strong) NSString* pathValue;
@property (nonatomic, strong) NSString* provisionValue;
@property (nonatomic, strong) NSString* entitlementsValue;
@property (nonatomic, strong) NSString* certifcateValue;
@property (nonatomic, strong) NSString* bundleIDValue;

- (id)initWithPath:(NSString*)path andProvision:(NSString*)provision andEntitlements:(NSString*)entitlements andCertificate:(NSString*)certificate andBundleID:(NSString*)bundleID;

- (void)resign;

- (void)checkUnzip;
- (void)checkCopy;
- (void)doProvisioning;
- (void)checkProvisioning;
- (void)doCodeSigning;
- (void)checkCodesigning;
- (void)doVerifySignature;
- (void)checkVerificationProcess;
- (void)doZip;
- (void)checkZip;

@end
