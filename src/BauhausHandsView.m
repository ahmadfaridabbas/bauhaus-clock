//
//  BauhausHandsView.m
//  BauhausClock
//
//  Created by Aryan on 10/14/25.
//

#import "BauhausHandsView.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#pragma mark - 🌈 Global Theme Configuration (All Hex-Based)

// === ACCENT COLOR (applies globally) ===
static NSString *const kAccentHex = @"00b3ff"; // alternatives: #00b3ff, 00bbff

// === LIGHT MODE COLORS ===
static NSString *const kLightBackgroundHex = @"F5F3EE";

// === DARK MODE COLORS ===
static NSString *const kDarkBackgroundHex  = @"000000";

// Palette popup titles.
static NSArray *PaletteTitles(void) {
    return @[@"Custom", @"Azure", @"Coral", @"Amber", @"Mint", @"Lavender", @"Rose", @"Ocean", @"Monochrome"];
}

// === Helper: Convert HEX → NSColor ===
static NSColor *ColorFromHex(NSString *hex) {
    NSString *clean = [[hex stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([clean hasPrefix:@"#"]) clean = [clean substringFromIndex:1];
    
    unsigned int rgbValue = 0;
    [[NSScanner scannerWithString:clean] scanHexInt:&rgbValue];
    
    return [NSColor colorWithCalibratedRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                                     green:((rgbValue & 0x00FF00) >> 8) / 255.0
                                      blue:(rgbValue & 0x0000FF) / 255.0
                                     alpha:1.0];
}

// A small, deterministic tile is generated once and reused at every frame.
// Fine grain and sparse fibres give the dial a matte paper finish without assets.
static NSColor *PaperGrain(void) {
    static NSColor *pattern;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const NSInteger side = 384;
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:side pixelsHigh:side
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace
            bitmapFormat:NSBitmapFormatAlphaNonpremultiplied bytesPerRow:side*4 bitsPerPixel:32];
        uint32_t seed = 0xBADA551;
        unsigned char *pixels = bitmap.bitmapData;
        for (NSInteger y=0; y<side; y++) for (NSInteger x=0; x<side; x++) {
            seed = seed * 1664525u + 1013904223u;
            unsigned char *pixel = pixels + y*bitmap.bytesPerRow + x*4;
            BOOL light = (seed >> 31) != 0;
            pixel[0] = pixel[1] = pixel[2] = light ? 255 : 0;
            pixel[3] = 3 + ((seed >> 20) % 12);
            // Occasional short fibres remain low contrast and tile seamlessly.
            if ((seed & 1023) < 5) {
                for (NSInteger k=0; k<3; k++) {
                    unsigned char *fibre = pixels + y*bitmap.bytesPerRow + ((x+side-k)%side)*4;
                    fibre[0] = fibre[1] = fibre[2] = light ? 255 : 0;
                    fibre[3] = 17;
                }
            }
        }
        NSImage *tile = [[NSImage alloc] initWithSize:NSMakeSize(side, side)];
        [tile addRepresentation:bitmap];
        pattern = [NSColor colorWithPatternImage:tile];
    });
    return pattern;
}

static NSArray *DialNames(void) { return @[@"Original", @"White", @"Turquoise", @"Glacier", @"Ocean", @"Tennis", @"Rose", @"Sky", @"Ivory", @"Graphite", @"Noir"]; }
static NSArray *DialBackgrounds(void) { return @[@"F5F3EE", @"FAFAF8", @"B2EFEC", @"B5CED7", @"103755", @"008A58", @"F5BCD0", @"B6E4FA", @"E7E3D7", @"45494E", @"090A0B"]; }
static NSArray *DialInks(void) { return @[@"303238", @"343B3E", @"00616B", @"305E70", @"7EF4E8", @"CEFF54", @"823D57", @"245F85", @"64645B", @"E2E7E8", @"E5E8E8"]; }
static NSArray *LumeColors(void) { return @[@"FF4949", @"FFAA20", @"AE9CFF", @"FF9CC7", @"8EDBC4", @"58D8FF", @"00E5ED", @"FFD1A1", @"70FF48", @"00E5AD", @"FFF147", @"EAFBFF"]; }

@interface BauhausHandsOptionsWindow : NSWindow
@end
@implementation BauhausHandsOptionsWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface HandsClockSwatch : NSButton
@property (strong) NSColor *swatchColor;
@property (strong) NSColor *inkColor;
@property BOOL dial;
@end
@implementation HandsClockSwatch
- (void)drawRect:(NSRect)dirtyRect {
    NSRect circle = NSInsetRect(self.bounds, 5, 5);
    [self.swatchColor setFill]; [[NSBezierPath bezierPathWithOvalInRect:circle] fill];
    if (self.dial) {
        NSPoint c = NSMakePoint(NSMidX(circle), NSMidY(circle));
        [self.inkColor setStroke];
        NSBezierPath *hands = [NSBezierPath bezierPath]; hands.lineWidth = 2;
        [hands moveToPoint:NSMakePoint(c.x-9,c.y+8)]; [hands lineToPoint:c];
        [hands lineToPoint:NSMakePoint(c.x+10,c.y+13)]; [hands stroke];
    }
    if (self.state == NSControlStateValueOn) {
        [NSColor.labelColor setStroke]; NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(self.bounds, 1.5, 1.5)];
        ring.lineWidth = 2.5; [ring stroke];
    }
}
@end

#pragma mark - 🕰️ BauhausHandsView Implementation

