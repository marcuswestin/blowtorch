//https://gist.github.com/1184827

#ifdef DEBUG

#import "DebugUIWebView.h"
#import "BTAppDelegate.h"

@class WebFrame;

@interface WebView
- (void)setScriptDebugDelegate:(id)delegate;
@end

@interface WebScriptCallFrame
- (id)exception;
- (NSString*)functionName;
- (WebScriptCallFrame*)caller;
@end

@interface WebScriptObject
- (id)valueForKey:(NSString*)key;
@end

@implementation DebugUIWebView

@synthesize sourceIDMap = sourceIDMap_;
static NSString* const kSourceIDMapFilenameKey = @"filename";
static NSString* const kSourceIDMapSourceKey = @"source";


- (id)initWithFrame:(CGRect)aRect
{
    if ((self = [super initWithFrame:aRect])) {
        self.sourceIDMap = [NSMutableDictionary dictionary];
    }
    
    return self;
}

+ (NSString*)filenameForURL:(NSURL*)url {
    NSString* pathString = [url path];
    NSArray* pathComponents = [pathString pathComponents];
    return [pathComponents objectAtIndex:([pathComponents count] - 1)];
}

+ (NSString*)formatSource:(NSString*)source {
    NSMutableString* formattedSource = [NSMutableString stringWithCapacity:100];
    [formattedSource appendString:@"Source:\n"];
    int* lineNumber = malloc(sizeof(int));
    *lineNumber = 1;
    [source enumerateLinesUsingBlock:^(NSString* line, BOOL* stop) {
        [formattedSource appendFormat:@"%3d: %@", *lineNumber, line];
        (*lineNumber)++;
    }];
    free(lineNumber);
    [formattedSource appendString:@"\n\n"];
    
    return formattedSource;
}

- (void)webView:(WebView*)webView didClearWindowObject:(id)windowObject forFrame:(WebFrame*)frame {
    [webView setScriptDebugDelegate:self];
}


- (void) webView:(WebView*)webView didParseSource:(NSString*)source baseLineNumber:(unsigned int)baseLineNumber fromURL:(NSURL*)url sourceId:(int)sourceID forWebFrame:(WebFrame*)webFrame {
    NSString* filename = nil;
    if (url) {
        filename = [DebugUIWebView filenameForURL:url];
    }
    
    // Save the sourceID -> source and filename mapping for identifying
    // exceptions later.
    NSMutableDictionary* mapEntry = [NSMutableDictionary dictionaryWithObject:source forKey:kSourceIDMapSourceKey];
    if (filename) {
        [mapEntry setObject:filename forKey:kSourceIDMapFilenameKey];
    }
    [self.sourceIDMap setObject:mapEntry forKey:[NSNumber numberWithInt:sourceID]];
    //NSLog(@"%@", [source substringToIndex:MIN(300, [source length])]);
}


- (void)webView:(WebView *)webView failedToParseSource:(NSString *)source baseLineNumber:(unsigned int)baseLineNumber fromURL:(NSURL *)url withError:(NSError *)error forWebFrame:(WebFrame *)webFrame {
    NSDictionary* userInfo = [error userInfo];
    NSNumber* fileLineNumber = [userInfo objectForKey:@"WebScriptErrorLineNumber"];
    
    NSString* filename = @"";
    NSMutableString* sourceLog = [NSMutableString stringWithCapacity:100];
    if (url) {
        filename = [NSString stringWithFormat:@"filename: %@, ", [DebugUIWebView filenameForURL:url]];
    } else {
        [sourceLog appendString:[[self class] formatSource:source]];
    }
    NSLog(@"Parse error - %@baseLineNumber: %d, fileLineNumber: %@\n%@", filename, baseLineNumber, fileLineNumber, sourceLog);
    
//    assert(false);
}

- (void)webView:(WebView *)webView exceptionWasRaised:(WebScriptCallFrame *)frame sourceId:(int)sourceID line:(int)lineNumber forWebFrame:(WebFrame *)webFrame {
    WebScriptObject* exception = [frame exception];
    if ([[exception valueForKey:@"message"] rangeOfString:@"DOM Exception 12"].location != NSNotFound) {
        // jquery test on startup, syntax error
        return;
    }
        
    // Lookup the sourceID and pull out the fields.
    NSDictionary* sourceLookup = [self.sourceIDMap objectForKey:[NSNumber numberWithInt:sourceID]];
    assert(sourceLookup);
    NSString* filename = [sourceLookup objectForKey:kSourceIDMapFilenameKey];
    NSString* source = [sourceLookup objectForKey:kSourceIDMapSourceKey];
    
    NSMutableString *message = [NSMutableString stringWithCapacity:100];
    
    [message appendFormat:@"Exception\n\nName: %@", [exception valueForKey:@"name"]];
    
    if (filename) {
        [message appendFormat:@", filename: %@", filename];
    }
    
    [message appendFormat:@"\nMessage: %@\n\n", [exception valueForKey:@"message"]];
    
    if (!filename) {
        [message appendString:[[self class] formatSource:source]];
    }
    
    NSArray* sourceLines = [source componentsSeparatedByString:@"\n"];
    NSString* sourceLine = [sourceLines objectAtIndex:(lineNumber - 1)];
    if ([sourceLine length] > 200) {
        sourceLine = [[sourceLine substringToIndex:200] stringByAppendingString:@"..."];
    }
    
//    NSString* firstLine = [sourceLines objectAtIndex:0];
//    firstLine = [firstLine stringByReplacingOccurrencesOfString:@";(function() {var module = {exports:{}}; var exports = module.exports;var " withString:@""];

    [message appendString:@"Offending function:\n"];
    [message appendFormat:@"  %d: %@\n", lineNumber, sourceLine];
//    [message appendFormat:@"file: %@\n", firstLine];
    
    // Build the call stack.
    [message appendString:@"\nCall stack:\n"];
    for (WebScriptCallFrame* currentFrame = frame; currentFrame; currentFrame = [currentFrame caller]) {
        [message appendFormat:@"  %@\n", [currentFrame functionName]];
    }
    
    NSLog(@"%@", message);
    
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:message, @"message", nil];
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [[BTAppDelegate instance] notify:@"app.error" info:info];
    });
}

// just entered a stack frame (i.e. called a function, or started global scope)
//- (void)webView:(WebView *)webView didEnterCallFrame:(WebScriptCallFrame *)frame sourceId:(int)sid line:(int)lineno forWebFrame:(WebFrame *)webFrame {}

// about to execute some code
//- (void)webView:(WebView *)webView willExecuteStatement:(WebScriptCallFrame *)frame sourceId:(int)sid line:(int)lineno forWebFrame:(WebFrame *)webFrame;

// about to leave a stack frame (i.e. return from a function)
//- (void)webView:(WebView *)webView willLeaveCallFrame:(WebScriptCallFrame *)frame sourceId:(int)sid line:(int)lineno forWebFrame:(WebFrame *)webFrame;

@end

#endif