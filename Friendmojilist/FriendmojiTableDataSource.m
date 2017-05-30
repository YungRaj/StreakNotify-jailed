#import <objc/runtime.h>
#import "FriendmojiTableDataSource.h"

@interface Friend
@property (strong,nonatomic) NSString *display;
-(NSString*)name;
-(NSString*)getFriendmojiForViewType:(NSInteger)type;
-(long long)snapStreakCount;
@end

@interface Friends
-(NSArray*)getAllFriends;
@end

@interface User
-(Friends*)friends;
@end

@interface Manager
+(Manager*)shared;
-(User*)user;
@end

@interface FriendmojiCell : UITableViewCell {
    
}

@end

@implementation FriendmojiCell


@end

@interface FriendmojiTableDataSource () {
    
}

@property (strong,nonatomic) NSDictionary *settings;
@property (strong,nonatomic) NSArray *friendsWithStreaksNames;
@property (strong,nonatomic) NSArray *friendmojisWithStreaks;
@property (strong,nonatomic) NSArray *friendsWithoutStreaksNames;
@property (strong,nonatomic) NSArray *friendmojisWithoutStreaks;

@end


@implementation FriendmojiTableDataSource

+(id)dataSource
{
    return [[[self alloc] init] autorelease];
}

-(id)init
{
    self = [super init];
    if (self) {
        NSArray *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [[documents objectAtIndex:0] stringByAppendingPathComponent:@"com.YungRaj.friendmojilist.plist"];
        self.settings = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        
        NSMutableDictionary *friendsWithStreaks = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *friendsWithoutStreaks = [[NSMutableDictionary alloc] init];
        
        Manager *manager = [objc_getClass("Manager") shared];
        User *user = [manager user];
        Friends *friends = [user friends];
        for(Friend *f in [friends getAllFriends]){
            
            NSString *displayName = [f display];
            NSString *friendmoji = [f getFriendmojiForViewType:0];
            
            if(displayName && ![displayName isEqual:@""]){
                if([f snapStreakCount] > 2){
                    [friendsWithStreaks setObject:friendmoji forKey:displayName];
                }else {
                    [friendsWithoutStreaks setObject:friendmoji forKey:displayName];
                }
            }else{
                NSString *username = [f name];
                if(username && ![username isEqual:@""]){
                    if([f snapStreakCount] > 2){
                        [friendsWithStreaks setObject:friendmoji forKey:username];
                    }else {
                        [friendsWithoutStreaks setObject:friendmoji forKey:username];
                    }
                }
            }
        }
        
        NSArray *friendsWithStreaksNames = [friendsWithStreaks allKeys];
        NSMutableArray *friendmojisWithStreaks = [[NSMutableArray alloc] init];
        
        NSArray *friendsWithoutStreaksNames = [friendsWithoutStreaks allKeys];
        NSMutableArray *friendmojisWithoutStreaks = [[NSMutableArray alloc] init];
        
        friendsWithStreaksNames = [friendsWithStreaksNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        friendsWithoutStreaksNames = [friendsWithoutStreaksNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        
        for(NSString *name in friendsWithStreaksNames){
            NSString *friendmoji = [friendsWithStreaks objectForKey:name];
            [friendmojisWithStreaks addObject:friendmoji];
        }
        
        for(NSString *name in friendsWithoutStreaksNames){
            NSString *friendmoji = [friendsWithoutStreaks objectForKey:name];
            [friendmojisWithoutStreaks addObject:friendmoji];
        }
        
        NSLog(@"friendmojilist:: Friends with streaks %@ %@",friendsWithStreaksNames,friendmojisWithStreaks);
        NSLog(@"friendmojilist:: Friends without streaks %@ %@",friendsWithoutStreaksNames,friendmojisWithoutStreaks);
        
        self.friendsWithStreaksNames = friendsWithStreaksNames;
        self.friendmojisWithStreaks = friendmojisWithStreaks;
        
        self.friendsWithoutStreaksNames = friendsWithoutStreaksNames;
        self.friendmojisWithoutStreaks = friendmojisWithoutStreaks;
        
        /* Create settings if they don't exist */
        if(!self.settings){
            NSMutableDictionary *settings  = [[NSMutableDictionary alloc] init];
            for(NSString *name in self.friendsWithStreaksNames){
                [settings setObject:@NO forKey:name];
            }
            
            for(NSString *name in self.friendsWithoutStreaksNames){
                [settings setObject:@NO forKey:name];
            }
            
            self.settings = settings;
            
            
            NSLog(@"friendmojilist:: %@",self.settings);
        }

        
        /* Add the data source as an observer to find out when the 
         * FriendmojiListController will exit so that we can save the dictionary to file */
        [[NSNotificationCenter defaultCenter]
                        addObserver:self
                           selector:@selector(friendmojiPreferencesWillExit:)
                               name:@"friendmojiPreferencesWillExit"
                            object:nil];
    }
    
    return self;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = @"Friends with Streaks";
            break;
        case 1:
            sectionName = @"Other Friends";
            break;
            // ...
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
            return [self.friendsWithStreaksNames count];
        case 1:
            return [self.friendsWithoutStreaksNames count];
    }
    return 0;
}


-(UITableViewCell*)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *identifier = @"friendmojiCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if(!cell){
        cell = [[[FriendmojiCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:identifier] autorelease];
        
    }
    if(indexPath.section == 0){
        if([cell isKindOfClass:[FriendmojiCell class]]){
            
            FriendmojiCell *friendmojiCell = (FriendmojiCell*)cell;
            NSString *name = [self.friendsWithStreaksNames objectAtIndex:indexPath.row];
            NSString *friendmoji = [self.friendmojisWithStreaks objectAtIndex:indexPath.row];
            friendmojiCell.textLabel.text = [NSString stringWithFormat:@"%@ %@",name,friendmoji];
            NSLog(@"friendmojilist::Cell for index %ld name %@ %@",(long)indexPath.row,name,friendmoji);
            if([self.settings[name] boolValue]){
                friendmojiCell.accessoryType = UITableViewCellAccessoryCheckmark;
            }else{
                friendmojiCell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if(indexPath.section == 1){
        if([cell isKindOfClass:[FriendmojiCell class]]){
            
            FriendmojiCell *friendmojiCell = (FriendmojiCell*)cell;
            NSString *name = [self.friendsWithoutStreaksNames objectAtIndex:indexPath.row];
            NSString *friendmoji = [self.friendmojisWithoutStreaks objectAtIndex:indexPath.row];
            friendmojiCell.textLabel.text = [NSString stringWithFormat:@"%@ %@",name,friendmoji];
            NSLog(@"friendmojilist:: Cell for index %ld name %@ %@",(long)indexPath.row,name,friendmoji);
            if([self.settings[name] boolValue]){
                friendmojiCell.accessoryType = UITableViewCellAccessoryCheckmark;
            }else{
                friendmojiCell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    }
    return cell;

}

-(void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    FriendmojiCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *name = [NSString string];
    
    if(indexPath.section == 0){
        name = [self.friendsWithStreaksNames objectAtIndex:indexPath.row];
    } else if(indexPath.section == 1){
        name = [self.friendsWithoutStreaksNames objectAtIndex:indexPath.row];
    }
    
    [self.settings setValue:[NSNumber numberWithBool:![self.settings[name] boolValue]]
                     forKey:name];
    
    
    if(cell.accessoryType==UITableViewCellAccessoryCheckmark){
        cell.accessoryType = UITableViewCellAccessoryNone;
    }else if(cell.accessoryType==UITableViewCellAccessoryNone){
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


-(void)friendmojiPreferencesWillExit:(NSNotification*)notification{
    NSDictionary *settings = self.settings;
    
    NSArray *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[documents objectAtIndex:0] stringByAppendingPathComponent:@"com.YungRaj.friendmojilist.plist"];
    
    [settings writeToFile:path
               atomically:YES];
    
    NSLog(@"friendmojilist::Saved settings");
    
}

-(void)dealloc{
    [super dealloc];
    [self.settings release];
    [self.friendsWithStreaksNames release];
    [self.friendsWithoutStreaksNames release];
    [self.friendmojisWithStreaks release];
    [self.friendmojisWithoutStreaks release];
    _settings = nil;
    _friendsWithStreaksNames = nil;
    _friendsWithoutStreaksNames = nil;
    _friendmojisWithStreaks = nil;
    _friendmojisWithoutStreaks = nil;
}

@end
