#include "iSpy.common.h"
#include "iSpy.class.h"
#include "iSpy.instance.h"
#include "fishhook/fishhook.h"
#include <dlfcn.h>

#define AFSSLPinningModeNone 0

/*
	iSpy can bypass quite a few SSL pinning implementations. 
	Enable this feature by calling [[iSpy sharedInstance] SSLPinning_enableBypass];
	It's disabled by default.
*/


/*
	TrustMe SSL Bypass.
	This function is basically copy pasta from trustme: https://github.com/intrepidusgroup/trustme?source=cc
	It bypasses a lot of SSL pinning implementations.
*/
static OSStatus (*original_SecTrustEvaluate)(SecTrustRef trust, SecTrustResultType *result) = NULL;
static OSStatus new_SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
	ispy_nslog("[iSpy] Intercepting SecTrustEvaluate() call and faking a success result");
	*result = kSecTrustResultProceed;
	return errSecSuccess;
}

void hook_SecTrustEvaluate(BOOL enableBypass) {
	if(enableBypass == TRUE) {
		// Save a function pointer to the real SecTrustEvaluate() function
		original_SecTrustEvaluate = (OSStatus(*)(SecTrustRef trust, SecTrustResultType *result))dlsym(RTLD_DEFAULT, "SecTrustEvaluate");

		// Switch out SecTrustEvaluate for our own implementation
    	rebind_symbols((struct rebinding[1]){{(char *)"SecTrustEvaluate", (void *)new_SecTrustEvaluate}}, 1); 
	} else {
		// Restore the original SecTrustEvaluate
		if(original_SecTrustEvaluate != NULL) {
			rebind_symbols((struct rebinding[1]){{(char *)"SecTrustEvaluate", (void *)original_SecTrustEvaluate}}, 1); 
			original_SecTrustEvaluate = NULL;
		}
	}
}
	

/*
	Bishop Fox AFNetworking SSL Pinning bypass.
*/
%hook AFSecurityPolicy

+(id) defaultPolicy {
	if([[iSpy sharedInstance] SSLPinningBypass] == TRUE) {
		ispy_nslog("[iSpy] SSL pinning bypass (AFNetworking). Intercepting [AFSecurityPolicy defaultPolicy]");
		%log;
		id policy = %orig;

// Tell clang not to barf when passing unknown messages to id-type objects.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access" 

		[policy setSSLPinningMode:AFSSLPinningModeNone];
		[policy setAllowInvalidCertificates:TRUE];
		[policy setValidatesCertificateChain:FALSE];
		[policy setValidatesDomainName:FALSE];

#pragma clang diagnostic pop

		return policy;
	}
	return %orig;
}

+(id)policyWithPinningMode:(int)pinningMode {
	if([[iSpy sharedInstance] SSLPinningBypass] == TRUE) {
		ispy_nslog("[iSpy] SSL pinning bypass (AFNetworking). Intercepting +[AFSecurityPolicy policyWithPinningMode:]");
		%log;
		return %orig(AFSSLPinningModeNone);
	}
	return %orig;
}

- (void)setSSLPinningMode:(int)mode {
	if([[iSpy sharedInstance] SSLPinningBypass] == TRUE) {
		ispy_nslog("[iSpy] SSL pinning bypass (AFNetworking). Intercepting -[AFSecurityPolicy setSSLPinningMode:]");
		%log;
		%orig(AFSSLPinningModeNone);
		return;
	}
	%orig;
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust {
	if([[iSpy sharedInstance] SSLPinningBypass] == TRUE) {
		ispy_nslog("[iSpy] SSL pinning bypass (AFNetworking). Intercepting -[AFSecurityPolicy serverTrust:]");
		%log;
		return YES;
	}
	return %orig;
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain {
	if([[iSpy sharedInstance] SSLPinningBypass] == TRUE) {
		ispy_nslog("[iSpy] SSL pinning bypass (AFNetworking). Intercepting -[AFSecurityPolicy serverTrust:forDomain:]");
		%log;
		return YES;
	}
	return %orig;
}
%end

/*
	Add further SSL pinning bypasses here.
*/
