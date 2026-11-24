#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

static NSString * const kBGPStateKey = @"BGPToggleStatus";
static NSString * const kBGPHideDIKey = @"BGPHideDIToggleStatus";
static NSString * const kBGPSliderThicknessKey = @"BGPSliderThicknessPercent";
static NSString * const kBGPSliderFullscreenOnlyKey = @"BGPSliderFullscreenOnly";
static const NSInteger kBGPSectionID = 2610;
static const NSInteger kTweakGroupID = 'psyt';
static const CGFloat kDefaultScrubberSize = 12.0;
static const CGFloat kYouTubeScrubberScale = 6.0;

static BOOL gBGPState = NO;
static BOOL gHideDIState = NO;
static NSInteger gSliderThicknessPercent = 100;
static BOOL gFullscreenOnly = NO;

static BOOL fetchBGPState() {
    return gBGPState;
}

static BOOL fetchHideDIState() {
    return gHideDIState;
}

static NSInteger fetchSliderThicknessPercent() {
    return gSliderThicknessPercent >= 50 ? gSliderThicknessPercent : 100;
}

static CGFloat fetchSliderThicknessScale() {
    return fetchSliderThicknessPercent() / 100.0;
}

static CGFloat fetchScrubberDotScale() {
    CGFloat sliderScale = fetchSliderThicknessScale();
    if (fabs(sliderScale - 1.0) <= 0.001) return 1.0;
    return 1.0 + ((sliderScale - 1.0) * 0.5);
}

static BOOL fetchFullscreenOnlyState() {
    return gFullscreenOnly;
}

static id safeGetObjectIvar(id obj, const char *ivarName) {
    if (!obj || !ivarName) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(obj), ivarName);
    if (!ivar) return nil;
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding || encoding[0] != '@') return nil;
    return object_getIvar(obj, ivar);
}

static BOOL isTweakGroupItem(id item) {
    if (!item) return NO;
    @try {
        id val = [item valueForKey:@"type"];
        if (val && [val integerValue] == kTweakGroupID) {
            return YES;
        }
    } @catch (id ex) {}
    return NO;
}

static BOOL isYouGroupSettingsActive() {
    Class cls = objc_getClass("YTSettingsGroupData");
    if (cls && class_getClassMethod(cls, sel_registerName("tweaks")) != NULL) {
        return YES;
    }
    return NO;
}

static NSString * loadText(NSString *key) {
    BOOL isKor = [[[NSLocale preferredLanguages] firstObject] hasPrefix:@"ko"];
    if ([key isEqualToString:@"T1"]) {
        return isKor ? @"안정적인 백그라운드 재생" : @"Stable background playback";
    }
    if ([key isEqualToString:@"D1"]) {
        return isKor ? @"앱을 종료하거나 화면을 꺼도 오디오 재생을 유지하며, '동영상이 일시중지되었습니다. 이어서 시청하시겠습니까?' 시청 확인창을 차단합니다." : @"Allows audio to continue playing in the background and prevents the 'Video paused. Continue watching?' prompt.";
    }
    if ([key isEqualToString:@"T2"]) {
        return isKor ? @"다이내믹 아일랜드에서 플레이어 숨기기" : @"Hide player on Dynamic Island";
    }
    if ([key isEqualToString:@"D2"]) {
        return isKor ? @"앱이 활성화되어 있거나 백그라운드에서 재생 중일 때 다이내믹 아일랜드에 미디어 플레이어를 표시하지 않습니다. 이 기능의 동작을 정확히 이해하신 경우에만 활성화해 주세요. (주의: 잠금 화면 미디어 플레이어에는 재생 중인 영상 정보가 빈 상태로 표시됩니다.)" : @"Hides the media player from the Dynamic Island during foreground and background playback. Only activate this feature if you fully understand its impact. (Note: The lock screen media player will appear blank)";
    }
    if ([key isEqualToString:@"T3"]) {
        return isKor ? @"슬라이더 두께" : @"Slider thickness";
    }
    if ([key isEqualToString:@"D3"]) {
        return isKor ? @"동영상 재생 바(슬라이더)의 두께 배율을 조절합니다." : @"Adjusts the thickness scale of the video player progress bar.";
    }
    if ([key isEqualToString:@"T4"]) {
        return isKor ? @"전체 화면에서만 슬라이더 두께 적용" : @"Apply slider thickness in fullscreen only";
    }
    if ([key isEqualToString:@"D4"]) {
        return isKor ? @"전체 화면 재생 시에만 변경된 슬라이더 두께와 재생 위치 점(스크러버) 크기를 적용합니다." : @"Applies the custom slider thickness and scrubber size only during fullscreen playback.";
    }
    if ([key isEqualToString:@"DEFAULT"]) {
        return isKor ? @"1x (기본값)" : @"1x (Default)";
    }
    return @"";
}

