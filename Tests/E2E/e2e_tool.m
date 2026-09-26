// End-to-end helper for CI (macOS runners have a single virtual screen).
//
//   e2e_tool vdisplay          create a 1920x1080 virtual display to the right of the main one and keep it alive
//   e2e_tool displays          print "id x y w h" for every active display
//   e2e_tool post <x> <y>      post a mouse-moved event at (x, y), then print where the pointer ended up
//   e2e_tool where             print the pointer location
//   e2e_tool dock              print CoreDockGetRect
//
// Build: clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework ApplicationServices e2e_tool.m -o e2e_tool

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

// Private CoreGraphics classes (macOS 11+), resolved at runtime with NSClassFromString.
@interface CGVirtualDisplayDescriptor : NSObject
@property (retain, nonatomic) dispatch_queue_t queue;
@property (retain, nonatomic) NSString *name;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int serialNum;
@property (nonatomic) CGPoint whitePoint;
@property (nonatomic) CGPoint redPrimary;
@property (nonatomic) CGPoint greenPrimary;
@property (nonatomic) CGPoint bluePrimary;
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (retain, nonatomic) NSArray *modes;
@property (nonatomic) unsigned int hiDPI;
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property (readonly, nonatomic) unsigned int displayID;
@end

static void printDisplays(void) {
    CGDirectDisplayID ids[16];
    uint32_t count = 0;
    CGGetActiveDisplayList(16, ids, &count);
    for (uint32_t i = 0; i < count; i++) {
        CGRect b = CGDisplayBounds(ids[i]);
        printf("%u %.0f %.0f %.0f %.0f%s\n", ids[i], b.origin.x, b.origin.y, b.size.width, b.size.height,
               CGDisplayIsMain(ids[i]) ? " main" : "");
    }
    fflush(stdout);
}

static CGPoint pointer(void) {
    CGEventRef event = CGEventCreate(NULL);
    CGPoint p = CGEventGetLocation(event);
    CFRelease(event);
    return p;
}

static int makeVirtualDisplay(void) {
    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    if (!descriptorClass || !displayClass || !settingsClass || !modeClass) {
        fprintf(stderr, "CGVirtualDisplay API not available\n");
        return 2;
    }
    CGVirtualDisplayDescriptor *descriptor = [[descriptorClass alloc] init];
    descriptor.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    descriptor.name = @"DockLock E2E Display";
    descriptor.maxPixelsWide = 1920;
    descriptor.maxPixelsHigh = 1080;
    descriptor.sizeInMillimeters = CGSizeMake(527, 296);
    descriptor.productID = 0x1234;
    descriptor.vendorID = 0x3456;
    descriptor.serialNum = 0x0001;
    descriptor.whitePoint = CGPointMake(0.3125, 0.3291);
    descriptor.redPrimary = CGPointMake(0.6797, 0.3203);
    descriptor.greenPrimary = CGPointMake(0.2559, 0.6983);
    descriptor.bluePrimary = CGPointMake(0.1494, 0.0557);

    CGVirtualDisplay *display = [[displayClass alloc] initWithDescriptor:descriptor];
    if (!display) {
        fprintf(stderr, "could not create virtual display\n");
        return 3;
    }
    CGVirtualDisplaySettings *settings = [[settingsClass alloc] init];
    settings.hiDPI = 0;
    settings.modes = @[[[modeClass alloc] initWithWidth:1920 height:1080 refreshRate:60]];
    if (![display applySettings:settings]) {
        fprintf(stderr, "applySettings failed\n");
        return 4;
    }
    CGDirectDisplayID vid = display.displayID;
    printf("created %u\n", vid);
    fflush(stdout);
    sleep(2);

    // Put it to the right of the main display, top-aligned, so both bottom edges are free.
    CGRect main = CGDisplayBounds(CGMainDisplayID());
    CGDisplayConfigRef config;
    if (CGBeginDisplayConfiguration(&config) == kCGErrorSuccess) {
        CGConfigureDisplayOrigin(config, vid, (int32_t)main.size.width, 0);
        CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
    }
    sleep(2);
    printDisplays();
    printf("ready\n");
    fflush(stdout);
    // Keep the display alive until killed.
    while (1) { CFRunLoopRunInMode(kCFRunLoopDefaultMode, 60, false); }
    (void)display;
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) { fprintf(stderr, "usage: e2e_tool vdisplay|displays|post x y|where|dock\n"); return 1; }
        NSString *cmd = @(argv[1]);
        if ([cmd isEqualToString:@"vdisplay"]) return makeVirtualDisplay();
        if ([cmd isEqualToString:@"displays"]) { printDisplays(); return 0; }
        if ([cmd isEqualToString:@"where"]) { CGPoint p = pointer(); printf("%.1f %.1f\n", p.x, p.y); return 0; }
        if ([cmd isEqualToString:@"post"] && argc >= 4) {
            CGPoint target = CGPointMake(atof(argv[2]), atof(argv[3]));
            for (int i = 0; i < 3; i++) {
                CGEventRef move = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, target, kCGMouseButtonLeft);
                CGEventPost(kCGHIDEventTap, move);
                CFRelease(move);
                usleep(80000);
            }
            usleep(200000);
            CGPoint p = pointer();
            printf("%.1f %.1f\n", p.x, p.y);
            return 0;
        }
        if ([cmd isEqualToString:@"windows"] && argc >= 3) {
            // Window numbers of on-screen windows owned by a process name (largest first).
            NSArray *list = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
            NSMutableArray *matches = [NSMutableArray array];
            for (NSDictionary *w in list) {
                if (![w[(id)kCGWindowOwnerName] isEqualToString:@(argv[2])]) continue;
                if ([w[(id)kCGWindowLayer] intValue] != 0) continue;
                CGRect b; CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)w[(id)kCGWindowBounds], &b);
                [matches addObject:@[w[(id)kCGWindowNumber], @(b.size.width * b.size.height)]];
            }
            [matches sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [b[1] compare:a[1]]; }];
            for (NSArray *m in matches) printf("%d\n", [m[0] intValue]);
            return 0;
        }
        if ([cmd isEqualToString:@"dock"]) {
            typedef void (*GetRect)(CGRect *);
            GetRect getRect = (GetRect)dlsym(RTLD_DEFAULT, "CoreDockGetRect");
            if (!getRect) { printf("unavailable\n"); return 0; }
            CGRect r; getRect(&r);
            printf("%.0f %.0f %.0f %.0f\n", r.origin.x, r.origin.y, r.size.width, r.size.height);
            return 0;
        }
        fprintf(stderr, "unknown command\n");
        return 1;
    }
}
