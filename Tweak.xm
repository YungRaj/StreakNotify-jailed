/*
	Bishop Fox - Theos for jailed iOS devices
*/
#import <dlfcn.h>
#include <pthread.h>
#include <errno.h>
#include <objc/message.h>
#import "Cycript.framework/headers/cycript.h"
#include "fishhook/fishhook.h"
#include "iSpy.class.h"
#include "iSpy.common.h"
#include "iSpy.instance.h"
#include "iSpy.msgSend.common.h"
#include "Interfaces.h"

#define CYCRIPT_PORT 31337

static CFStringRef applicationID = CFSTR("com.YungRaj.streaknotify");


/* gets the earliest snap that wasn't replied to, it is important to do that because a user can just send a snap randomly and reset the 24 hours. basically forces you to respond if you just keep opening messages
 this is a better solution than the private SnapStreakData class that the app uses in the new chat 2.0 update
 */

Snap* FindEarliestUnrepliedSnapForChat(SCChat *chat){
    NSArray *snaps = [chat allSnapsArray];
    
    if(!snaps || ![snaps count]){
        return nil;
    }
    
    snaps = [snaps sortedArrayUsingComparator:^(id obj1, id obj2){
        if ([obj1 isKindOfClass:objc_getClass("Snap")] &&
            [obj2 isKindOfClass:objc_getClass("Snap")]) {
            Snap *s1 = obj1;
            Snap *s2 = obj2;
            
            if([s1.timestamp laterDate:s2.timestamp]) {
                return (NSComparisonResult)NSOrderedAscending;
            } else if ([s2.timestamp laterDate:s1.timestamp]) {
                return (NSComparisonResult)NSOrderedDescending;
            }
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    Snap *earliestUnrepliedSnap = nil;
    
    for(id obj in snaps){
        if([obj isKindOfClass:objc_getClass("Snap")]){
            Snap *snap = obj;
            NSString *sender = [snap sender];
            if(!sender){
                earliestUnrepliedSnap = nil;
            }else if(!earliestUnrepliedSnap && sender){
                earliestUnrepliedSnap = snap;
            }
        }
    }
    return earliestUnrepliedSnap;
}

/*
 this might be useful later in the future
 static NSString* UsernameForDisplay(NSString *display){
 Manager *manager = [%c(Manager) shared];
 User *user = [manager user];
 Friends *friends = [user friends];
 for(Friend *f in [friends getAllFriends]){
 if([display isEqual:f.display]){
 return f.name;
 }
 }
 /* this shouldn't happen if the display variable is coming from the friendmojilist settings plist
 return nil;
 }
 */


static void SizeLabelToRect(UILabel *label, CGRect labelRect){
    /* utility method to make sure that the label's size doesn't truncate the text that it is supposed to display */
    label.frame = labelRect;
    
    int fontSize = 15;
    int minFontSize = 3;
    
    CGSize constraintSize = CGSizeMake(label.frame.size.width, MAXFLOAT);
    
    do {
        label.font = [UIFont fontWithName:label.font.fontName size:fontSize];
        
        CGRect textRect = [[label text] boundingRectWithSize:constraintSize
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{NSFontAttributeName:label.font}
                                                     context:nil];
        
        CGSize labelSize = textRect.size;
        if( labelSize.height <= label.frame.size.height )
            break;
        
        fontSize -= 0.5;
        
    } while (fontSize > minFontSize);
}


static NSString* GetTimeRemaining(Friend *f, SCChat *c, Snap *earliestUnrepliedSnap){
    /* good utility method to figure out the time remaining for the streak
     
     in the new chat 2.0 update to snapchat, the SOJUFriend and SOJUFriendBuilder class now sets a property called snapStreakExpiration/snapStreakExpiryTime which is basically a long long value that describes the time in seconds since 1970 of when the snap streak should end when that expiration date arrives.
     
     if I decide to support only the newest revisions of Snapchat, then I will implement it this way. however even though in the last revisions of Snapchat that API wasn't there it could be possible that it was private and thus not available on headers dumped via class-dump.
     
     for now I am just using 24 hours past the earliest snap sent that wasn't replied to
     */
    if(!f || !c){
        return @"";
    }
    
    NSDate *date = [NSDate date];
    
    
    NSDate *latestSnapDate = [earliestUnrepliedSnap timestamp];
    int daysToAdd = 1;
    NSDate *latestSnapDateDayAfter = [latestSnapDate dateByAddingTimeInterval:60*60*24*daysToAdd];
    NSCalendar *gregorianCal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSUInteger unitFlags = NSSecondCalendarUnit | NSMinuteCalendarUnit |NSHourCalendarUnit | NSDayCalendarUnit;
    NSDateComponents *components = [gregorianCal components:unitFlags
                                                   fromDate:date
                                                     toDate:latestSnapDateDayAfter
                                                    options:0];
    NSInteger day = [components day];
    NSInteger hour = [components hour];
    NSInteger minute = [components minute];
    NSInteger second = [components second];
    
    if(day<0 || hour<0 || minute<0 || second<0){
        return @"Limited";
        /*this means that the last snap + 24 hours later is earlier than the current time... and a streak is still valid assuming that the function that called this checked for a valid streak
         in the new chat 2.0 update the new properties introduced into the public API for the SOJUFriend and SOJUFriendBuilder class allow us to know when the server will end the streak
         if I use snapStreakExpiration/snapStreakExpiryTime then this shouldn't happen unless there's a bug in the Snapchat application
         this API isn't available (or public) so for previous versions of Snapchat this would not work
         */
    }
    
    if(day){
        return [NSString stringWithFormat:@"%ldd",(long)day];
    }else if(hour){
        return [NSString stringWithFormat:@"%ld hr",(long)hour];
    }else if(minute){
        return [NSString stringWithFormat:@"%ld m",(long)minute];
    }else if(second){
        return [NSString stringWithFormat:@"%ld s",(long)second];
    }else{
        /* this shouldn't happen but to shut the compiler up this is needed */
        return @"Unknown";
    }
    
}

/* easier to read when viewing the code, can call [application cancelAllLocalNotfiications] though */
static void CancelScheduledLocalNotifications(){
    UIApplication *application = [UIApplication sharedApplication];
    NSArray *scheduledLocalNotifications = [application scheduledLocalNotifications];
    for(UILocalNotification *notification in scheduledLocalNotifications){
        [application cancelLocalNotification:notification];
    }
}

static void ScheduleNotification(NSDate *snapDate,
                                 NSString *displayName,
                                 float seconds,
                                 float minutes,
                                 float hours){
    /* schedules the notification and makes sure it isn't before the current time */
    float t = hours ? hours : minutes ? minutes : seconds;
    NSString *time =  hours ? @"hours" : minutes ? @"minutes" : @"seconds";
    NSDate *notificationDate =
    [[NSDate alloc] initWithTimeInterval:60*60*24 - 60*60*hours - 60*minutes - seconds
                               sinceDate:snapDate];
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = notificationDate;
    notification.alertBody = [NSString stringWithFormat:@"Keep streak with %@. %ld %@ left!",displayName,(long)t,time];
    NSDate *latestDate = [notificationDate laterDate:[NSDate date]];
    if(latestDate==notificationDate){
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        NSLog(@"Scheduling notification for %@, firing at %@",displayName,[notification fireDate]);
    }
}

static void ResetNotifications(){
    /* ofc set the local notifications based on the preferences, good utility function that is commonly used in the tweak
     */
    
    CancelScheduledLocalNotifications();
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    Friends *friends = [user friends];
    SCChats *chats = [user chats];
    
    for(SCChat *chat in [chats allChats]){
        
        Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(chat);
        NSDate *snapDate = [earliestUnrepliedSnap timestamp];
        Friend *f = [friends friendForName:[chat recipient]];
        
        NSLog(@"%@ snapDate for %@",snapDate,[chat recipient]);
        
        if([f snapStreakCount]>2 && earliestUnrepliedSnap){
            NSString *displayName = [friends displayNameForUsername:[chat recipient]];
            ScheduleNotification(snapDate,displayName,0,0,1);
            ScheduleNotification(snapDate,displayName,0,10,0);
        }
    }
    
    NSLog(@"Resetting notifications success %@",[[UIApplication sharedApplication] scheduledLocalNotifications]);
}

/* a remote notification has been sent from the APNS server and we must let the app know so that it can schedule a notification for the chat */
/* we need to fetch updates so that the new snap can be found */
/* otherwise we won't be able to set the notification properly because the new snap or message hasn't been tracked by the application */

void HandleRemoteNotification(){
    NSLog(@"Resetting local notifications");
    [[objc_getClass("Manager") shared] fetchUpdatesWithCompletionHandler:^(BOOL success){
        NSLog(@"Finished fetching updates, resetting local notifications");
        ResetNotifications();
    }
                                                          includeStories:NO
                                                 didHappendWhenAppLaunch:YES];
}

#ifdef THEOS
%group SnapchatHooks
%hook AppDelegate
#endif

-(BOOL)application:(UIApplication*)application
didFinishLaunchingWithOptions:(NSDictionary*)launchOptions{
    
    /* just makes sure that the app is registered for local notifications, might be implemented in the app but haven't explored it, for now just do this.
     */
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    
    NSLog(@"Just launched application successfully, resetting local notifications for streaks");
    
    ResetNotifications();
    
    
    return %orig();
}

-(void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    /* everytime we receive a snap or even a chat message, we want to make sure that the notifications are updated each time*/
    HandleRemoteNotification();
    %orig();
}

-(void)applicationDidBecomeActive:(UIApplication*)application
{
    ResetNotifications();
    %orig();
}

#ifdef THEOS
%end
#endif


static NSMutableArray *instances = nil;
static NSMutableArray *labels = nil;


#ifdef THEOS
%hook Snap
#endif

/* the number has changed for the friend and now we must let the daemon know of the changes so that they can be saved to file */
-(void)setSnapStreakCount:(long long)snapStreakCount{
    %orig(snapStreakCount);
}

/* call the chatsDidMethod on the chats object so that the SCFeedViewController tableview can reload safely without graphics bugs */

-(void)doSend{
    %orig();
    
    NSLog(@"Post send snap");
    
    Manager *manager = [%c(Manager) shared];
    User *user = [manager user];
    SCChats *chats = [user chats];
    [chats chatsDidChange];
}

#ifdef THEOS
%end
#endif

#ifdef THEOS
%hook SCFeedViewController
#endif


-(UITableViewCell*)tableView:(UITableView*)tableView
       cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    
    /* updating tableview and we want to make sure the labels are updated too, if not created if the feed is now being populated
     */
    
    UITableViewCell *cell = %orig(tableView,indexPath);
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        /* want to do this on the main thread because all ui updates should be done on the main thread
         this should already be on the main thread but we should make sure of this
         */
        
        if([cell isKindOfClass:objc_getClass("SCFeedTableViewCell")]){
            SCFeedTableViewCell *feedCell = (SCFeedTableViewCell*)cell;
            
            if(!instances){
                instances = [[NSMutableArray alloc] init];
            } if(!labels){
                labels = [[NSMutableArray alloc] init];
            }
            
            SCChatViewModelForFeed *feedItem = feedCell.feedItem;
            SCChat *chat = [feedItem chat];
            Friend *f = [feedItem friendForFeedItem];
            
            
            Snap *earliestUnrepliedSnap = FindEarliestUnrepliedSnapForChat(chat);
            
            NSLog(@"%@ is earliest unreplied snap %@",earliestUnrepliedSnap,[earliestUnrepliedSnap timestamp]);
            
            UILabel *label;
            
            if(![instances containsObject:cell]){
                
                CGSize size = cell.frame.size;
                CGRect rect = CGRectMake(size.width*.83,
                                         size.height*.7,
                                         size.width/8,
                                         size.height/4);
                
                label = [[UILabel alloc] initWithFrame:rect];
                
                [instances addObject:cell];
                [labels addObject:label];
                
                [feedCell.containerView addSubview:label];
                
                
            }else {
                label = [labels objectAtIndex:[instances indexOfObject:cell]];
            }
            
            if([f snapStreakCount]>2 && earliestUnrepliedSnap){
                label.text = [NSString stringWithFormat:@"⏰ %@",GetTimeRemaining(f,chat,earliestUnrepliedSnap)];
                SizeLabelToRect(label,label.frame);
                label.hidden = NO;
            }else {
                label.text = @"";
                label.hidden = YES;
            }
        }
    });
    
    return cell;
}


