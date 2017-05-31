#ifdef DEBUG
#define SNLog(...) NSLog(__VA_ARGS__)
#else
#define SNLog(...) void(0)
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_9_0
#define kCFCoreFoundationVersionNumber_iOS_9_0 1240.10
#endif

#define IOS_LT(version) (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_##version)
