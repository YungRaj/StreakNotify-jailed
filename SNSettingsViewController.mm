#import "SNAPI.h"
#import "SNSettingsViewController.h"
#import "FriendmojiListController.h"

extern NSDictionary *prefs;
static NSMutableDictionary *preferences = nil;
static NSDictionary *general = @{@"kStreakNotifyDisabled" : @"Disable StreakNotify?",
                                 @"kExactTime" : @"Show exact time remaining"};
static NSDictionary *notifications = @{ @"kTwelveHours" :  @"12 hours remaining",
                                        @"kFiveHours" : @"5 hours remaining",
                                        @"kOneHour" : @"1 hour remaining",
                                        @"kTenMinutes" : @"10 minutes remaining" };
static NSArray *custom = @[@"Hours",@"Minutes",@"Seconds",@"Friendmoji", @"AutoReply"];


typedef enum{
    GENERAL,
    NOTIFICATIONS,
    CUSTOM,
} SNSettingsCellType;

@interface SNSettingsCell : UITableViewCell {
    
}

@property (strong,nonatomic) UISwitch *toggle;
@property (strong,nonatomic) UITextField *time;

@end

@implementation SNSettingsCell

-(id)initWithType:(SNSettingsCellType)type
        style:(UITableViewCellStyle)style
   reuseIdentifier:(NSString *)reuseIdentifier{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(self){
        CGSize size = self.frame.size;
        if(type == GENERAL || type == NOTIFICATIONS){
            self.toggle = [[UISwitch alloc] initWithFrame:CGRectMake(size.width-size.width/12.5,size.height/20,
                                                                     size.width/15,size.height-size.height/10)];
            [self.toggle setOn:[preferences[reuseIdentifier] boolValue] animated:YES];
            [self addSubview:self.toggle];
            [self.toggle addTarget:self action:@selector(toggleSwitch)
                  forControlEvents:UIControlEventTouchUpInside];
            
        } else if(type == CUSTOM){
            if([reuseIdentifier isEqualToString:@"Hours"] ||
               [reuseIdentifier isEqualToString:@"Minutes"] ||
               [reuseIdentifier isEqualToString:@"Seconds"]){
                NSString *key = [NSString stringWithFormat:@"kCustom%@",reuseIdentifier];
                self.time = [[UITextField alloc] initWithFrame:CGRectMake(size.width-size.width/7.5,size.height/20,
                                                                          size.width/4,size.height-size.height/10)];
                self.time.text = [NSString stringWithFormat:@"%d",[preferences[key] intValue]];
                self.time.borderStyle = UITextBorderStyleRoundedRect;
                self.time.keyboardType = UIKeyboardTypeNumberPad;
                [self addSubview:self.time];
                
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(preferencesWillExit:)
                                                             name:@"streakNotifyPreferencesWillExit"
                                                           object:nil];
            }
        }
    }
    return self;
}

-(void)toggleSwitch{
    NSString *identifier = self.reuseIdentifier;
    preferences[identifier] = [NSNumber numberWithBool:[preferences[identifier] boolValue] ^ true];
}

-(void)preferencesWillExit:(NSNotification*)notification{
    NSString *key = [NSString stringWithFormat:@"kCustom%@",self.reuseIdentifier];
    
    if(preferences[key]){
        preferences[key] = [NSNumber numberWithInt:[[self.time text] intValue]];
    }
}

-(void)dealloc{
    [super dealloc];
    if(_toggle){
        [_toggle release];
    } if(_time){
        [_time release];
    }
}

@end



@interface SNSettingsViewController () {
    
}

@end


@implementation SNSettingsViewController