@interface BauhausHandsView ()
@property (nonatomic, assign) BOOL nightMode;
@property (nonatomic, strong) NSColor *clockColor;
@property (nonatomic, strong) ScreenSaverDefaults *preferences;
@property (nonatomic, strong) NSWindow *settingsWindow;
@property (nonatomic, strong) NSPopUpButton *themeControl;
@property (nonatomic, strong) NSColorWell *colorControl;
@property (nonatomic, strong) BauhausHandsView *settingsPreview;
@property NSTimeInterval lastPreferencesRefresh;
@property NSInteger appearanceMode;
@property NSInteger dialStyle;
@property NSInteger movementStyle;
@property NSInteger hourStyle;
@property NSInteger minuteStyle;
@property NSInteger secondStyle;
@property (strong) NSArray<NSPopUpButton *> *handControls;
@property BOOL rotatedMinutes;
@property (strong) NSColor *lumeColor;
@property (strong) NSSegmentedControl *appearanceControl;
@property (strong) NSSegmentedControl *movementControl;
@property (strong) NSSegmentedControl *sizeControl;
@property (strong) NSColorWell *lumeControl;
@property (strong) NSButton *rotationControl;
@property (strong) NSMutableArray *dialButtons;
@property (strong) NSMutableArray *lumeButtons;
@property (strong) NSTimer *previewTimer;
@property NSInteger digitStyle;
@property NSInteger fontStyle;
@property BOOL outerNumbers;
@property BOOL secondHand;
@property CGFloat glowAmount;
@property CGFloat clockScale;
@property (nonatomic, strong) NSPopUpButton *digitsControl;
@property (nonatomic, strong) NSPopUpButton *fontControl;
@property (nonatomic, strong) NSPopUpButton *paletteControl;
@property (nonatomic, strong) NSButton *outerControl;
@property (nonatomic, strong) NSButton *secondControl;
@property (nonatomic, strong) NSSlider *glowControl;
@property (nonatomic, strong) NSSlider *scaleControl;
@property (nonatomic, assign) NSInteger lastSecond; // PERF: Track last rendered second to avoid unnecessary redraws
@end

@implementation BauhausHandsView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        // PERF: Reduced from 1.0/60.0 (60fps) to 1.0/30.0 (30fps)
        // 30fps is smooth enough for a clock and uses 50% less CPU
        [self setAnimationTimeInterval:1.0/60.0];
        _preferences = [ScreenSaverDefaults defaultsForModuleWithName:@"local.bauhaus.hands"];
        [_preferences registerDefaults:@{@"ClockTheme": @"dark", @"ClockColor": @"00B3FF", @"DigitStyle": @0, @"FontStyle": @0, @"OuterNumbers": @YES, @"SecondHand": @YES, @"GlowAmount": @0.4, @"ClockScale": @1.0, @"DialStyle": @0, @"MovementStyle": @2, @"LumeColor": @"00E5ED", @"RotatedMinutes": @NO, @"HourStyle": @2, @"MinuteStyle": @2, @"SecondStyle": @5}];
        [self loadPreferences];
        _lastSecond = -1; // PERF: Initialize to invalid value
    }
    return self;
}

- (void)loadPreferences {
    [self.preferences synchronize];
    self.lastPreferencesRefresh = [NSDate timeIntervalSinceReferenceDate];
    NSString *theme = [self.preferences stringForKey:@"ClockTheme"];
    self.appearanceMode = [theme isEqualToString:@"system"] ? 2 : ([theme isEqualToString:@"light"] ? 0 : 1);
    self.dialStyle = MAX(0, MIN(10, [self.preferences integerForKey:@"DialStyle"]));
    self.movementStyle = MAX(0, MIN(2, [self.preferences integerForKey:@"MovementStyle"]));
    self.hourStyle = MAX(0, MIN(5, [self.preferences integerForKey:@"HourStyle"]));
    self.minuteStyle = MAX(0, MIN(5, [self.preferences integerForKey:@"MinuteStyle"]));
    self.secondStyle = MAX(0, MIN(5, [self.preferences integerForKey:@"SecondStyle"]));
    self.rotatedMinutes = [self.preferences boolForKey:@"RotatedMinutes"];
    self.lumeColor = ColorFromHex([self.preferences stringForKey:@"LumeColor"]);
    [self resolveAppearance];
    self.clockColor = ColorFromHex([self.preferences stringForKey:@"ClockColor"] ?: kAccentHex);
    self.digitStyle = MAX(0, MIN(3, [self.preferences integerForKey:@"DigitStyle"]));
    self.fontStyle = MAX(0, MIN(3, [self.preferences integerForKey:@"FontStyle"]));
    self.outerNumbers = [self.preferences boolForKey:@"OuterNumbers"];
    self.secondHand = [self.preferences boolForKey:@"SecondHand"];
    self.glowAmount = MAX(0, MIN(1, [self.preferences doubleForKey:@"GlowAmount"]));
    self.clockScale = MAX(0.65, MIN(1, [self.preferences doubleForKey:@"ClockScale"]));
}

- (void)resolveAppearance {
    self.nightMode = self.appearanceMode == 1 || (self.appearanceMode == 2 &&
        [[self.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua]);
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self resolveAppearance]; [self setNeedsDisplay:YES]; }

- (void)dealloc { [self.previewTimer invalidate]; }

- (void)startAnimation {
    [self loadPreferences];
    [super startAnimation];
}

- (BOOL)hasConfigureSheet { return YES; }

- (void)addLabel:(NSString *)text y:(CGFloat)y to:(NSView *)content {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = NSMakeRect(390, y + 3, 105, 22);
    [content addSubview:label];
}

- (NSPopUpButton *)popup:(NSArray *)items y:(CGFloat)y label:(NSString *)label {
    NSView *content = self.settingsWindow.contentView;
    [self addLabel:label y:y to:content];
    NSPopUpButton *control = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(498, y, 238, 28) pullsDown:NO];
    [control addItemsWithTitles:items];
    control.target = self; control.action = @selector(updateSettingsPreview:);
    [control setAccessibilityLabel:label];
    [content addSubview:control];
    return control;
}

