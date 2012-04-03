## Get started

- Drag the sdk/blowtorch-ios-sdk folders into your xcode project
- Copy into AppDelegate.h:
	#import <UIKit/UIKit.h>
	#import "BTAppDelegate.h"

	@interface AppDelegate : BTAppDelegate

	@end
- Copy into AppDelegate.m:
	#import "AppDelegate.h"

	@implementation AppDelegate

	@end
- Project file row -> Targets -> Build Phases -> Compile Sources
	- Mark all AF* files
	- Mark UIImageView+AFNetworking file
	- Mark JSONKit file
	- Mark NSFileManager+Tar file
	- Mark WebViewJavascriptBridge file
	- Add this compiler flag to all those files: `-fno-objc-arc`