static CGRect scaleBarFrameVertically(CGRect frame, CGFloat scale) {
    if (fabs(scale - 1.0) <= 0.001) return frame;
    if (frame.size.height > 0.0 && frame.size.height <= 12.0) {
        CGFloat midY = CGRectGetMidY(frame);
        CGFloat newHeight = frame.size.height * scale;
        frame.origin.y = midY - (newHeight / 2.0);
        frame.size.height = newHeight;
    }
    return frame;
}

static void updateScrubberCircleSize(UIView *scrubberCircle, CGFloat scale) {
    if (![scrubberCircle isKindOfClass:[UIView class]]) return;
    CGRect frame = scrubberCircle.frame;
    CGFloat size = (kDefaultScrubberSize * scale) / kYouTubeScrubberScale;
    if (frame.size.width > 0.0 && frame.size.height > 0.0) {
        CGFloat midX = CGRectGetMidX(frame);
        CGFloat midY = CGRectGetMidY(frame);
        scrubberCircle.frame = CGRectMake(midX - (size / 2.0), midY - (size / 2.0), size, size);
    } else {
        scrubberCircle.frame = CGRectMake(frame.origin.x, frame.origin.y, size, size);
    }
    scrubberCircle.layer.cornerRadius = size / 2.0;
}

@interface YTIIcon : NSObject
@property (nonatomic, assign) NSUInteger iconType;
@end

@interface YTSettingsGroupData : NSObject
@property (nonatomic, assign, readonly) NSInteger type;
- (instancetype)initWithGroupType:(NSInteger)type;
@end

@interface YTAppSettingsGroupPresentationData : NSObject
+ (NSArray *)orderedGroups;
@end

@interface YTSettingsSectionItem : NSObject
+ (instancetype)switchItemWithTitle:(NSString *)title
                   titleDescription:(NSString *)titleDescription
            accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           switchOn:(BOOL)switchOn
                        switchBlock:(BOOL (^)(id cell, BOOL enabled))switchBlock
                      settingItemId:(int)settingItemId;
+ (instancetype)itemWithTitle:(NSString *)title
             titleDescription:(NSString *)titleDescription
      accessibilityIdentifier:(NSString *)accessibilityIdentifier
              detailTextBlock:(NSString * (^)(void))detailTextBlock
                  selectBlock:(BOOL (^)(id cell, NSUInteger arg1))selectBlock;
+ (instancetype)checkmarkItemWithTitle:(NSString *)title
                      titleDescription:(NSString *)titleDescription
                           selectBlock:(BOOL (^)(id cell, NSUInteger arg1))selectBlock;
@end

@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSArray *)items forCategory:(NSInteger)category title:(NSString *)title icon:(id)icon titleDescription:(NSString *)desc headerHidden:(BOOL)hidden;
- (void)setSectionItems:(NSArray *)items forCategory:(NSInteger)category title:(NSString *)title titleDescription:(NSString *)desc headerHidden:(BOOL)hidden;
- (void)reloadData;
- (void)pushViewController:(UIViewController *)viewController;
@end

@interface YTSettingsPickerViewController : UIViewController
- (instancetype)initWithNavTitle:(NSString *)navTitle
              pickerSectionTitle:(NSString *)sectionTitle
                            rows:(NSArray *)rows
               selectedItemIndex:(NSUInteger)index
                 parentResponder:(id)parentResponder;