- (NSWindow *)configureSheet {
    // System Settings remotely hosts the content in the legacyScreenSaver
    // process and calls -beginSheet: on the window we return. On macOS Tahoe a
    // reused window whose previous sheet session was never torn down triggers
    // "cannot begin sheet a second time", which silently swallows the Options
    // click. We therefore discard the window AND every cached control from the
    // prior session, so each presentation builds a pristine, never-presented
    // window. Any leftover controls would otherwise reference a dead view tree.
    [self.previewTimer invalidate];
    self.previewTimer = nil;
    [self.colorControl deactivate];
    [self.lumeControl deactivate];
    if (self.settingsWindow) {
        [self.settingsWindow orderOut:nil];
    }
    self.handControls = nil;
    self.settingsWindow = nil;
    self.settingsPreview = nil;
    self.appearanceControl = nil;
    self.movementControl = nil;
    self.sizeControl = nil;
    self.rotationControl = nil;
    self.lumeControl = nil;
    self.themeControl = nil;
    self.paletteControl = nil;
    self.colorControl = nil;
    self.digitsControl = nil;
    self.fontControl = nil;
    self.outerControl = nil;
    self.secondControl = nil;
    self.glowControl = nil;
    self.scaleControl = nil;
    self.dialButtons = nil;
    self.lumeButtons = nil;

    if (!self.settingsWindow) {
        self.settingsWindow = [[BauhausHandsOptionsWindow alloc] initWithContentRect:NSMakeRect(0, 0, 760, 560)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        self.settingsWindow.title = @"Bauhaus Hands Options";
        self.settingsWindow.releasedWhenClosed = NO;
        NSView *content = self.settingsWindow.contentView;
        NSTextField *title = [NSTextField labelWithString:@"Make it your clock"];
        title.font = [NSFont boldSystemFontOfSize:22];
        title.frame = NSMakeRect(24, 505, 700, 30);
        [content addSubview:title];
        NSTextField *subtitle = [NSTextField labelWithString:@"A familiar face, with your own finishing touches."];
        subtitle.textColor = NSColor.secondaryLabelColor;
        subtitle.frame = NSMakeRect(24, 478, 710, 22);
        [content addSubview:subtitle];
        self.settingsPreview = [[BauhausHandsView alloc] initWithFrame:NSMakeRect(24, 125, 340, 340) isPreview:YES];
        [content addSubview:self.settingsPreview];
        NSTextField *hint = [NSTextField wrappingLabelWithString:@"Preview updates as you choose. Save to apply your look."];
        hint.textColor = NSColor.secondaryLabelColor;
        hint.frame = NSMakeRect(24, 75, 340, 38);
        [content addSubview:hint];
        self.themeControl = [self popup:@[@"Dark", @"Light"] y:429 label:@"Theme"];
        self.paletteControl = [self popup:PaletteTitles() y:387 label:@"Palette"];
        [self addLabel:@"Clock color" y:345 to:content];
        self.colorControl = [[NSColorWell alloc] initWithFrame:NSMakeRect(498, 345, 238, 28)];
        self.colorControl.target = self; self.colorControl.action = @selector(updateSettingsPreview:);
        [self.colorControl setAccessibilityLabel:@"Custom clock color"];
        [content addSubview:self.colorControl];
        self.digitsControl = [self popup:@[@"Arabic · 1, 2, 3", @"Roman · I, II, III", @"Quarter hours · 12, 3, 6, 9", @"None"] y:291 label:@"Digits"];
        self.fontControl = [self popup:@[@"Classic", @"Rounded", @"Serif", @"Monospaced"] y:249 label:@"Typography"];
        self.outerControl = [NSButton checkboxWithTitle:@"Outer minute numbers" target:self action:@selector(updateSettingsPreview:)];
        self.outerControl.frame = NSMakeRect(390, 210, 346, 24); [content addSubview:self.outerControl];
        self.secondControl = [NSButton checkboxWithTitle:@"Show second hand" target:self action:@selector(updateSettingsPreview:)];
        self.secondControl.frame = NSMakeRect(390, 178, 346, 24); [content addSubview:self.secondControl];
        [self addLabel:@"Glow" y:133 to:content];
        self.glowControl = [NSSlider sliderWithValue:0.4 minValue:0 maxValue:1 target:self action:@selector(updateSettingsPreview:)];
        self.glowControl.frame = NSMakeRect(498, 133, 238, 24);
        [self.glowControl setAccessibilityLabel:@"Glow intensity"]; [content addSubview:self.glowControl];
        [self addLabel:@"Clock size" y:95 to:content];
        self.scaleControl = [NSSlider sliderWithValue:1 minValue:0.65 maxValue:1 target:self action:@selector(updateSettingsPreview:)];
        self.scaleControl.frame = NSMakeRect(498, 95, 238, 24);
        [self.scaleControl setAccessibilityLabel:@"Clock size"]; [content addSubview:self.scaleControl];
        NSButton *reset = [NSButton buttonWithTitle:@"Reset appearance" target:self action:@selector(resetSettings:)];
        reset.frame = NSMakeRect(24, 22, 160, 32); [content addSubview:reset];
        NSButton *cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelSettings:)];
        cancel.frame = NSMakeRect(544, 22, 90, 32); cancel.keyEquivalent = @"\e"; [content addSubview:cancel];
        NSButton *save = [NSButton buttonWithTitle:@"Save" target:self action:@selector(saveSettings:)];
        save.frame = NSMakeRect(640, 22, 96, 32); save.keyEquivalent = @"\r"; [content addSubview:save];
    }
    if (!self.appearanceControl) {
        NSView *content = self.settingsWindow.contentView;
        [self.settingsWindow setContentSize:NSMakeSize(900, 720)];
        for (NSView *view in [content.subviews copy]) {
            NSRect frame = view.frame;
            if (frame.origin.y > 50) frame.origin.y += 160;
            if (frame.origin.x >= 390) frame.origin.x += 140;
            view.frame = frame;
            if ([view isKindOfClass:NSTextField.class] && [[(NSTextField *)view stringValue] hasPrefix:@"Preview updates"]) view.hidden=YES;
        }
        self.settingsPreview.frame = NSMakeRect(24, 395, 470, 230);
        NSMutableArray *handControls = [NSMutableArray array];
        NSArray *handLabels = @[@"Hour hand", @"Minute hand", @"Second hand"];
        for (NSInteger i=0; i<3; i++) {
            CGFloat y = 355 - i*34;
            NSTextField *label = [NSTextField labelWithString:handLabels[i]];
            label.frame = NSMakeRect(24, y+4, 110, 22); [content addSubview:label];
            NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, y, 354, 28) pullsDown:NO];
            [popup addItemsWithTitles:@[@"Original", @"Baton", @"Dauphine", @"Leaf", @"Sword", @"Needle"]];
            [popup setAccessibilityLabel:handLabels[i]];
            popup.target=self; popup.action=@selector(updateSettingsPreview:);
            [content addSubview:popup]; [handControls addObject:popup];
        }
        self.handControls = handControls;
        self.themeControl.hidden = YES;
        self.appearanceControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Day", @"Night", @"System"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(updateSettingsPreview:)];
        self.appearanceControl.frame = NSMakeRect(638, 589, 238, 28); [content addSubview:self.appearanceControl];
        self.movementControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Quartz", @"Mechanical", @"Smooth"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(updateSettingsPreview:)];
        self.movementControl.frame = NSMakeRect(24, 245, 470, 28); [content addSubview:self.movementControl];
        self.movementControl.toolTip = @"Quartz ticks once per second; Mechanical advances eight times per second; Smooth sweeps continuously.";
        self.sizeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Classic", @"Compact"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(updateSettingsPreview:)];
        self.sizeControl.frame = NSMakeRect(24, 205, 225, 28); [content addSubview:self.sizeControl];
        self.rotationControl = [NSButton checkboxWithTitle:@"Rotate outer numbers" target:self action:@selector(updateSettingsPreview:)];
        self.rotationControl.frame = NSMakeRect(270, 205, 240, 28); [content addSubview:self.rotationControl];
        self.dialButtons = [NSMutableArray array]; self.lumeButtons = [NSMutableArray array];
        for (NSInteger i=0; i<(NSInteger)DialNames().count; i++) {
            HandsClockSwatch *button = [[HandsClockSwatch alloc] initWithFrame:NSMakeRect(24+i*53, 134, 46, 46)];
            button.dial = YES; button.swatchColor = ColorFromHex(DialBackgrounds()[i]); button.inkColor = ColorFromHex(DialInks()[i]);
            button.tag=i; button.title=@""; button.toolTip=DialNames()[i]; [button setAccessibilityLabel:DialNames()[i]];
            button.target=self; button.action=@selector(selectDial:); [content addSubview:button]; [self.dialButtons addObject:button];
        }
        NSTextField *dialLabel=[NSTextField labelWithString:@"Clock dial"]; dialLabel.frame=NSMakeRect(638,145,238,24); [content addSubview:dialLabel];
        for (NSInteger i=0; i<(NSInteger)LumeColors().count; i++) {
            HandsClockSwatch *button = [[HandsClockSwatch alloc] initWithFrame:NSMakeRect(24+i*44, 76, 34, 34)];
            button.swatchColor=ColorFromHex(LumeColors()[i]); button.tag=i; button.title=@"";
            button.toolTip=@[@"Red",@"Amber",@"Lavender",@"Pink",@"Seafoam",@"Ice blue",@"Cyan",@"Peach",@"Lime",@"Mint",@"Yellow",@"White"][i];
            [button setAccessibilityLabel:[@"Lume: " stringByAppendingString:button.toolTip]];
            button.target=self; button.action=@selector(selectLume:); [content addSubview:button]; [self.lumeButtons addObject:button];
        }
        self.lumeControl=[[NSColorWell alloc] initWithFrame:NSMakeRect(568,78,48,30)]; self.lumeControl.target=self; self.lumeControl.action=@selector(updateSettingsPreview:);
        [self.lumeControl setAccessibilityLabel:@"Custom lume color"]; [content addSubview:self.lumeControl];
        NSTextField *lumeLabel=[NSTextField labelWithString:@"Lume color"]; lumeLabel.frame=NSMakeRect(638,82,238,24); [content addSubview:lumeLabel];
    }
    [self loadPreferences];
    self.appearanceControl.selectedSegment = self.appearanceMode;
    [self.handControls[0] selectItemAtIndex:self.hourStyle];
    [self.handControls[1] selectItemAtIndex:self.minuteStyle];
    [self.handControls[2] selectItemAtIndex:self.secondStyle];
    self.movementControl.selectedSegment = self.movementStyle;
    self.sizeControl.selectedSegment = self.clockScale < 0.9 ? 1 : 0;
    self.rotationControl.state = self.rotatedMinutes;
    self.lumeControl.color = self.lumeColor;
    [self.themeControl selectItemAtIndex:self.nightMode ? 0 : 1];
    [self.paletteControl selectItemAtIndex:MAX(0, MIN((NSInteger)PaletteTitles().count - 1, [self.preferences integerForKey:@"Palette"]))];
    self.colorControl.color = self.clockColor;
    [self.digitsControl selectItemAtIndex:self.digitStyle];
    [self.fontControl selectItemAtIndex:self.fontStyle];
    self.outerControl.state = self.outerNumbers;
    self.secondControl.state = self.secondHand;
    self.glowControl.doubleValue = self.glowAmount;
    self.scaleControl.doubleValue = self.clockScale;
    [self updateSettingsPreview:nil];
    [self.previewTimer invalidate];
    __weak BauhausHandsView *weakSelf = self;
    self.previewTimer = [NSTimer timerWithTimeInterval:1.0/30.0 repeats:YES block:^(NSTimer *timer) { [weakSelf.settingsPreview setNeedsDisplay:YES]; }];
    [[NSRunLoop mainRunLoop] addTimer:self.previewTimer forMode:NSRunLoopCommonModes];
    return self.settingsWindow;
}

