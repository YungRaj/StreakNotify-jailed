#import <dlfcn.h>
#include <pthread.h>
#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.instance.h"
#include "fishhook/fishhook.h"

/*
	Features:
		Tracks objects instantiated/destroyed
		Allows dumping of instantiated App objects
		Allows dumping of ALL objects
		Enable/disable tracking.

	Proposed features:
		Dump JSON blob of objects
		Search objects for strings/bytes
		Alerting/trigger when a specific type of object is created
			Fire callback with a pointer to the trigger object

*/

static pthread_mutex_t mutex_instance = PTHREAD_MUTEX_INITIALIZER;
static InstanceTracker *trackerPtr = NULL;

@implementation InstanceTracker

-(id)init {
	static InstanceMap_t instanceMapStatic;

	NSLog(@"[iSpy tracker] Init starting with self @ %p", self);

	if(!self)
		self = [super init];

	self->enabled = FALSE; //[self setEnabled:false];
	self->instanceMap = &instanceMapStatic; //[self setInstanceMap:&instanceMap];
	trackerPtr = self;	
	
	NSLog(@"[iSpy tracker] Init finished with self @ %p", self);
	return self;
}

-(void) start {
	ispy_nslog("[iSpy tracker] Starting!");
	[self clear];
	self->enabled = TRUE;
}

-(void) stop {
	ispy_nslog("[iSpy tracker] Stopping!");
	self->enabled = FALSE;
}

-(void) clear {
	InstanceMap_t *instanceMapPtr = self->instanceMap;
	(*instanceMapPtr).clear();
}

-(NSArray *) instancesOfAllClasses {
	InstanceMap_t *instanceMapPtr = trackerPtr->instanceMap;
	NSMutableArray *instances = [[NSMutableArray alloc] init];

	for(InstanceMap_t::const_iterator it = (*instanceMapPtr).begin(); it != (*instanceMapPtr).end(); ++it) {
		[instances addObject:[NSString stringWithFormat:@"%p", it->second]];
	}

	return (NSArray *)instances;
}

/*
	We CANNOT use anything in here that calls alloc or dealloc.
	This is because we will race with the hooked alloc/dealloc methods.
	All of this means that you can't do: FooClass *foo = [[FooClass alloc] init];
	Instead force everything through objc_msgSend. Woo, fun.
*/
-(NSArray *) instancesOfAppClasses {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-objc-isa-usage"

	NSMutableArray *instances = objc_msgSend(objc_getClass("NSMutableArray"), @selector(alloc));
	instances = objc_msgSend(instances, @selector(init));

	pthread_mutex_lock(&mutex_instance);
	InstanceMap_t *instanceMapPtr = trackerPtr->instanceMap;

	for(InstanceMap_t::const_iterator it = (*instanceMapPtr).begin(); it != (*instanceMapPtr).end(); ++it) {
		if(is_valid_pointer(&it)) {
			TrackerObject_t *tObj = (TrackerObject_t *)it->second;
			if(is_valid_pointer((void *)tObj)) {
				if(is_valid_pointer(tObj->addr)) {
					struct bf_objc_class *theInstance = (bf_objc_class *)tObj->addr;
					if(theInstance->isa == tObj->isa) {
						NSString *str;
						if(!objc_msgSend(objc_getClass("iSpy"), @selector(isClassFromApp_str:), tObj->name))
							continue;
						str = objc_msgSend(objc_getClass("NSString"), @selector(stringWithFormat:), @"%s (%p)", tObj->name, tObj->addr);
						objc_msgSend(instances, @selector(addObject:), str);
					}
				}
			}
		}
	}
	pthread_mutex_unlock(&mutex_instance);
	return (NSArray *)instances;

#pragma clang diagnostic pop
}

// Given a hex address (eg. 0xdeafbeef) dumps the class data from the object at that address.
// Returns an object as discussed in instance_dumpInstance, below.
// This is exposed to /api/instance/0xdeadbeef << replace deadbeef with an actual address.
-(id)instanceAtAddress:(NSString *)addr {
	return [self __dumpInstance:[self __instanceAtAddress:addr]];
}

// Given a string in the format @"0xdeadbeef", this first converts the string to an address, then
// returns an opaque Objective-C object at that address.
// The runtime can treat this return value just like any other object.
// BEWARE: give this an incorrect/invalid address and you'll return a duff pointer. Caveat emptor.
-(id)__instanceAtAddress:(NSString *)addr {
	return (id)strtoul([addr UTF8String], (char **)NULL, 16);
}

