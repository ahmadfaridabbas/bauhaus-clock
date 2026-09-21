#import "../src/BauhausHandsView.m"
int main() { @autoreleasepool {
    [NSApplication sharedApplication];
    BauhausHandsView *view = [[BauhausHandsView alloc] initWithFrame:NSMakeRect(0,0,360,360) isPreview:YES];
    view.preferences = [ScreenSaverDefaults defaultsForModuleWithName:@"local.bauhaus.hands.qa"];
    [view.preferences registerDefaults:@{@"ClockTheme":@"dark", @"ClockColor":@"00B3FF", @"LumeColor":@"00E5ED", @"ClockScale":@1, @"SecondHand":@YES}];
    NSWindow *sheet = [view configureSheet];
    NSCAssert(sheet && view.handControls.count == 3, @"Missing controls");
    [view.handControls[0] selectItemAtIndex:3];
    [view.handControls[1] selectItemAtIndex:4];
    [view.handControls[2] selectItemAtIndex:5];
    [view updateSettingsPreview:nil];
    NSCAssert(view.settingsPreview.hourStyle==3 && view.settingsPreview.minuteStyle==4 && view.settingsPreview.secondStyle==5,@"Preview mismatch");
    [view saveSettings:nil];
    [view loadPreferences];
    NSCAssert(view.hourStyle==3 && view.minuteStyle==4 && view.secondStyle==5,@"Persistence mismatch");
    [view configureSheet]; [view.handControls[0] selectItemAtIndex:1]; [view cancelSettings:nil]; [view loadPreferences];
    NSCAssert(view.hourStyle==3,@"Cancel persisted changes");
    [view configureSheet]; [view resetSettings:nil];
    NSCAssert(view.handControls[0].indexOfSelectedItem==2 && view.handControls[2].indexOfSelectedItem==5,@"Reset mismatch");
    [view cancelSettings:nil];
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(1080,780)];
    [image lockFocus];
    [[NSColor colorWithWhite:.08 alpha:1] setFill]; NSRectFill(NSMakeRect(0,0,1080,780));
    NSArray *names=@[@"Original",@"Baton",@"Dauphine",@"Leaf",@"Sword",@"Needle"];
    for (int i=0;i<6;i++) {
        CGFloat x=(i%3)*360, y=(1-i/3)*390;
        view.hourStyle=i; view.minuteStyle=i; view.secondStyle=i;
        view.nightMode=YES; view.clockScale=1; view.glowAmount=.2;
        NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
        [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
        [rep drawInRect:NSMakeRect(x,y+30,360,360)];
        [names[i] drawAtPoint:NSMakePoint(x+140,y+8) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:17],NSForegroundColorAttributeName:NSColor.whiteColor}];
    }
    [image unlockFocus];
    NSBitmapImageRep *out=[[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
    [[out representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@"tests/hand-styles.png" atomically:YES];
    for (NSString *key in @[@"HourStyle",@"MinuteStyle",@"SecondStyle",@"ClockColor",@"Palette",@"ClockTheme",@"DialStyle",@"MovementStyle",@"RotatedMinutes",@"LumeColor",@"DigitStyle",@"FontStyle",@"OuterNumbers",@"SecondHand",@"GlowAmount",@"ClockScale"]) [view.preferences removeObjectForKey:key];
    [view.preferences synchronize];
    NSLog(@"PASS: controls, preview, persistence, cancel, reset, reopen, six renders");
} return 0; }