- (void)selectDial:(NSButton *)sender { self.dialStyle=sender.tag; [self updateSettingsPreview:sender]; }
- (void)selectLume:(NSButton *)sender { self.lumeControl.color=ColorFromHex(LumeColors()[sender.tag]); [self updateSettingsPreview:sender]; }

- (void)resetSettings:(id)sender {
    [self.handControls[0] selectItemAtIndex:2];
    [self.handControls[1] selectItemAtIndex:2];
    [self.handControls[2] selectItemAtIndex:5];
    self.appearanceControl.selectedSegment=1; self.movementControl.selectedSegment=2;
    self.sizeControl.selectedSegment=0; self.dialStyle=0; self.rotationControl.state=NSControlStateValueOff;
    self.lumeControl.color=ColorFromHex(@"00E5ED");
    [self.themeControl selectItemAtIndex:0]; [self.paletteControl selectItemAtIndex:1];
    [self.digitsControl selectItemAtIndex:0]; [self.fontControl selectItemAtIndex:0];
    self.outerControl.state = NSControlStateValueOn; self.secondControl.state = NSControlStateValueOn;
    self.glowControl.doubleValue = 0.4; self.scaleControl.doubleValue = 1;
    [self updateSettingsPreview:self.paletteControl];
}

- (void)updateSettingsPreview:(id)sender {
    if (sender == self.colorControl) [self.paletteControl selectItemAtIndex:0];
    NSInteger palette = self.paletteControl.indexOfSelectedItem;
    self.settingsPreview.appearanceMode=self.appearanceControl.selectedSegment;
    [self.settingsPreview resolveAppearance];
    BOOL dark = self.settingsPreview.nightMode;
    if (sender == self.sizeControl) self.scaleControl.doubleValue=self.sizeControl.selectedSegment == 0 ? 1 : 0.75;
    if (sender == self.scaleControl) self.sizeControl.selectedSegment=-1;
    if (palette > 0 && (sender == self.paletteControl || sender == self.appearanceControl)) {
        NSArray *colors = dark ? @[@"00B3FF", @"FF756B", @"FFC857", @"71DDB1", @"B6A0FF", @"FF9FCB", @"58D6DE", @"EAE7E0"]
                               : @[@"0074AD", @"BC4039", @"936000", @"187451", @"7050B5", @"AE396C", @"006E79", @"303238"];
        self.colorControl.color = ColorFromHex(colors[palette - 1]);
    }
    BauhausHandsView *preview = self.settingsPreview;
    preview.nightMode = dark;

    self.paletteControl.enabled = self.dialStyle == 0;
    self.colorControl.enabled = self.dialStyle == 0;
    self.colorControl.toolTip = @"Clock color and palette apply to the Original dial. Other dials use coordinated face colors and the separate lume color.";
    preview.dialStyle=self.dialStyle; preview.movementStyle=self.movementControl.selectedSegment;
    preview.rotatedMinutes=self.rotationControl.state == NSControlStateValueOn;
    preview.lumeColor=[self.lumeControl.color colorWithAlphaComponent:1];
    for (NSButton *button in self.dialButtons) { button.state=button.tag == self.dialStyle; [button setNeedsDisplay:YES]; }
    for (NSButton *button in self.lumeButtons) { button.state=[ColorFromHex(LumeColors()[button.tag]) isEqual:self.lumeControl.color]; [button setNeedsDisplay:YES]; }
    preview.clockColor = [self.colorControl.color colorWithAlphaComponent:1.0];
    preview.digitStyle = self.digitsControl.indexOfSelectedItem;
    preview.fontStyle = self.fontControl.indexOfSelectedItem;
    preview.outerNumbers = self.outerControl.state == NSControlStateValueOn;
    preview.hourStyle = self.handControls[0].indexOfSelectedItem;
    preview.minuteStyle = self.handControls[1].indexOfSelectedItem;
    preview.secondStyle = self.handControls[2].indexOfSelectedItem;
    self.handControls[2].enabled = self.secondControl.state == NSControlStateValueOn;
    preview.secondHand = self.secondControl.state == NSControlStateValueOn;
    preview.glowAmount = self.glowControl.doubleValue;
    preview.clockScale = self.scaleControl.doubleValue;
    self.fontControl.enabled = preview.digitStyle != 3 || preview.outerNumbers;
    [preview setNeedsDisplay:YES];
}

