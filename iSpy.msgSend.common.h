#ifndef ___ISPY_MSGSEND_COMMON___
#define ___ISPY_MSGSEND_COMMON___
#include <tr1/unordered_set>
#include <tr1/unordered_map>

// Uncomment the next line to do crazy verbose logging inside objc_msgSend.
// Be aware this will basically grind your app to a halt. 
// It's useful for debugging crashes, but too much overhead otherwise.
// It's a compile-time option for a reason.

//#define DO_SUPER_DEBUG_MODE 1

#ifdef DO_SUPER_DEBUG_MODE
#define __log__(...) ispy_log(__VA_ARGS__)
#else
#define __log__(...) {}
#endif

// Important. Don't futz.
struct objc_callState {
	char *json;
	char *returnType;
};

// If you know what this does you've already lol'd at my code.
#define ISPY_MAX_RECURSION 128

extern "C" USED const char *get_param_value(id x);
extern "C" USED void *print_args_v(id self, SEL _cmd, std::va_list va);
extern "C" USED char *parameter_to_JSON(char *typeCode, void *paramVal);
extern "C" unsigned int is_this_method_on_whitelist(id Cls, SEL selector);
extern "C" USED void interesting_call_postflight_check(struct objc_callState *callState, struct interestingCall *call);
extern "C" void breakpoint_wait_until_release(struct interestingCall *call);
void breakpoint_release_breakpoint(const char *className, const char *methodName);

#endif
