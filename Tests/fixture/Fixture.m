#import <AppKit/AppKit.h>

@interface Fixture : NSObject <NSApplicationDelegate>
@property(strong) NSWindow *window;
@property(strong) NSTextField *field;
@property(strong) NSTimer *timer;
@property(strong) id monitor;
@property(strong) NSMutableArray *events;
@property(copy) NSString *label;
@property NSInteger clicks;
@end
@implementation Fixture
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.label=NSProcessInfo.processInfo.arguments.count>1 ? NSProcessInfo.processInfo.arguments[1]:@"A";
    self.events=[NSMutableArray array];
    double x=[self.label isEqualToString:@"A"]?520:300;
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(x,140,440,260) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=[@"PinTop 临时输入测试 " stringByAppendingString:self.label];
    self.window.releasedWhenClosed=NO;
    NSTextField *label=[NSTextField labelWithString:@"临时测试窗口：原窗口与输入焦点"];
    label.frame=NSMakeRect(24,204,390,24);
    [self.window.contentView addSubview:label];
    self.field=[[NSTextField alloc] initWithFrame:NSMakeRect(24,150,[self.label isEqualToString:@"A"]?390:160,26)];
    self.field.placeholderString=@"输入只存于此临时窗口";
    [self.window.contentView addSubview:self.field];
    NSButton *button=[NSButton buttonWithTitle:@"点击计数" target:self action:@selector(clicked:)];
    button.frame=NSMakeRect(24,98,120,30);
    [self.window.contentView addSubview:button];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.field];
    [NSApp activate];
    __weak Fixture *weakSelf=self;
    self.monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskLeftMouseUp|NSEventMaskLeftMouseDragged|NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event) {
        Fixture *s=weakSelf;
        [s.events addObject:@{@"type":@(event.type),@"x":[NSString stringWithFormat:@"%g",event.locationInWindow.x],@"y":[NSString stringWithFormat:@"%g",event.locationInWindow.y],@"window":@(event.windowNumber),@"flags":@(event.modifierFlags)}];
        if(s.events.count>12)[s.events removeObjectAtIndex:0];
        return event;
    }];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(save) userInfo:nil repeats:YES];
    [self save];
}
- (void)clicked:(id)sender { (void)sender;self.clicks++;[self save]; }
- (void)save {
    NSDictionary *state=@{@"pid":@(getpid()),@"window":@(self.window.windowNumber),@"active":@(NSApp.active),@"key":@(self.window.keyWindow),@"main":@(self.window.mainWindow),@"text":self.field.stringValue,@"clicks":@(self.clicks),@"mouseLog":self.events,@"level":@(self.window.level),@"time":@(NSDate.date.timeIntervalSince1970)};
    NSError *error=nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingSortedKeys error:&error];
    NSString *path=[NSString stringWithFormat:@"/tmp/pintop-no-sip-lab/%@.json",self.label];
    if(![data writeToFile:path options:NSDataWritingAtomic error:&error])NSLog(@"state error %@",error);
}
@end
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        Fixture *fixture=[Fixture new];NSApp.delegate=fixture;[NSApp run];
    }
}
