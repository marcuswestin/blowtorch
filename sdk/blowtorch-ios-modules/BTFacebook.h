#import "BTModule.h"
#import "Facebook.h"
#import "FBSession.h"
#import "FBSettings.h"

@interface BTFacebook : BTModule <FBDialogDelegate>

+ (BOOL)handleOpenURL:(NSURL*)url;

@end
