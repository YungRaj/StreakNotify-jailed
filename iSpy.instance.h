#ifndef __ISPY_INSTANCE__
#define __ISPY_INSTANCE__

// This is used to track the metadata about instantiated objects.
typedef struct {
	void *addr;
	void *isa;
	const char *name;
} TrackerObject_t;

// hash map to track each object
typedef std::tr1::unordered_map<unsigned int, TrackerObject_t *> InstanceMap_t;

@interface InstanceTracker : NSObject {
	@public
		BOOL enabled;
		InstanceMap_t *instanceMap;
}

-(void) start; // implies a call to -[InstanceTracker clear]
-(void) stop;
-(void) clear;
-(NSArray *) instancesOfAllClasses;  
-(NSArray *) instancesOfAppClasses;
-(id)instanceAtAddress:(NSString *)addr; 

// Don't call these
-(id)__instanceAtAddress:(NSString *)addr;
-(NSArray *)__dumpInstance:(id)instance;
@end

#endif // __ISPY_INSTANCE__