@end

@interface YTSettingsSectionItemManager : NSObject
- (void)buildCustomBGPSection:(id)entry;
- (id)parentResponder;
@end

@interface YTPlayerBarRectangleDecorationView : UIView
@end

@interface YTPlayerBarProgressDecorationView : UIView
@end

@interface YTPlayerBarSegmentView : UIView
@end

@interface YTPlayerBarScrubberDotDecorationView : UIView
- (void)transformScrubberScale:(CGFloat)scale;
@end

@interface YTPlayerBarScrubberDotDecorationViewV2 : YTPlayerBarScrubberDotDecorationView
@end

@interface YTModularPlayerBarView : UIView
@end

@interface YTSegmentableInlinePlayerBarView : UIView
@end

@interface YTInlinePlayerBarView : UIView
@end

@interface YTWatchFloatingMiniplayerProgressBarView : UIView
@end

@interface YTInlineMutedPlaybackScrubbingSlider : UISlider
@end

static BOOL isViewInFullscreen(UIView *view) {
    if (!view || !view.window) return NO;
    CGFloat windowH = CGRectGetHeight(view.window.bounds);
    if (windowH <= 0.0) return NO;
    Class overlayClass = %c(YTMainAppVideoPlayerOverlayView);
    UIView *node = view;
    while (node) {
        if (overlayClass && [node isKindOfClass:overlayClass]) {
            return CGRectGetHeight(node.bounds) >= windowH * 0.82;
        }
        node = node.superview;
    }
    return NO;
}

static CGFloat effectiveSliderThicknessScaleForView(UIView *view) {
    CGFloat scale = fetchSliderThicknessScale();
    if (fabs(scale - 1.0) <= 0.001) return 1.0;
    if (fetchFullscreenOnlyState() && !isViewInFullscreen(view)) return 1.0;
    return scale;
}

static CGFloat effectiveScrubberDotScaleForView(UIView *view) {
    CGFloat scale = fetchScrubberDotScale();
    if (fabs(scale - 1.0) <= 0.001) return 1.0;
    if (fetchFullscreenOnlyState() && !isViewInFullscreen(view)) return 1.0;
    return scale;
}

static void forceDecorationScaleRefresh(YTPlayerBarScrubberDotDecorationView *decorationView) {
    if (![decorationView respondsToSelector:@selector(transformScrubberScale:)]) return;
    CGFloat youtubeScale = kYouTubeScrubberScale;
    @try {
        NSInteger scaleEnum = [[decorationView valueForKey:@"_scrubberDotDecorationScale"] integerValue];
        if (scaleEnum <= 0) {
            youtubeScale = 0.0;
        } else if (scaleEnum == 2) {
            youtubeScale = [[decorationView valueForKey:@"_dragEnlargedScale"] doubleValue] ?: 10.0;
        } else {
            youtubeScale = [[decorationView valueForKey:@"_enlargedScale"] doubleValue] ?: kYouTubeScrubberScale;
        }
    } @catch (id ex) {}
    [decorationView transformScrubberScale:youtubeScale + 0.01];
    [decorationView transformScrubberScale:youtubeScale];
    [decorationView setNeedsLayout];
    [decorationView layoutIfNeeded];
}

static void relayoutVisiblePlayerBars(UIView *view, NSUInteger depth) {
    if (!view || depth > 20) return;
    NSString *clsName = NSStringFromClass(view.class);
    if ([clsName containsString:@"PlayerBar"] ||
        [clsName containsString:@"MiniplayerProgressBar"]) {
        [view setNeedsLayout];
        [view setNeedsDisplay];
        UIView *scrubberCircle = safeGetObjectIvar(view, "_scrubberCircle");
        if (scrubberCircle) {
            updateScrubberCircleSize(scrubberCircle, effectiveScrubberDotScaleForView(view));
        }
    }
    Class dotDecorationClass = %c(YTPlayerBarScrubberDotDecorationView);
    if (dotDecorationClass && [view isKindOfClass:dotDecorationClass]) {
        updateScrubberCircleSize(safeGetObjectIvar(view, "_defaultScrubberDot"), effectiveScrubberDotScaleForView(view));
        forceDecorationScaleRefresh((YTPlayerBarScrubberDotDecorationView *)view);
    }
    for (UIView *subview in view.subviews) {
        relayoutVisiblePlayerBars(subview, depth + 1);
    }
}