-(void)didFinishReloadData{
    /* want to update notifications if something has changed after reloading data */
    %orig();
    ResetNotifications();
    
}


-(void)dealloc{
    [instances removeAllObjects];
    [labels removeAllObjects];
    %orig();
}


#ifdef THEOS
%end
%end
#endif

/*
 * Constructor
 */
%ctor {
	NSLog(@"[BF] Constructor entry");
	
	// initialize and cache the iSpy sharedInstance. 
	NSLog(@"[BF] Activating iSpy");
	[iSpy sharedInstance]; // do nothing with the return value, just force iSpy to initialize
	
	// Start Cycript
	ispy_nslog("[BF] Starting Cycript. Connect by running \"cycript -r <yourIOSDeviceIP>:%d\" on your MacBook.", CYCRIPT_PORT);
	CYListenServer(CYCRIPT_PORT);

    /* 
     *	The objc_msgSend tracing feature uses a whitelist to determine which methods/classes
     *	should be monitored and logged. By default the whitelist contains all of the methods in all 
     *	of the the classes defined by the target app. 
     *	You can add/remove individual methods and/or entire classes to/from the whitelist.
     *	This is good for removing animations, CPU hogs, and other uninteresting crap.
     */
    //ispy_nslog("[BF] Removing unwanted classes from msgSend whitelist");
    //[mySpy msgSend_whitelistRemoveClass:@"ClassWeDoNotCareAbout"];

    // Remove an individual method from the whitelist
    //[mySpy msgSend_whitelistRemoveMethod:@"testMethod" fromClass:@"FooClass"];

    // Add a method to the whitelist
    //[mySpy msgSend_whitelistAddMethod:@"setHTTPBody:" forClass:@"NSMutableURLRequest"];

    // Add all the methods in a single class
	//[mySpy msgSend_whitelistAddClass:@"NSURLConnection"];
	    
	/*
	 *	Turn on objc_msgSend tracing.
	 *	You can also turn it on/off in Cycript using: 
	 *		[[iSpy sharedInstance] msgSend_enableLogging]
	 *		[[iSpy sharedInstance] msgSend_disableLogging]
	 */
	//ispy_nslog("[BF] Enabling msgSend logging to %s/Documents/.iSpy/*.log", [[mySpy appPath] UTF8String]);
	//[mySpy msgSend_enableLogging];

	/*
	 *	Bypass SSL pinning. Uses a combination of:
	 *		- TrustMe SecTrustEvaluate() bypass
	 *		- BF's custom AFNetworking bypasses
	 *	This is disabled by default and you must enable it manually here or
	 *	in Cycript, by using: [[iSpy sharedInstance] SSLPinning_enableBypass]
	 */
	//ispy_nslog("[BF] Enabling SSL Pinning bypasses");
	//[mySpy SSLPinning_enableBypass];
	
	/*
	 *	By default the instance tracker is off. Turn it on.
	 */
	ispy_nslog("[BF] Enabling instance tracker");
	[[[iSpy sharedInstance] instanceTracker] start];
	
	/*
	 *	Now we continue with the normal load process, passing control to the app's main() function.
	 */
	ispy_nslog("[BF] All done, continuing dyld load sequence.");
    
    %init(SnapchatHooks);
}
