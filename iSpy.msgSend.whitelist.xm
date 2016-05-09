#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.msgSend.whitelist.h"
#include <iostream>
#include <string>
#include <vector>
#include <memory>

// This is work in progress, don't use it
struct interestingCall interestingCalls[] = {
    /*
    {
        // Field meanings:

        "Classification of interesting call",
        "Name of class to trigger on",
        "Name of method to trigger on",
        "Provide a description that will be sent to the iSpy UI",
        "Provide a risk rating",
        one of: INTERESTING_CALL or INTERESTING_BREAKPOINT
    }
    */
    // Data Storage
    { 
        "Data Storage",
        "NSManagedObjectContext", 
        "save", 
        "Core Data uses unencrypted SQLite databases. Sensitive information should not be stored here.", 
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSDictionary",
        "writeToFile",
        "Sensitive data should not be saved in this manner.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSUserDefaults",
        "init",
        "Sensitive data should not be saved using NSUserDefaults.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSURLCache",
        "initWithMemoryCapacity:diskCapacity:diskPath:",
        "Sensitive SSL-encrypted data may be stored in the clear using NSURLCache.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSURLCache",
        "storeCachedResponse:forRequest:",
        "Sensitive SSL-encrypted data may be stored in the clear using NSURLCache.",
        "Medium",
        INTERESTING_CALL
    },
    {
        "Data Storage",
        "NSURLCache",
        "setDiskCapacity:",
        "Sensitive SSL-encrypted data may be stored in the clear using NSURLCache.",
        "Medium",
        INTERESTING_CALL
    },
    

    // Breakpoints
    /*
    {
        "TEST",                         // must be present, value unimportant
        "RealTimeDataViewController",   // class
        "showLoadingView",              // method
        "",
        "",
        INTERESTING_BREAKPOINT          // must be present
    },
    */
    { NULL }
};

extern void whitelist_add_method(std::string *className, std::string *methodName, unsigned int type) {
    ClassMap_t *ClassMap = [[iSpy sharedInstance] classWhitelist];
    (*ClassMap)[*className][*methodName] = type;
}

extern void whitelist_remove_method(std::string *className, std::string *methodName) {
    ClassMap_t *ClassMap = [[iSpy sharedInstance] classWhitelist];
    ispy_nslog("[whitelist remove] Whitelist ptr @ %p", &(*ClassMap));
    (*ClassMap)[*className].erase(*methodName);
}

extern void whitelist_remove_class(std::string *className) {
    ClassMap_t *ClassMap = [[iSpy sharedInstance] classWhitelist];
    ClassMap_t::iterator c_it = (*ClassMap).find(*className);
    
    ispy_nslog("[whitelist remove class] Whitelist ptr @ %p", &(*ClassMap));
    if(c_it == ([[iSpy sharedInstance] classWhitelist])->end()) {
        ispy_nslog("[whitelist remove class] The class %s is not on the whitelist", className->c_str());
    }
    else {
        ispy_nslog("[whitelist remove class] The class %s is on the whitelist, removing.", className->c_str());
        ClassMap->erase(c_it);
    }
}

extern void whitelist_startup() {
    ispy_nslog("[whitelist_startup] Startup.");
    // Use a static buffer because shoving the hashmap onto the BSS prevented a crash I was having storing it elsewhere.
    // XXX Should probably debug/fix this sometime.
    static std::tr1::unordered_map<std::string, std::tr1::unordered_map<std::string, unsigned int> > WhitelistClassMap;
    static BreakpointMap_t Breakpoints;
    
    // So here we're setting a pointer property of the iSpy object to point at a local static variable.
    // This is is crazy and should be properly stored in the class singleton. See XXX above.
    ispy_nslog("[Whitelist_startup] Initializing whitelist pointer");
    ispy_nslog("[whitelist_startup] Calling sharedInstance");
    [[iSpy sharedInstance] setClassWhitelist:&WhitelistClassMap];
    ispy_nslog("[Whitelist_startup] Whitelist ptr @ %p.", [[iSpy sharedInstance] classWhitelist]);
    
    ispy_nslog("[Whitelist_startup] Breakpoints.");
    ispy_nslog("[whitelist_startup] Calling sharedInstance");
    [iSpy sharedInstance]->breakpoints = &Breakpoints;
    
    ispy_nslog("[Whitelist_startup] Done.");
}

// Hard-coded interesting calls are defined above as an example of one way to focus on particular
// functions.
extern void whitelist_add_hardcoded_interesting_calls() {
    ispy_log("[whitelist_add_hardcoded_interesting_calls] Initializing the interesting functions");
    struct interestingCall *call = interestingCalls;

    while(call->classification) {
        ispy_nslog("call = %p", call);
        std::string tmpClsName = std::string(call->className);
        std::string tmpMthName = std::string(call->methodName);
        whitelist_add_method(&tmpClsName, &tmpMthName, (unsigned int)call);
        call++;
    }
}

extern void whitelist_clear_whitelist() {
    ispy_log("[whitelist_clear_whitelist] Clearning the whitelist");
    ([[iSpy sharedInstance] classWhitelist])->clear();
}

// add all of the classes and methods defined in the application to the objc_msgSend logging whitelist.
void whitelist_add_app_classes() {
    int i, numClasses, m, numMethods;

    // Get a list of all the classes in the app
    NSArray *classes = [[iSpy sharedInstance] classes];
	numClasses = [classes count];
    
    ispy_nslog("[whitelist_add_app_classes] adding %d classes...", numClasses);

    // Iterate through all the class names, adding each one to our lookup table
    for(i = 0; i < numClasses; i++) {
    	NSString *name = [classes objectAtIndex:i];
    	if(!name) {
    		continue;
    	}

        if([name isEqualToString:@"iSpy"]) {
            continue;
        }

    	NSArray *methods = [[iSpy sharedInstance] methodListForClass:name];
    	if(!methods) {
    		continue;
    	}

    	numMethods = [methods count];
    	if(!numMethods) {
    		[methods release];
    		[name release];
    		continue;
    	}

    	for(m = 0; m < numMethods; m++) {
    		NSString *methodName = [methods objectAtIndex:m];
    		if(!methodName) {
    			continue;
    		}
    		std::string *classNameString = new std::string([name UTF8String]);
    		std::string *methodNameString = new std::string([methodName UTF8String]);
    		if(!classNameString || !methodNameString) {
    			if(methodNameString)
    				delete methodNameString;
    			if(classNameString)
    				delete classNameString;
    			continue;
    		}
    		//ispy_nslog("[Whitelist adding [%s %s]", classNameString->c_str(), methodNameString->c_str());
            whitelist_add_method(classNameString, methodNameString, WHITELIST_PRESENT);
    		delete methodNameString;
    		delete classNameString;
    	}
    	[name release];
    	[methods release];
    }
    [classes release];

    ispy_log("[whitelist_add_app_classes] Added %d of %d classes to the whitelist.", i, numClasses);   
}