static void refreshAllPlayerBars() {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            relayoutVisiblePlayerBars(window, 0);
        }
    }
}

%hook MLVideo
- (BOOL)playableInBackground {
    if (fetchBGPState()) return YES;
    return %orig;
}
%end

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground {
    if (fetchBGPState()) return YES;
    return %orig;
}
%end

%hook YTPlaybackData
- (BOOL)isPlayableInBackground {
    if (fetchBGPState()) return YES;
    return %orig;
}
%end

%hook YTIPlayerResponse
- (BOOL)isPlayableInBackground {
    if (fetchBGPState()) return YES;
    return %orig;
}
%end

%hook YTColdConfig
- (BOOL)enableYouthereCommandsOnIos {
    if (fetchBGPState()) return NO;
    return %orig;
}
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt {
    if (fetchBGPState()) return NO;
    return %orig;
}
- (void)showYouTherePrompt {
    if (!fetchBGPState()) %orig;
}
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt {
    if (fetchBGPState()) return NO;
    return %orig;
}
- (void)showYouTherePrompt {
    if (!fetchBGPState()) %orig;
}
%end

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary<NSString *, id> *)nowPlayingInfo {
    if (fetchHideDIState()) {
        %orig(nil);
    } else {
        %orig(nowPlayingInfo);
    }
}
%end

%hook YTPlayerViewController
- (void)setPlayerViewLayout:(NSInteger)layout {
    %orig;
    if (fetchFullscreenOnlyState() && fabs(fetchSliderThicknessScale() - 1.0) > 0.001) {
        dispatch_async(dispatch_get_main_queue(), ^{
            refreshAllPlayerBars();
        });
    }
}
%end

%hook YTPlayerBarRectangleDecorationView
- (void)setFrame:(CGRect)frame {
    %orig(scaleBarFrameVertically(frame, effectiveSliderThicknessScaleForView(self)));
}

- (void)layoutSubviews {
    %orig;
    if ((fabs(effectiveSliderThicknessScaleForView(self) - 1.0) > 0.001 || fetchFullscreenOnlyState()) && self.layer.cornerRadius > 0.0) {
        self.layer.cornerRadius = self.bounds.size.height / 2.0;
    }
}
%end

%hook YTPlayerBarProgressDecorationView
- (void)setFrame:(CGRect)frame {
    %orig(scaleBarFrameVertically(frame, effectiveSliderThicknessScaleForView(self)));
}

- (void)layoutSubviews {
    %orig;
    if ((fabs(effectiveSliderThicknessScaleForView(self) - 1.0) > 0.001 || fetchFullscreenOnlyState()) && self.layer.cornerRadius > 0.0) {
        self.layer.cornerRadius = self.bounds.size.height / 2.0;
    }
}
%end

%hook YTPlayerBarSegmentView
- (void)setFrame:(CGRect)frame {
    %orig(scaleBarFrameVertically(frame, effectiveSliderThicknessScaleForView(self)));
}
%end

%hook YTPlayerBarScrubberDotDecorationView
- (id)initWithModel:(id)model {
    self = %orig;
    if (self) {
        CGFloat dotScale = effectiveScrubberDotScaleForView(self);
        if (fabs(dotScale - 1.0) > 0.001) {
            updateScrubberCircleSize(safeGetObjectIvar(self, "_defaultScrubberDot"), dotScale);
        }
    }
    return self;
}
%end

%hook YTPlayerBarScrubberDotDecorationViewV2
- (void)transformScrubberScale:(CGFloat)scale {
    CGFloat dotScale = effectiveScrubberDotScaleForView(self);
    if (fabs(dotScale - 1.0) > 0.001) {
        scale *= dotScale;
    }
    %orig(scale);
}
%end