- (void)closeSettings {
    [self.previewTimer invalidate]; self.previewTimer=nil;
    [self.colorControl deactivate]; [self.lumeControl deactivate];
    NSWindow *sheet = self.settingsWindow;
    // The host process owns the modal session. End it on the window that
    // actually presented the sheet (its sheetParent) using the modern API so
    // the host's sheet state is cleared and Options can be reopened later. Fall
    // back to the legacy NSApp path and a plain orderOut: if no parent exists.
    NSWindow *parent = sheet.sheetParent;
    if (parent) {
        [parent endSheet:sheet];
    } else {
        [NSApp endSheet:sheet];
    }
    [sheet orderOut:nil];
}

- (void)cancelSettings:(id)sender { [self closeSettings]; }

- (void)saveSettings:(id)sender {
    NSColor *color = [self.colorControl.color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!color) return;
    NSString *hex = [NSString stringWithFormat:@"%02X%02X%02X",
        (unsigned int)lround(color.redComponent * 255),
        (unsigned int)lround(color.greenComponent * 255),
        (unsigned int)lround(color.blueComponent * 255)];
    [self.preferences setObject:hex forKey:@"ClockColor"];
    [self.preferences setInteger:self.paletteControl.indexOfSelectedItem forKey:@"Palette"];
    [self.preferences setObject:@[@"light", @"dark", @"system"][self.appearanceControl.selectedSegment] forKey:@"ClockTheme"];
    [self.preferences setInteger:self.handControls[0].indexOfSelectedItem forKey:@"HourStyle"];
    [self.preferences setInteger:self.handControls[1].indexOfSelectedItem forKey:@"MinuteStyle"];
    [self.preferences setInteger:self.handControls[2].indexOfSelectedItem forKey:@"SecondStyle"];
    [self.preferences setInteger:self.dialStyle forKey:@"DialStyle"];
    [self.preferences setInteger:self.movementControl.selectedSegment forKey:@"MovementStyle"];
    [self.preferences setBool:self.rotationControl.state == NSControlStateValueOn forKey:@"RotatedMinutes"];
    NSColor *lume=[self.lumeControl.color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    [self.preferences setObject:[NSString stringWithFormat:@"%02X%02X%02X",(int)lround(lume.redComponent*255),(int)lround(lume.greenComponent*255),(int)lround(lume.blueComponent*255)] forKey:@"LumeColor"];
    [self.preferences setInteger:self.digitsControl.indexOfSelectedItem forKey:@"DigitStyle"];
    [self.preferences setInteger:self.fontControl.indexOfSelectedItem forKey:@"FontStyle"];
    [self.preferences setBool:self.outerControl.state == NSControlStateValueOn forKey:@"OuterNumbers"];
    [self.preferences setBool:self.secondControl.state == NSControlStateValueOn forKey:@"SecondHand"];
    [self.preferences setDouble:self.glowControl.doubleValue forKey:@"GlowAmount"];
    [self.preferences setDouble:self.scaleControl.doubleValue forKey:@"ClockScale"];
    [self.preferences synchronize];
    [self loadPreferences];
    [self setNeedsDisplay:YES];
    [self closeSettings];
}

- (void)setNightMode:(BOOL)enabled {
    _nightMode = enabled;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    // PERF: Enable anti-aliasing for optimal rendering
    CGContextSetShouldAntialias(ctx, YES);
    CGContextSetAllowsAntialiasing(ctx, YES);
    
    // === COLOR SELECTION ===
    NSColor *accent = self.clockColor ?: ColorFromHex(kAccentHex);
    NSColor *bg, *tickColor, *textColor;
    
    if (self.nightMode) {
        bg        = ColorFromHex(kDarkBackgroundHex);
        tickColor = [accent colorWithAlphaComponent:0.85];
        textColor = accent;
    } else {
        bg        = ColorFromHex(kLightBackgroundHex);
        tickColor = [accent colorWithAlphaComponent:0.35];
        textColor = accent;
    }
    
    if (self.dialStyle > 0) {
        bg = self.nightMode ? ColorFromHex(self.dialStyle == 10 ? @"050607" : @"101416") : ColorFromHex(DialBackgrounds()[self.dialStyle]);
        accent = self.lumeColor;
        textColor = self.nightMode ? self.lumeColor : ColorFromHex(DialInks()[self.dialStyle]);
        tickColor = [textColor colorWithAlphaComponent:0.8];
    }
    // === BACKGROUND ===
    [bg setFill];
    NSRectFill(rect);
    // Gentle light across the paper; no moving noise or distracting vignette.
    NSGradient *paperLight = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithWhite:1 alpha:self.dialStyle == 10 ? 0.012 : (self.nightMode ? 0.035 : 0.08)]
        endingColor:[NSColor colorWithWhite:0 alpha:self.nightMode ? 0.015 : 0.035]];
    [paperLight drawInRect:self.bounds angle:105];
    CGContextSaveGState(ctx);
    if (self.dialStyle == 10) CGContextSetAlpha(ctx, 0.45);
    [PaperGrain() setFill];
    NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
    CGContextRestoreGState(ctx);
    
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGPoint center = CGPointMake(width/2, height/2);
    CGFloat radius = MIN(width, height) * 0.4 * self.clockScale;
    
    // === TICKS ===
    for (int i = 0; i < 60; i++) {
        CGFloat angle = M_PI_2 - (i * M_PI / 30.0);
        BOOL isHourMark = (i % 5 == 0);
        
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, center.x, center.y);
        CGContextRotateCTM(ctx, -angle);
        
        if (isHourMark) {
            CGFloat w = radius * 0.035;
            CGFloat h = radius * 0.12;
            CGRect r = CGRectMake(-w/2, -radius, w, h);
            
            NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:r xRadius:w/2 yRadius:w/2];
            [NSGraphicsContext saveGraphicsState];
            
            // Glow
            NSShadow *glow = [[NSShadow alloc] init];
            glow.shadowColor = [accent colorWithAlphaComponent:self.glowAmount];
            glow.shadowBlurRadius = 40.0;
            glow.shadowOffset = NSZeroSize;
            [glow set];
            
            if (self.dialStyle > 0 && !self.nightMode) {
                NSGradient *metal=[[NSGradient alloc] initWithStartingColor:ColorFromHex(@"909C9F") endingColor:ColorFromHex(@"FFFFFF")];
                [metal drawInBezierPath:pill angle:0];
                NSBezierPath *inset=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r,w*0.25,w*0.25) xRadius:w/3 yRadius:w/3];
                [[accent blendedColorWithFraction:0.75 ofColor:NSColor.whiteColor] setFill]; [inset fill];
            } else { [accent setFill]; [pill fill]; }
            
            [bg setStroke];
            [pill setLineWidth:2.5];
            [pill stroke];
            
            [NSGraphicsContext restoreGraphicsState];
        } else {
            CGContextSetLineWidth(ctx, 1.0);
            CGContextSetStrokeColorWithColor(ctx, [tickColor colorWithAlphaComponent:0.4].CGColor);
            CGContextMoveToPoint(ctx, 0, -radius * 0.95);
            CGContextAddLineToPoint(ctx, 0, -radius);
            CGContextStrokePath(ctx);
        }
        
        CGContextRestoreGState(ctx);
    }

    // === FONTS ===
    NSFont *innerFont = [NSFont fontWithName:@"SF Pro Expanded Regular" size:radius * 0.14]
        ?: [NSFont systemFontOfSize:radius * 0.12 weight:NSFontWeightBold];
    NSFont *outerFont = [NSFont fontWithName:@"SF Pro Expanded Ultralight" size:radius * 0.08]
        ?: [NSFont systemFontOfSize:radius * 0.08];
    
    if (self.fontStyle == 1) {
        NSFontDescriptor *descriptor = [[NSFont systemFontOfSize:radius * 0.12 weight:NSFontWeightMedium].fontDescriptor fontDescriptorWithDesign:NSFontDescriptorSystemDesignRounded];
        innerFont = [NSFont fontWithDescriptor:descriptor size:radius * 0.12] ?: innerFont;
        outerFont = [NSFont fontWithDescriptor:descriptor size:radius * 0.08] ?: outerFont;
    } else if (self.fontStyle == 2) {
        innerFont = [NSFont fontWithName:@"Georgia" size:radius * 0.13] ?: innerFont;
        outerFont = [NSFont fontWithName:@"Georgia" size:radius * 0.08] ?: outerFont;
    } else if (self.fontStyle == 3) {
        innerFont = [NSFont monospacedSystemFontOfSize:radius * 0.12 weight:NSFontWeightMedium];
        outerFont = [NSFont monospacedSystemFontOfSize:radius * 0.08 weight:NSFontWeightRegular];
    }
    if (self.digitStyle == 1) innerFont = [NSFont fontWithDescriptor:innerFont.fontDescriptor size:radius * 0.105];
    NSDictionary *innerAttrs = @{
        NSFontAttributeName: innerFont,
        NSForegroundColorAttributeName: textColor
    };
    NSDictionary *outerAttrs = @{
        NSFontAttributeName: outerFont,
        NSForegroundColorAttributeName: [textColor colorWithAlphaComponent:0.5]
    };
    
    // === INNER NUMBERS ===
    for (int i = 1; i <= 12; i++) {
        if (self.digitStyle == 3 || (self.digitStyle == 2 && i % 3 != 0)) continue;
        CGFloat angle = M_PI_2 - (i * M_PI / 6.0);
        NSString *text = self.digitStyle == 1 ? @[@"I", @"II", @"III", @"IV", @"V", @"VI", @"VII", @"VIII", @"IX", @"X", @"XI", @"XII"][i-1] : [NSString stringWithFormat:@"%d", i];
        
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:innerAttrs];
        CGSize size = [str size];
        
        CGFloat r = radius * 0.74;
        CGPoint pos = CGPointMake(center.x + r * cos(angle) - size.width / 2,
                                  center.y + r * sin(angle) - size.height / 2);
        [str drawAtPoint:pos];
    }
    
    // === OUTER NUMBERS ===
    for (int i = 5; self.outerNumbers && i <= 60; i += 5) {
        CGFloat angle = M_PI_2 - ((i / 5.0) * M_PI / 6.0);
        NSString *text = [NSString stringWithFormat:@"%02d", i % 61];
        
        NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:outerAttrs];
        CGSize size = [str size];
        
        CGFloat r = radius * 1.12;
        CGPoint pos = CGPointMake(center.x + r * cos(angle) - size.width / 2,
                                  center.y + r * sin(angle) - size.height / 2);
        if (self.rotatedMinutes) {
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, pos.x+size.width/2, pos.y+size.height/2);
            CGContextRotateCTM(ctx, angle-M_PI_2);
            [str drawAtPoint:NSMakePoint(-size.width/2,-size.height/2)];
            CGContextRestoreGState(ctx);
        } else [str drawAtPoint:pos];
    }
    
    // === TIME ===
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitNanosecond)
                                               fromDate:date];

    // Keep nanosecond precision for smooth second hand animation
    CGFloat seconds = components.second + components.nanosecond / 1e9;
    if (self.movementStyle == 0) seconds=floor(seconds);
    else if (self.movementStyle == 1) seconds=floor(seconds*8)/8;
    CGFloat minutes = components.minute + seconds / 60.0;
    CGFloat hours = fmod(components.hour, 12) + minutes / 60.0;

    // Correct angles - adjusted for the 90-degree offset
    CGFloat hourAngle = -(hours * 2 * M_PI / 12.0);
    CGFloat minuteAngle = -(minutes * 2 * M_PI / 60.0);
    CGFloat secondAngle = -(seconds * 2 * M_PI / 60.0);
    
    
    // PERF: Reuse accent color object instead of creating new ones
    // Was: [accent colorWithAlphaComponent:1]
    NSColor *hourColor = accent;
    NSColor *minuteColor = accent;
    NSColor *secondColor = accent;
    

    [self drawHandInContext:ctx
                     center:center
                      angle:hourAngle
                     length:radius * 0.6
                      width:radius * 0.071
                      color:hourColor
                 background:bg
                     accent:hourColor style:self.hourStyle];

    [self drawHandInContext:ctx
                     center:center
                      angle:minuteAngle
                     length:radius * 0.85
                      width:radius * 0.058
                      color:minuteColor
                 background:bg
                     accent:minuteColor style:self.minuteStyle];

    if (self.secondHand) [self drawHandInContext:ctx
                     center:center
                      angle:secondAngle
                     length:radius * 0.9
                      width:radius * 0.021
                      color:secondColor
                 background:bg
                     accent:secondColor style:self.secondStyle];
    
    // Center dot
    CGFloat capRadius = radius * 0.042;
    CGContextSetFillColorWithColor(ctx, bg.CGColor);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - capRadius, center.y - capRadius, capRadius * 2, capRadius * 2));
    CGContextFillPath(ctx);
    
    CGContextSetStrokeColorWithColor(ctx, accent.CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x - capRadius, center.y - capRadius, capRadius * 2, capRadius * 2));
    CGContextStrokePath(ctx);
    
    CGContextRestoreGState(ctx);
    
    // PERF: Update last rendered second
    self.lastSecond = components.second;
}