-(id)init
{
    self = [super init];
    if (self) {
        preferences = [prefs mutableCopy];
        
        if(!preferences){
            preferences = [[@{@"kStreakNotifyDisabled" : @NO,
                              @"kExactTime" : @YES,
                              @"kTwelveHours" : @YES,
                              @"kFiveHours" : @NO,
                              @"kOneHour" : @NO,
                              @"kTenMinutes" : @NO,
                              @"kCustomHours" : @"0",
                              @"kCustomMinutes" : @"0",
                              @"kCustomSeconds" : @"0"} mutableCopy] retain];
            
            NSArray *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *path = [[documents objectAtIndex:0] stringByAppendingPathComponent:@"com.YungRaj.streaknotify.plist"];
            
            [preferences writeToFile:path atomically:YES];
        }
    }
    
    return self;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"streakNotifyPreferencesWillExit"
                                                        object:nil];
    [self savePreferences];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    if ([self isMovingFromParentViewController]) {
        //specific stuff for being popped off stack
        [[NSNotificationCenter defaultCenter] postNotificationName:@"resetNotifications"
                                                            object:nil];
    }
}

 -(void)choosePhotoForAutoReplySnapstreak{
    SNLog(@"streaknotify:: prompting user to select auto reply snapstreak image");
    UIImagePickerController *pickerLibrary = [[UIImagePickerController alloc] init];
    pickerLibrary.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickerLibrary.delegate = self;
    [self presentViewController:pickerLibrary animated:YES completion:nil];
 }
 
 -(void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    NSData *imageData = UIImageJPEGRepresentation(image,0.7);
 
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
 
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory]){
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    }
 
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"streaknotify_autoreply.jpeg"];
 
    SNLog(@"streaknotify:: Writing autoreply image to file %@",filePath);
 
    [imageData writeToFile:filePath atomically:YES];
    [picker dismissViewControllerAnimated:YES completion:nil];
 }



-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 3;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = @"General";
            break;
        case 1:
            sectionName = @"Notifications";
            break;
            // ...
        case 2:
            sectionName = @"Custom";
            break;
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}

-(NSInteger)tableView:(UITableView *)tableView
numberOfRowsInSection:(NSInteger)section{
    
    switch (section)
    {
        case 0:
            return [[general allKeys] count];
        case 1:
            return [[notifications allKeys] count];
        case 2:
            return [custom count];
    }
    return 0;
}



-(UITableViewCell*)tableView:(UITableView*)tableView
       cellForRowAtIndexPath:(NSIndexPath*)indexPath{
    NSString *key = nil;
    NSString *value = nil;
    
    if(indexPath.section == 0){
        key = [[general allKeys] objectAtIndex:indexPath.row];
        value = [[general allValues] objectAtIndex:indexPath.row];
    } else if(indexPath.section == 1){
        key = [[notifications allKeys] objectAtIndex:indexPath.row];
        value = [[notifications allValues] objectAtIndex:indexPath.row];
    } else if(indexPath.section == 2){
        key = [custom objectAtIndex:indexPath.row];
        value = key;
        
    }
    
    SNLog(@"%@ key set identifier for cell at indexPath %@",key,indexPath);
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:key];
    
    if(!cell){
        cell = [[[SNSettingsCell alloc] initWithType:(SNSettingsCellType)indexPath.section
                                                style:UITableViewCellStyleDefault
                                      reuseIdentifier:key] autorelease];
        
    }
    
    if([cell isKindOfClass:[SNSettingsCell class]]){
        SNSettingsCell *snCell = (SNSettingsCell*)cell;
        snCell.textLabel.text = value;
        
        if(indexPath.section == 2){
            snCell.toggle.hidden = YES;
        } else {
            snCell.toggle.hidden = NO;
        }
    }
    
    return cell;
    
}

-(void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    // UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if(indexPath.section == 2){
        NSString *option = [custom objectAtIndex:indexPath.row];
        if([option isEqualToString:@"Friendmoji"]){
            FriendmojiListController *friendmojilist = [[FriendmojiListController alloc] init];
            [self.navigationController pushViewController:friendmojilist animated:YES];
            
        } else if([option isEqualToString:@"AutoReply"]){
            [self choosePhotoForAutoReplySnapstreak];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
                            
                            
-(void)savePreferences{
    NSArray *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[documents objectAtIndex:0] stringByAppendingPathComponent:@"com.YungRaj.streaknotify.plist"];
                                
    [preferences writeToFile:path
                   atomically:YES];
    
    SNLog(@"Saved preferences %@",preferences);
    
    prefs = preferences;
    
    preferences = nil;
    SNLog(@"StreakNotify::Saved preferences");
                                
}

-(void)dealloc{
    [super dealloc];
}


@end