%hook YTModularPlayerBarView
- (id)initWithModel:(id)model delegate:(id)delegate {
    self = %orig;
    if (self) {
        CGFloat dotScale = effectiveScrubberDotScaleForView(self);
        if (fabs(dotScale - 1.0) > 0.001) {
            updateScrubberCircleSize(safeGetObjectIvar(self, "_scrubberCircle"), dotScale);
        }
    }
    return self;
}

- (void)didMoveToWindow {
    %orig;
    if (self.window && fetchFullscreenOnlyState() && fabs(fetchSliderThicknessScale() - 1.0) > 0.001) {
        dispatch_async(dispatch_get_main_queue(), ^{
            relayoutVisiblePlayerBars(self, 0);
        });
    }
}

- (void)layoutSubviews {
    %orig;
    if (fabs(effectiveSliderThicknessScaleForView(self) - 1.0) <= 0.001) return;

    self.clipsToBounds = NO;

    UIView *scrubberDot = safeGetObjectIvar(self, "_scrubberCircle");
    if (!scrubberDot) {
        Class dotDecorationClass = %c(YTPlayerBarScrubberDotDecorationView);
        for (UIView *sub in self.subviews) {
            if (dotDecorationClass && [sub isKindOfClass:dotDecorationClass]) {
                scrubberDot = sub;
                break;
            }
        }
    }

    if (scrubberDot && self.subviews.lastObject != scrubberDot) {
        [self bringSubviewToFront:scrubberDot];
    }
}
%end

%hook YTSegmentableInlinePlayerBarView
- (id)init {
    self = %orig;
    if (self) {
        CGFloat dotScale = effectiveScrubberDotScaleForView(self);
        if (fabs(dotScale - 1.0) > 0.001) {
            updateScrubberCircleSize(safeGetObjectIvar(self, "_scrubberCircle"), dotScale);
        }
    }
    return self;
}
%end

%hook YTInlinePlayerBarView
- (id)init {
    self = %orig;
    if (self) {
        CGFloat dotScale = effectiveScrubberDotScaleForView(self);
        if (fabs(dotScale - 1.0) > 0.001) {
            updateScrubberCircleSize(safeGetObjectIvar(self, "_scrubberCircle"), dotScale);
        }
    }
    return self;
}

- (void)layoutSubviews {
    %orig;
    CGFloat scale = effectiveSliderThicknessScaleForView(self);
    if (fabs(scale - 1.0) <= 0.001) return;

    self.clipsToBounds = NO;
    UIView *playingProgress = safeGetObjectIvar(self, "_playingProgress");
    if ([playingProgress isKindOfClass:[UIView class]]) {
        playingProgress.frame = scaleBarFrameVertically(playingProgress.frame, scale);
    }
}
%end

%hook YTWatchFloatingMiniplayerProgressBarView
- (void)setFrame:(CGRect)frame {
    if (fetchFullscreenOnlyState()) {
        %orig;
        return;
    }
    %orig(scaleBarFrameVertically(frame, fetchSliderThicknessScale()));
}
%end

%hook YTInlineMutedPlaybackScrubbingSlider
- (CGRect)trackRectForBounds:(CGRect)bounds {
    CGRect rect = %orig;
    if (fetchFullscreenOnlyState() || ![self.accessibilityIdentifier isEqualToString:@"id.player.scrubber.slider"]) {
        return rect;
    }
    return scaleBarFrameVertically(rect, fetchSliderThicknessScale());
}

- (void)setThumbImage:(UIImage *)image forState:(UIControlState)state {
    CGFloat scale = fetchFullscreenOnlyState() ? 1.0 : fetchScrubberDotScale();
    if (!image || fabs(scale - 1.0) <= 0.001 || ![self.accessibilityIdentifier isEqualToString:@"id.player.scrubber.slider"]) {
        %orig;
        return;
    }
    BOOL isTransparent = NO;
    @try {
        isTransparent = [[image.imageAsset valueForKey:@"assetName"] isEqualToString:@"transparent"];
    } @catch (id ex) {}
    if (isTransparent) {
        %orig;
        return;
    }

    CGSize newSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = image.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:newSize format:format];
    UIImage *scaledImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    }];
    %orig(scaledImage, state);
}
%end