- (void)drawHandInContext:(CGContextRef)ctx
                   center:(CGPoint)center
                    angle:(CGFloat)angle
                   length:(CGFloat)length
                    width:(CGFloat)width
                    color:(NSColor*)accent
               background:(NSColor*)bgColor
                   accent:(NSColor*)accentColor
                    style:(NSInteger)style
{
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, center.x, center.y);
    CGContextRotateCTM(ctx, angle);
    
    // === SHAPE PROPORTIONS ===
    CGFloat baseWidth = width;
    CGFloat bodyLength = length * 0.88;     // most of the hand is rectangular
    CGFloat taperLength = length * 0.12;    // gentle taper at the end
    CGFloat taperStartY = bodyLength;
    
    // === MAIN BODY SHAPE (rectangle with rounded taper) ===
    NSBezierPath *outerPath = [NSBezierPath bezierPath];
    [outerPath moveToPoint:NSMakePoint(-baseWidth / 2.0, 0)];           // Bottom left
    [outerPath lineToPoint:NSMakePoint(baseWidth / 2.0, 0)];            // Bottom right
    [outerPath lineToPoint:NSMakePoint(baseWidth / 2.0, taperStartY)];  // Top right of rectangle
    
    // Gentle curve to rounded tip
    [outerPath curveToPoint:NSMakePoint(0, length)                      // Tip point
              controlPoint1:NSMakePoint(baseWidth / 2.0, taperStartY + taperLength * 0.3)
              controlPoint2:NSMakePoint(baseWidth / 4.0, length - taperLength * 0.2)];
    
    // Curve back down the other side
    [outerPath curveToPoint:NSMakePoint(-baseWidth / 2.0, taperStartY)  // Top left of rectangle
              controlPoint1:NSMakePoint(-baseWidth / 4.0, length - taperLength * 0.2)
              controlPoint2:NSMakePoint(-baseWidth / 2.0, taperStartY + taperLength * 0.3)];
    
    [outerPath closePath];
    
    if (style != 0) {
        outerPath = [NSBezierPath bezierPath];
        CGFloat w = width;
        switch (style) {
            case 1: // Straight, softly rounded baton.
                outerPath = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(-w*.42, 0, w*.84, length) xRadius:w*.18 yRadius:w*.18];
                break;
            case 2: // Broad diamond taper.
                [outerPath moveToPoint:NSMakePoint(0, -length*.06)];
                [outerPath lineToPoint:NSMakePoint(w*.85, length*.22)];
                [outerPath lineToPoint:NSMakePoint(0, length)];
                [outerPath lineToPoint:NSMakePoint(-w*.85, length*.22)];
                [outerPath closePath]; break;
            case 3: // Symmetric curved leaf.
                [outerPath moveToPoint:NSMakePoint(0, 0)];
                [outerPath curveToPoint:NSMakePoint(0, length) controlPoint1:NSMakePoint(w*1.5, length*.25) controlPoint2:NSMakePoint(w*.8, length*.65)];
                [outerPath curveToPoint:NSMakePoint(0, 0) controlPoint1:NSMakePoint(-w*.8, length*.65) controlPoint2:NSMakePoint(-w*1.5, length*.25)];
                [outerPath closePath]; break;
            case 4: // Narrow stem, broad blade, sharp tip.
                [outerPath moveToPoint:NSMakePoint(-w*.22, 0)];
                [outerPath lineToPoint:NSMakePoint(w*.22, 0)];
                [outerPath lineToPoint:NSMakePoint(w*.22, length*.28)];
                [outerPath lineToPoint:NSMakePoint(w*.8, length*.40)];
                [outerPath lineToPoint:NSMakePoint(0, length)];
                [outerPath lineToPoint:NSMakePoint(-w*.8, length*.40)];
                [outerPath lineToPoint:NSMakePoint(-w*.22, length*.28)];
                [outerPath closePath]; break;
            default: // Fine needle with a circular counterweight.
                outerPath = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(-w*.14, -length*.20, w*.28, length*1.20) xRadius:w*.14 yRadius:w*.14];
                [outerPath appendBezierPathWithOvalInRect:NSMakeRect(-w*.8, -length*.18-w*.8, w*1.6, w*1.6)];
                break;
        }
    }

    // === COLORS ===
    NSColor *metalColor;
    NSColor *outlineColor;
    NSColor *radiumColor = accent;
    
    if (self.nightMode) {
        metalColor   = bgColor;
        outlineColor = [accent colorWithAlphaComponent:0.1];
    } else {
        metalColor   = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0]; // silver
        outlineColor = [NSColor whiteColor];
    }
    
    // === METAL BODY WITH SHADOW ===
    [NSGraphicsContext saveGraphicsState];
    
    // Add shadow below the hand
    NSShadow *handShadow = [[NSShadow alloc] init];
    handShadow.shadowColor = [accent colorWithAlphaComponent:self.glowAmount];
    handShadow.shadowBlurRadius = 60.0;
    [handShadow set];
    
    if (self.dialStyle > 0 && !self.nightMode) {
        NSGradient *metal=[[NSGradient alloc] initWithColors:@[ColorFromHex(@"8D999D"), NSColor.whiteColor, ColorFromHex(@"C2CCCF")]];
        [metal drawInBezierPath:outerPath angle:0];
    } else { [metalColor setFill]; [outerPath fill]; }
    
    [NSGraphicsContext restoreGraphicsState];
    
    [outlineColor setStroke];
    [outerPath setLineWidth:1.2];
    [outerPath stroke];
    
    // === RADIUM INSET WITH PADDING FROM ALL SIDES ===
    CGFloat sidePadding = width * 0.35;      // padding from left/right edges
    CGFloat bottomPadding = length * 0.15;   // padding from bottom
    CGFloat topEnd = bodyLength * 0.95;      // stop before taper begins
    
    CGFloat radiumWidth = baseWidth - (sidePadding * 2);
    CGFloat radiumLength = topEnd - bottomPadding;
    CGFloat insetRadius = radiumWidth * 0.5;
    
    NSRect radiumRect = NSMakeRect(-radiumWidth / 2.0,
                                   bottomPadding,
                                   radiumWidth,
                                   radiumLength);
    
    NSBezierPath *radiumPath = [NSBezierPath bezierPathWithRoundedRect:radiumRect
                                                               xRadius:insetRadius
                                                               yRadius:insetRadius];
    if (style != 0) {
        radiumPath = [outerPath copy];
        NSAffineTransform *inset = [NSAffineTransform transform];
        [inset translateXBy:0 yBy:length*.08];
        [inset scaleXBy:.48 yBy:.80];
        [radiumPath transformUsingAffineTransform:inset];
    }
    [NSGraphicsContext saveGraphicsState];
    [outerPath addClip];
    [radiumColor setFill];
    [radiumPath fill];
    [NSGraphicsContext restoreGraphicsState];
    
    CGContextRestoreGState(ctx);
    
}

- (void)animateOneFrame {
    // The options and full-screen saver can live in separate host processes.
    // Refresh the shared defaults even if this view never restarts animation.
    if ([NSDate timeIntervalSinceReferenceDate] - self.lastPreferencesRefresh >= 1.0) {
        [self loadPreferences];
    }
    // PERF: Optional optimization - only redraw when second changes
    // Uncomment the code below to reduce redraws from 30fps to 1fps (huge battery savings)
    // Note: This will make the second hand jump instead of being smooth
    /*
    NSDate *date = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitSecond fromDate:date];
    
    if (components.second != self.lastSecond) {
        [self setNeedsDisplay:YES];
    }
    */
    
    // Current: Always redraw (smooth animation)
    [self setNeedsDisplay:YES];
}

@end
