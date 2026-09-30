#import <AppKit/AppKit.h>

@interface SameApp : NSObject <NSApplicationDelegate>
@property(strong) NSWindow *first;
@property(strong) NSWindow *second;
@property(strong) NSTimer *timer;
@property(copy) NSString *lastCommand;
@end
@implementation SameApp
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    (void)note;
    self.first = [[NSWindow alloc] initWithContentRect:NSMakeRect(380,180,440,260)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.second = [[NSWindow alloc] initWithContentRect:NSMakeRect(520,230,440,260)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.first.title = @"PinTop 同应用测试 1";
    self.second.title = @"PinTop 同应用测试 2";
    [self.second makeKeyAndOrderFront:nil];
    [self.first makeKeyAndOrderFront:nil];
    [NSApp activate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(tick)
        userInfo:nil repeats:YES];
    [self tick];
}
- (void)tick {
    NSString *path = @"/tmp/pintop-no-sip-lab/same-command";
    NSString *command = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (command.length && ![command isEqualToString:self.lastCommand]) {
        self.lastCommand = command;
        if ([command hasPrefix:@"1"]) [self.first makeKeyAndOrderFront:nil];
        if ([command hasPrefix:@"2"]) [self.second makeKeyAndOrderFront:nil];
        if ([command hasPrefix:@"m"]) [self.first miniaturize:nil];
        if ([command hasPrefix:@"d"]) [self.first deminiaturize:nil];
        if ([command hasPrefix:@"h"]) [NSApp hide:nil];
        if ([command hasPrefix:@"u"]) [NSApp unhide:nil];
        if (![command hasPrefix:@"h"] && ![command hasPrefix:@"m"]) [NSApp activate];
    }
    NSDictionary *state = @{ @"pid": @(getpid()), @"first": @(self.first.windowNumber),
        @"second": @(self.second.windowNumber), @"key": @(NSApp.keyWindow.windowNumber),
        @"mini": @(self.first.miniaturized), @"hidden": @(NSApp.hidden) };
    NSData *data = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
    [data writeToFile:@"/tmp/pintop-no-sip-lab/same.json" atomically:YES];
}
@end
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        SameApp *delegate = [SameApp new];
        NSApp.delegate = delegate;
        [NSApp run];
    }
}
