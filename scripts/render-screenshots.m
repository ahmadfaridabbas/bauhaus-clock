// Uses a temporary source copy with a fixed display time; the shipped clock uses real time.
#import "ScreenshotClock.m"
static void Render(NSString *name, NSInteger dial, BOOL night, NSInteger hour, NSInteger minute, NSInteger second, NSInteger digits, NSInteger font, BOOL outer, NSInteger width, NSInteger height) {
    BauhausHandsView *view=[[BauhausHandsView alloc] initWithFrame:NSMakeRect(0,0,width,height) isPreview:YES];
    view.dialStyle=dial; view.nightMode=night; view.hourStyle=hour; view.minuteStyle=minute; view.secondStyle=second;
    view.digitStyle=digits; view.fontStyle=font; view.outerNumbers=outer; view.rotatedMinutes=NO;
    view.secondHand=YES; view.glowAmount=.18; view.clockScale=.94;
    view.clockColor=ColorFromHex(night ? @"00B3FF" : @"0074AD"); view.lumeColor=ColorFromHex(@"00E5ED");
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    [view drawRect:view.bounds];
    [NSGraphicsContext restoreGraphicsState];
    NSData *jpg=[bitmap representationUsingType:NSBitmapImageFileTypeJPEG properties:@{NSImageCompressionFactor:@.92}];
    NSString *path=[@"docs/assets/" stringByAppendingFormat:@"%@.jpg",name];
    if (![jpg writeToFile:path atomically:YES]) { NSLog(@"Could not write %@",path); exit(1); }
}
int main() { @autoreleasepool {
    [NSApplication sharedApplication];
    [[NSFileManager defaultManager] createDirectoryAtPath:@"docs/assets" withIntermediateDirectories:YES attributes:nil error:nil];
    Render(@"hero",10,YES,2,2,5,0,0,YES,1600,1000);
    NSArray *styles=@[@"original",@"baton",@"dauphine",@"leaf",@"sword",@"needle"];
    for (NSInteger i=0;i<6;i++) Render([@"style-" stringByAppendingString:styles[i]],0,YES,i,i,i,0,0,NO,720,720);
    Render(@"turquoise",2,NO,1,1,5,0,1,YES,1000,800);
    Render(@"ivory",8,NO,3,3,5,1,2,NO,1000,800);
    Render(@"ocean",4,NO,4,4,5,2,0,YES,1000,800);
    Render(@"rose",6,NO,2,2,5,0,1,NO,1000,800);
    Render(@"noir",10,YES,2,2,5,0,0,YES,1000,800);
    Render(@"white",1,NO,1,1,5,3,0,NO,1000,800);
    NSLog(@"Rendered 13 native clock images.");
} return 0; }