// Make sure to pass a valid pointer (instance) to this method!
// In return it'll give you an array. Each element in the array represents an iVar and comprises a dictionary.
// Each element in the dictionary represents the name, type, and value of the iVar.
-(NSArray *)__dumpInstance:(id)instance {
	void *ptr;
	ispy_nslog("[__dumpInstance] Calling [iSpy sharedInstance]");
	NSArray *iVars = [[iSpy sharedInstance] iVarsForClass:[NSString stringWithUTF8String:object_getClassName(instance)]];
	int i;
	NSMutableArray *iVarData = [[NSMutableArray alloc] init];

	for(i=0; i< [iVars count]; i++) {
		NSDictionary *iVar = [iVars objectAtIndex:i];
		NSEnumerator *e = [iVar keyEnumerator];
		id key;

		while((key = [e nextObject])) {
			NSMutableDictionary *iVarInfo = [[NSMutableDictionary alloc] init];
			[iVarInfo setObject:key forKey:@"name"];

			object_getInstanceVariable(instance, [key UTF8String], &ptr );

			// Dumb check alert!
			// The logic goes like this. All parameter types have a style guide.
			// e.g. If the type of argument we're examining is an Objective-C class, the first letter of its name
			// will be a capital letter. We can dump these with ease using the Objective-C runtime.
			// Similarly, anything from the C world should have a lower case first letter.
			// Now, we can easily leverage the Objective-C runtime to dump class data. but....
			// The C environment ain't so easy. Easy stuff is booleans (just a "char") or ints.
			// Of course we could dump strings (char*) too, but we need to write code to handle that.
			// As iSpy matures we'll do just that. Meantime, you'll get (a) the type of the var you're looking at,
			// (b) a pointer to that var. Do as you please with it. BOOLs (really just chars) are already taken care of as an example
			// of how to deal with this shit.
			// TODO: there are better ways to do this. See obj_mgSend logging stuff. FIXME.
			char *type = (char *)[[iVar objectForKey:key] UTF8String];

			if(islower(*type)) {
				char *boolVal = (char *)ptr;
				if(strcmp(type, "char") == 0) {
					[iVarInfo setObject:@"BOOL" forKey:@"type"];
					[iVarInfo setObject:[NSString stringWithFormat:@"%d", (int)boolVal&0xff] forKey:@"value"];
				} else {
					[iVarInfo setObject:[iVar objectForKey:key] forKey:@"type"];
					[iVarInfo setObject:[NSString stringWithFormat:@"[%s] pointer @ %p", type, ptr] forKey:@"value"];
				}
			} else {
				// This is likely to be an Objective-C class. Hey, what's the worst that could happen if it's not?
				// That would be a segfault. Signal 11. Do not pass go, do not collect a stack trace.
				// This is a shady janky-ass mofo of a function.
				[iVarInfo setObject:[iVar objectForKey:key] forKey:@"type"];
				[iVarInfo setObject:[NSString stringWithFormat:@"%@", ptr] forKey:@"value"];
			}
			[iVarData addObject:iVarInfo];
			[iVarInfo release];
		}
	}

	return (NSArray *)[iVarData copy];
}
@end

/*
	We hook alloc and dealloc so that we can track object instantiation and destruction.
*/
%hook NSObject
-(void)dealloc {
	if(!trackerPtr->enabled) {
		%orig;
		return;
	}

	pthread_mutex_lock(&mutex_instance);	

	InstanceMap_t *instanceMapPtr = trackerPtr->instanceMap;
	InstanceMap_t::iterator it = (*instanceMapPtr).find((unsigned int)self);
    if(it == (*instanceMapPtr).end())
		goto outtaHere; // goto fail, mwahahaha
    free(it->second);
	(*instanceMapPtr).erase(it);

outtaHere:
	pthread_mutex_unlock(&mutex_instance);
	%orig;
}

+(id)alloc {
	id obj = %orig;
	if(!trackerPtr->enabled)
		return obj;

	pthread_mutex_lock(&mutex_instance);

	TrackerObject_t *tObj;
	tObj = (TrackerObject_t *)malloc(sizeof(TrackerObject_t)); // let's assume this works ;)
	tObj->isa = (void *)self;
	tObj->addr = (void *)obj;
	tObj->name = class_getName(self);
	InstanceMap_t *instanceMapPtr = trackerPtr->instanceMap; 
	(*instanceMapPtr)[(unsigned int)obj] = tObj;
	
	pthread_mutex_unlock(&mutex_instance);
	return obj;
}
%end