%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    NSArray *baseOrder = %orig;
    NSMutableArray *modOrder = baseOrder ? [baseOrder mutableCopy] : [NSMutableArray array];
    if (![modOrder containsObject:@(kBGPSectionID)]) {
        NSUInteger generalIdx = [modOrder indexOfObject:@(1)];
        if (generalIdx != NSNotFound) {
            [modOrder insertObject:@(kBGPSectionID) atIndex:generalIdx + 1];
        } else {
            [modOrder addObject:@(kBGPSectionID)];
        }
    }
    return modOrder.copy;
}
%end

%hook YTAppSettingsGroupPresentationData
+ (NSArray *)orderedGroups {
    NSArray *groups = %orig;
    if (isYouGroupSettingsActive()) return groups;
    for (id item in groups) {
        if (isTweakGroupItem(item)) return groups;
    }
    Class groupDataClass = %c(YTSettingsGroupData);
    if (groupDataClass && [groupDataClass instancesRespondToSelector:@selector(initWithGroupType:)]) {
        id customGroup = [[groupDataClass alloc] initWithGroupType:kTweakGroupID];
        if (customGroup) {
            NSMutableArray *modGroups = groups ? [groups mutableCopy] : [NSMutableArray array];
            [modGroups insertObject:customGroup atIndex:0];
            return modGroups.copy;
        }
    }
    return groups;
}
%end

%hook YTSettingsGroupData
- (NSString *)titleForSettingGroupType:(NSUInteger)type {
    if (type == kTweakGroupID) {
        NSString *origTitle = %orig;
        if (origTitle && origTitle.length > 0) return origTitle;
        return @"Tweaks";
    }
    return %orig;
}

- (NSArray <NSNumber *> *)orderedCategoriesForGroupType:(NSUInteger)type {
    NSArray *baseArr = %orig;
    if (type == kTweakGroupID) {
        NSMutableArray *modArr = baseArr ? [baseArr mutableCopy] : [NSMutableArray array];
        if (![modArr containsObject:@(kBGPSectionID)]) [modArr addObject:@(kBGPSectionID)];
        return modArr.copy;
    }
    return baseArr;
}

- (NSArray <NSNumber *> *)orderedCategories {
    NSArray *baseArr = %orig;
    if (self.type == kTweakGroupID) {
        NSMutableArray *modArr = baseArr ? [baseArr mutableCopy] : [NSMutableArray array];
        if (![modArr containsObject:@(kBGPSectionID)]) [modArr addObject:@(kBGPSectionID)];
        return modArr.copy;
    }
    return baseArr;
}
%end

