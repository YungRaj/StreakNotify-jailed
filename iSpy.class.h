#ifndef ___ISPY_DEFINED___
#include "iSpy.msgSend.whitelist.h"
#include "iSpy.instance.h"

#define MAX_BREAKPOINTS 256

struct bf_objc_class {
    Class isa;
    Class super_class;
    const char *name;
    long version;
    long info;
    long instance_size;
    struct objc_ivar_list *ivars;
    struct objc_method_list **methodLists;
    struct objc_cache *cache;
    struct objc_protocol_list *protocols;                     
};

/*
    Adds a nice "containsString" method to NSString
*/
@interface NSString (iSpy)
{

}
-(BOOL) containsString:(NSString*)substring;
@end

/*
	Functionality that's exposed to Cycript.
*/
@interface iSpy : NSObject {
	@public
		BreakpointMap_t *breakpoints; // super experimental. Aka: broken, poorly designed, and shittily implemented.
		ClassMap_t *_classWhitelist;
		NSString *appName;
}
@property (assign) char *bundle;
@property (assign) NSString *bundleId;
@property (assign) NSString *appPath;
@property (assign) NSMutableDictionary *msgSendWhitelist;
@property (assign) InstanceTracker *instanceTracker;
@property (assign) BOOL SSLPinningBypass;

+(iSpy *)sharedInstance;
-(void)initializeAllTheThings;
-(NSDictionary *) getNetworkInfo;
-(NSDictionary *) keyChainItems;
-(NSDictionary *) infoForMethod:(SEL)selector inClass:(Class)cls;
-(NSDictionary *) infoForMethod:(SEL)selector inClass:(Class)cls isInstanceMethod:(BOOL)isInstance;
-(NSArray *) iVarsForClass:(NSString *)className;
-(NSArray *) propertiesForClass:(NSString *)className;
-(NSArray *) methodsForClass:(NSString *)className;
-(NSArray *) protocolsForClass:(NSString *)className;
-(NSArray *) methodListForClass:(NSString *)className;
-(NSArray *) classes;
-(NSArray *) classesWithSuperClassAndProtocolInfo;
-(NSArray *) propertiesForProtocol:(Protocol *)protocol;
-(NSArray *) methodsForProtocol:(Protocol *)protocol;
-(NSDictionary *) protocolDump;
-(NSDictionary *) classDump;
-(NSDictionary *) classDumpClass:(NSString *)className;
-(NSString *) msgSend_whitelistAddClass:(NSString *) className;
-(NSString *) msgSend_whitelistAddMethod:(NSString *)methodName forClass:(NSString *)className;
-(NSString *) _msgSend_whitelistAddMethod:(NSString *)methodName forClass:(NSString *)className ofType:(struct interestingCall *)call;
-(NSString *) msgSend_addAppClassesToWhitelist;
-(NSString *) msgSend_whitelistRemoveClass:(NSString *)className;
-(NSString *) msgSend_whitelistRemoveMethod:(NSString *)methodName fromClass:(NSString *)className;
-(NSString *) msgSend_releaseBreakpointForMethod:(NSString *)methodName inClass:(NSString *)className;
-(NSString *) msgSend_clearWhitelist;
+(BOOL) isClassFromApp:(NSString *)className;
+(BOOL)isClassFromApp_str:(const char *)className;
-(ClassMap_t *) classWhitelist;
-(unsigned int) ASLR;
-(void) msgSend_enableLogging;
-(void) msgSend_disableLogging;
-(void) setClassWhitelist:(ClassMap_t *)classMap;
-(void) SSLPinning_disableBypass;
-(void) SSLPinning_enableBypass;
-(void *(*)(id, SEL, ...)) swizzleSelector:(SEL)originalSelector withFunction:(IMP)function forClass:(id)cls isInstanceMethod:(BOOL)isInstance;
@end


/*
	Helper functions.
*/

char *bf_get_type_from_signature(char *typeStr);
extern "C" int is_valid_pointer(void *ptr);

#else
#define ___ISPY_DEFINED___
#endif