%hook YTSettingsSectionItemManager
%new
- (void)buildCustomBGPSection:(id)entry {
    id targetDelegate = [self valueForKey:@"_dataDelegate"];
    if (!targetDelegate) {
        targetDelegate = [self valueForKey:@"_settingsViewControllerDelegate"];
    }

    NSMutableArray *uiItems = [NSMutableArray array];

    id tSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:loadText(@"T1")
        titleDescription:loadText(@"D1")
        accessibilityIdentifier:nil
        switchOn:fetchBGPState()
        switchBlock:^BOOL (id cell, BOOL enabled) {
            gBGPState = enabled;
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBGPStateKey];
            return YES;
        }
        settingItemId:0];
    [uiItems addObject:tSwitch];

    id diSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:loadText(@"T2")
        titleDescription:loadText(@"D2")
        accessibilityIdentifier:nil
        switchOn:fetchHideDIState()
        switchBlock:^BOOL (id cell, BOOL enabled) {
            gHideDIState = enabled;
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBGPHideDIKey];
            if (enabled) {
                [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
            }
            return YES;
        }
        settingItemId:1];
    [uiItems addObject:diSwitch];

    NSArray<NSNumber *> *presets = @[@50, @100, @125, @150, @200, @250, @300, @400];
    NSString *thicknessTitle = loadText(@"T3");

    id thicknessItem = [%c(YTSettingsSectionItem) itemWithTitle:thicknessTitle
        titleDescription:loadText(@"D3")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            NSInteger percent = fetchSliderThicknessPercent();
            if (percent == 100) return loadText(@"DEFAULT");
            return [NSString stringWithFormat:@"%.3gx", percent / 100.0];
        }
        selectBlock:^BOOL (id cell, NSUInteger arg1) {
            NSInteger currentPercent = fetchSliderThicknessPercent();
            NSUInteger selectedIndex = 0;
            NSMutableArray *rows = [NSMutableArray array];

            for (NSUInteger i = 0; i < presets.count; i++) {
                NSInteger val = presets[i].integerValue;
                if (val == currentPercent) selectedIndex = i;
                NSString *rowTitle = (val == 100)
                    ? loadText(@"DEFAULT")
                    : [NSString stringWithFormat:@"%.3gx", val / 100.0];

                id rowItem = [%c(YTSettingsSectionItem) checkmarkItemWithTitle:rowTitle
                    titleDescription:nil
                    selectBlock:^BOOL (id rowCell, NSUInteger rowIdx) {
                        gSliderThicknessPercent = val;
                        [[NSUserDefaults standardUserDefaults] setInteger:val forKey:kBGPSliderThicknessKey];
                        refreshAllPlayerBars();
                        if ([targetDelegate respondsToSelector:@selector(reloadData)]) {
                            [targetDelegate reloadData];
                        }
                        return YES;
                    }];
                [rows addObject:rowItem];
            }

            Class pickerClass = %c(YTSettingsPickerViewController);
            if (pickerClass && [targetDelegate respondsToSelector:@selector(pushViewController:)]) {
                id parentResp = [self respondsToSelector:@selector(parentResponder)] ? [self parentResponder] : nil;
                UIViewController *picker = [[pickerClass alloc] initWithNavTitle:thicknessTitle
                    pickerSectionTitle:nil
                    rows:rows
                    selectedItemIndex:selectedIndex
                    parentResponder:parentResp];
                [targetDelegate pushViewController:picker];
            }
            return YES;
        }];
    [uiItems addObject:thicknessItem];

    id fsSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:loadText(@"T4")
        titleDescription:loadText(@"D4")
        accessibilityIdentifier:nil
        switchOn:fetchFullscreenOnlyState()
        switchBlock:^BOOL (id cell, BOOL enabled) {
            gFullscreenOnly = enabled;
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBGPSliderFullscreenOnlyKey];
            refreshAllPlayerBars();
            return YES;
        }
        settingItemId:2];
    [uiItems addObject:fsSwitch];

    YTIIcon *iConfig = [%c(YTIIcon) new];
    if ([iConfig respondsToSelector:@selector(setIconType:)]) {
        iConfig.iconType = 44;
    }

    if ([targetDelegate respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        [targetDelegate setSectionItems:uiItems forCategory:kBGPSectionID title:@"YTBackgroundOnly" icon:iConfig titleDescription:nil headerHidden:NO];
    } else if ([targetDelegate respondsToSelector:@selector(setSectionItems:forCategory:title:titleDescription:headerHidden:)]) {
        [targetDelegate setSectionItems:uiItems forCategory:kBGPSectionID title:@"YTBackgroundOnly" titleDescription:nil headerHidden:NO];
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == kBGPSectionID) {
        [self buildCustomBGPSection:entry];
        return;
    }
    %orig;
}
%end

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        kBGPStateKey: @NO,
        kBGPHideDIKey: @NO,
        kBGPSliderThicknessKey: @100,
        kBGPSliderFullscreenOnlyKey: @NO,
    }];
    gBGPState = [defaults boolForKey:kBGPStateKey];
    gHideDIState = [defaults boolForKey:kBGPHideDIKey];
    NSInteger savedThickness = [defaults integerForKey:kBGPSliderThicknessKey];
    gSliderThicknessPercent = savedThickness >= 50 ? savedThickness : 100;
    gFullscreenOnly = [defaults boolForKey:kBGPSliderFullscreenOnlyKey];
}
