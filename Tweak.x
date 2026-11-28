#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <string.h>
#import <math.h>

static NSString * const kBGPStateKey = @"BGPToggleStatus";
static NSString * const kBGPHideDIKey = @"BGPHideDIToggleStatus";
static NSString * const kBGPNormalSliderKey = @"BGPNormalSliderThicknessPercent";
static NSString * const kBGPFullscreenSliderKey = @"BGPFullscreenSliderThicknessPercent";
static NSString * const kBGPShortsSliderKey = @"BGPShortsSliderThicknessPercent";
static const NSInteger kBGPSectionID = 2610;
static const NSInteger kTweakGroupID = 'psyt';
static const CGFloat kDefaultScrubberSize = 12.0;
static const CGFloat kYouTubeScrubberScale = 6.0;

static const void * const kBGPBaseHeightKey = &kBGPBaseHeightKey;
static const void * const kBGPAppliedHeightKey = &kBGPAppliedHeightKey;
static const void * const kBGPModifiedTrackKey = &kBGPModifiedTrackKey;
static const void * const kBGPModifiedContainerKey = &kBGPModifiedContainerKey;
static const void * const kBGPModifiedDotKey = &kBGPModifiedDotKey;
static const void * const kBGPWasFullscreenKey = &kBGPWasFullscreenKey;
static const void * const kBGPCachedKindKey = &kBGPCachedKindKey;
static const void * const kBGPRelayoutPendingKey = &kBGPRelayoutPendingKey;

static BOOL gBGPState = NO;
static BOOL gHideDIState = NO;
static NSInteger gNormalSliderPercent = 100;
static NSInteger gFullscreenSliderPercent = 100;
static NSInteger gShortsSliderPercent = 100;
static BOOL gHasModifiedSlider = NO;
static BOOL gHasModifiedNormal = NO;
static BOOL gApplyingTrackFrame = NO;

typedef NS_ENUM(NSInteger, BGPViewContext) {
    BGPViewContextUnknown = 0,
    BGPViewContextNormalInline,
    BGPViewContextNormalFullscreen,
    BGPViewContextShorts,
    BGPViewContextExcluded
};

typedef NS_ENUM(NSInteger, BGPCachedKind) {
    BGPCachedKindOverlay = 1,
    BGPCachedKindShorts = 2,
    BGPCachedKindInline = 3,
    BGPCachedKindExcluded = 4
};

static NSInteger sanitizeSliderPercent(NSInteger val) {
    return (val >= 50 && val <= 400) ? val : 100;
}

static BOOL fetchBGPState() {
    return gBGPState;
}

static BOOL fetchHideDIState() {
    return gHideDIState;
}

static CGFloat scrubberScaleForSliderScale(CGFloat sliderScale) {
    if (fabs(sliderScale - 1.0) <= 0.001) return 1.0;
    return 1.0 + ((sliderScale - 1.0) * 0.5);
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
        return isKor ? @"일반 화면 슬라이더 두께" : @"Regular slider thickness";
    }
    if ([key isEqualToString:@"D3"]) {
        return isKor ? @"일반 재생 화면(세로 화면 등)의 동영상 재생 바(슬라이더)와 재생 위치 점(스크러버)의 배율을 조절합니다." : @"Adjusts slider and scrubber scale in regular playback (portrait, miniplayer, etc.).";
    }
    if ([key isEqualToString:@"T4"]) {
        return isKor ? @"전체 화면 슬라이더 두께" : @"Fullscreen slider thickness";
    }
    if ([key isEqualToString:@"D4"]) {
        return isKor ? @"전체 화면 재생 시의 동영상 재생 바(슬라이더)와 재생 위치 점(스크러버)의 배율을 조절합니다." : @"Adjusts slider and scrubber scale during fullscreen playback.";
    }
    if ([key isEqualToString:@"T5"]) {
        return isKor ? @"Shorts 슬라이더 두께" : @"Shorts slider thickness";
    }
    if ([key isEqualToString:@"D5"]) {
        return isKor ? @"Shorts 재생 시의 동영상 재생 바(슬라이더)와 재생 위치 점(스크러버)의 배율을 조절합니다." : @"Adjusts slider and scrubber scale during Shorts playback.";
    }
    if ([key isEqualToString:@"DEFAULT"]) {
        return isKor ? @"1x (비활성화)" : @"1x (Disabled)";
    }
    return @"";
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

static void applyScrubberCircleScaleIfNeeded(UIView *scrubberCircle, CGFloat scale) {
    if (![scrubberCircle isKindOfClass:[UIView class]]) return;
    BOOL isScaled = fabs(scale - 1.0) > 0.001;
    BOOL wasModified = [objc_getAssociatedObject(scrubberCircle, kBGPModifiedDotKey) boolValue];
    if (!isScaled && !wasModified) return;
    updateScrubberCircleSize(scrubberCircle, isScaled ? scale : 1.0);
    if (isScaled) {
        if (!wasModified) {
            objc_setAssociatedObject(scrubberCircle, kBGPModifiedDotKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        objc_setAssociatedObject(scrubberCircle, kBGPModifiedDotKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
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

@interface YTPlayerViewController : UIViewController
@end

@interface YTMainAppVideoPlayerOverlayView : UIView
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

static BOOL isExcludedAncestorClass(Class cls) {
    if (!cls) return NO;
    const char *name = class_getName(cls);
    if (!name) return NO;
    return strstr(name, "InlineMutedPlayback") != NULL;
}

static BOOL isShortsAncestorClass(Class cls) {
    if (!cls) return NO;
    const char *name = class_getName(cls);
    if (!name) return NO;
    return (strstr(name, "Reel") != NULL || strstr(name, "Shorts") != NULL);
}

static BGPViewContext detectViewContext(UIView *view) {
    if (!view) return BGPViewContextUnknown;
    Class miniBarClass = %c(YTWatchFloatingMiniplayerProgressBarView);
    if (miniBarClass && [view isKindOfClass:miniBarClass]) {
        return BGPViewContextNormalInline;
    }
    if (!view.window) return BGPViewContextUnknown;

    Class overlayClass = %c(YTMainAppVideoPlayerOverlayView);
    NSNumber *cachedKind = objc_getAssociatedObject(view, kBGPCachedKindKey);
    if (cachedKind) {
        NSInteger kind = cachedKind.integerValue;
        if (kind == BGPCachedKindExcluded) return BGPViewContextExcluded;
        if (kind == BGPCachedKindShorts) return BGPViewContextShorts;
        if (kind == BGPCachedKindInline) return BGPViewContextNormalInline;
        if (kind == BGPCachedKindOverlay) {
            if (gNormalSliderPercent == gFullscreenSliderPercent) {
                return BGPViewContextNormalInline;
            }
            CGFloat windowH = CGRectGetHeight(view.window.bounds);
            if (windowH <= 0.0) return BGPViewContextNormalInline;
            UIView *node = view.superview;
            while (node) {
                if (overlayClass && [node isKindOfClass:overlayClass]) {
                    return CGRectGetHeight(node.bounds) >= windowH * 0.82
                        ? BGPViewContextNormalFullscreen
                        : BGPViewContextNormalInline;
                }
                node = node.superview;
            }
            return BGPViewContextNormalInline;
        }
    }

    CGFloat windowH = CGRectGetHeight(view.window.bounds);
    UIView *node = view;
    while (node) {
        if (overlayClass && [node isKindOfClass:overlayClass]) {
            objc_setAssociatedObject(view, kBGPCachedKindKey, @(BGPCachedKindOverlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (windowH > 0.0 && CGRectGetHeight(node.bounds) >= windowH * 0.82) {
                return BGPViewContextNormalFullscreen;
            }
            return BGPViewContextNormalInline;
        }
        if (isExcludedAncestorClass(node.class)) {
            objc_setAssociatedObject(view, kBGPCachedKindKey, @(BGPCachedKindExcluded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return BGPViewContextExcluded;
        }
        if (isShortsAncestorClass(node.class)) {
            objc_setAssociatedObject(view, kBGPCachedKindKey, @(BGPCachedKindShorts), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return BGPViewContextShorts;
        }
        node = node.superview;
    }

    objc_setAssociatedObject(view, kBGPCachedKindKey, @(BGPCachedKindInline), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return BGPViewContextNormalInline;
}

static NSInteger effectiveSliderPercentForView(UIView *view) {
    if (gNormalSliderPercent == 100 &&
        gFullscreenSliderPercent == 100 &&
        gShortsSliderPercent == 100) {
        return 100;
    }
    BGPViewContext ctx = detectViewContext(view);
    if (ctx == BGPViewContextNormalFullscreen) return gFullscreenSliderPercent;
    if (ctx == BGPViewContextShorts) return gShortsSliderPercent;
    if (ctx == BGPViewContextNormalInline) return gNormalSliderPercent;
    return 100;
}

static CGFloat effectiveSliderThicknessScaleForView(UIView *view) {
    NSInteger percent = effectiveSliderPercentForView(view);
    return percent == 100 ? 1.0 : (percent / 100.0);
}

static CGFloat effectiveScrubberDotScaleForView(UIView *view) {
    return scrubberScaleForSliderScale(effectiveSliderThicknessScaleForView(view));
}

static CGRect scaleTrackFrameForView(UIView *view, CGRect frame) {
    if (!view || !gHasModifiedSlider || gApplyingTrackFrame) return frame;

    CGFloat incomingH = frame.size.height;
    if (incomingH <= 0.0) return frame;

    CGFloat scale = effectiveSliderThicknessScaleForView(view);
    BOOL isScaled = fabs(scale - 1.0) > 0.001;
    BOOL wasModified = [objc_getAssociatedObject(view, kBGPModifiedTrackKey) boolValue];
    if (!isScaled && !wasModified) return frame;

    NSNumber *baseNum = objc_getAssociatedObject(view, kBGPBaseHeightKey);
    NSNumber *appliedNum = objc_getAssociatedObject(view, kBGPAppliedHeightKey);
    CGFloat currentH = view.frame.size.height;

    CGFloat baseHeight = 0.0;
    if (baseNum && appliedNum &&
        fabs(incomingH - appliedNum.doubleValue) < 0.05 &&
        fabs(incomingH - currentH) < 0.05) {
        baseHeight = baseNum.doubleValue;
    } else if (incomingH <= 12.0) {
        baseHeight = incomingH;
        if (!baseNum || fabs(baseNum.doubleValue - baseHeight) >= 0.05) {
            objc_setAssociatedObject(view, kBGPBaseHeightKey, @(baseHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        return frame;
    }

    CGFloat targetHeight = isScaled ? (baseHeight * scale) : baseHeight;
    if (isScaled) {
        if (!appliedNum || fabs(appliedNum.doubleValue - targetHeight) >= 0.05) {
            objc_setAssociatedObject(view, kBGPAppliedHeightKey, @(targetHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!wasModified) {
            objc_setAssociatedObject(view, kBGPModifiedTrackKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        if (appliedNum) {
            objc_setAssociatedObject(view, kBGPAppliedHeightKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        objc_setAssociatedObject(view, kBGPModifiedTrackKey, nil, OBJC_ASSOCIATION_ASSIGN);
        if (view.layer.cornerRadius > 0.0) {
            view.layer.cornerRadius = targetHeight / 2.0;
        }
    }

    if (fabs(targetHeight - incomingH) > 0.05) {
        CGFloat midY = CGRectGetMidY(frame);
        frame.origin.y = midY - (targetHeight / 2.0);
        frame.size.height = targetHeight;
    }
    return frame;
}

static void syncTrackViewThickness(UIView *view) {
    if (!view || !gHasModifiedSlider) return;

    CGFloat scale = effectiveSliderThicknessScaleForView(view);
    BOOL isScaled = fabs(scale - 1.0) > 0.001;
    BOOL wasModified = [objc_getAssociatedObject(view, kBGPModifiedTrackKey) boolValue];
    if (!isScaled && !wasModified) return;

    CGRect frame = view.frame;
    if (frame.size.height <= 0.0) return;

    NSNumber *baseNum = objc_getAssociatedObject(view, kBGPBaseHeightKey);
    CGFloat baseHeight = 0.0;
    if (baseNum) {
        baseHeight = baseNum.doubleValue;
    } else if (frame.size.height <= 12.0) {
        baseHeight = frame.size.height;
        objc_setAssociatedObject(view, kBGPBaseHeightKey, @(baseHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        return;
    }

    NSNumber *appliedNum = objc_getAssociatedObject(view, kBGPAppliedHeightKey);
    CGFloat targetHeight = isScaled ? (baseHeight * scale) : baseHeight;
    if (isScaled) {
        if (!appliedNum || fabs(appliedNum.doubleValue - targetHeight) >= 0.05) {
            objc_setAssociatedObject(view, kBGPAppliedHeightKey, @(targetHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!wasModified) {
            objc_setAssociatedObject(view, kBGPModifiedTrackKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        if (appliedNum) {
            objc_setAssociatedObject(view, kBGPAppliedHeightKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        objc_setAssociatedObject(view, kBGPModifiedTrackKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }

    if (fabs(targetHeight - frame.size.height) > 0.05) {
        CGFloat midY = CGRectGetMidY(frame);
        frame.origin.y = midY - (targetHeight / 2.0);
        frame.size.height = targetHeight;
        gApplyingTrackFrame = YES;
        view.frame = frame;
        gApplyingTrackFrame = NO;
    }
    if (view.layer.cornerRadius > 0.0) {
        CGFloat expectedRadius = view.bounds.size.height / 2.0;
        if (fabs(view.layer.cornerRadius - expectedRadius) > 0.05) {
            view.layer.cornerRadius = expectedRadius;
        }
    }
}

static void forceDecorationScaleRefresh(YTPlayerBarScrubberDotDecorationView *decorationView) {
    if (![decorationView respondsToSelector:@selector(transformScrubberScale:)]) return;
    CGFloat youtubeScale = kYouTubeScrubberScale;
    @try {
        NSInteger scaleEnum = [[decorationView valueForKey:@"_scrubberDotDecorationScale"] integerValue];
        if (scaleEnum <= 0) {
            return;
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

    Class overlayClass = %c(YTMainAppVideoPlayerOverlayView);
    if (overlayClass && [view isKindOfClass:overlayClass]) {
        if (view.window) {
            CGFloat windowH = CGRectGetHeight(view.window.bounds);
            BOOL isFull = (windowH > 0.0 && CGRectGetHeight(view.bounds) >= windowH * 0.82);
            NSNumber *prevFull = objc_getAssociatedObject(view, kBGPWasFullscreenKey);
            if (!prevFull || prevFull.boolValue != isFull) {
                objc_setAssociatedObject(view, kBGPWasFullscreenKey, @(isFull), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        } else if (objc_getAssociatedObject(view, kBGPWasFullscreenKey)) {
            objc_setAssociatedObject(view, kBGPWasFullscreenKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
    }

    Class rectClass = %c(YTPlayerBarRectangleDecorationView);
    Class progressClass = %c(YTPlayerBarProgressDecorationView);
    Class segClass = %c(YTPlayerBarSegmentView);
    Class miniBarClass = %c(YTWatchFloatingMiniplayerProgressBarView);
    Class dotDecorationClass = %c(YTPlayerBarScrubberDotDecorationView);

    if ((rectClass && [view isKindOfClass:rectClass]) ||
        (progressClass && [view isKindOfClass:progressClass]) ||
        (segClass && [view isKindOfClass:segClass]) ||
        (miniBarClass && [view isKindOfClass:miniBarClass])) {
        syncTrackViewThickness(view);
    }

    const char *rawName = class_getName(view.class);
    if (rawName && (strstr(rawName, "PlayerBar") != NULL || strstr(rawName, "MiniplayerProgressBar") != NULL)) {
        BOOL isScaled = (effectiveSliderPercentForView(view) != 100);
        BOOL wasModified = [objc_getAssociatedObject(view, kBGPModifiedContainerKey) boolValue];
        if (isScaled) {
            if (view.clipsToBounds) {
                view.clipsToBounds = NO;
            }
            if (!wasModified) {
                objc_setAssociatedObject(view, kBGPModifiedContainerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            [view setNeedsLayout];
            [view setNeedsDisplay];
        } else if (wasModified) {
            objc_setAssociatedObject(view, kBGPModifiedContainerKey, nil, OBJC_ASSOCIATION_ASSIGN);
            [view setNeedsLayout];
            [view setNeedsDisplay];
        }
        UIView *scrubberCircle = safeGetObjectIvar(view, "_scrubberCircle");
        if (scrubberCircle) {
            applyScrubberCircleScaleIfNeeded(scrubberCircle, effectiveScrubberDotScaleForView(view));
        }
    }

    if (dotDecorationClass && [view isKindOfClass:dotDecorationClass]) {
        CGFloat dotScale = effectiveScrubberDotScaleForView(view);
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(view, "_defaultScrubberDot"), dotScale);
        BOOL isScaled = fabs(dotScale - 1.0) > 0.001;
        BOOL wasModified = [objc_getAssociatedObject(view, kBGPModifiedDotKey) boolValue];
        if (isScaled || wasModified) {
            forceDecorationScaleRefresh((YTPlayerBarScrubberDotDecorationView *)view);
        }
    }

    for (UIView *subview in view.subviews) {
        relayoutVisiblePlayerBars(subview, depth + 1);
    }
}

static void schedulePlayerBarRelayout(UIView *rootView) {
    if (!rootView) return;
    if ([objc_getAssociatedObject(rootView, kBGPRelayoutPendingKey) boolValue]) return;
    objc_setAssociatedObject(rootView, kBGPRelayoutPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakRoot = rootView;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongRoot = weakRoot;
        if (!strongRoot) return;
        objc_setAssociatedObject(strongRoot, kBGPRelayoutPendingKey, nil, OBJC_ASSOCIATION_ASSIGN);
        if (strongRoot.window) {
            relayoutVisiblePlayerBars(strongRoot, 0);
        }
    });
}

static UIView *findPlayerOverlayView(UIView *view, NSUInteger depth) {
    if (!view || depth > 5) return nil;
    Class overlayClass = %c(YTMainAppVideoPlayerOverlayView);
    if (overlayClass && [view isKindOfClass:overlayClass]) return view;
    for (UIView *sub in view.subviews) {
        UIView *found = findPlayerOverlayView(sub, depth + 1);
        if (found) return found;
    }
    return nil;
}

static void refreshAllPlayerBars() {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            relayoutVisiblePlayerBars(window, 0);
        }
    }
}

static id buildThicknessPickerItem(NSString *title,
                                   NSString *desc,
                                   NSArray<NSNumber *> *presets,
                                   NSString *defaultsKey,
                                   NSInteger *percentPtr,
                                   BOOL *contextModifiedPtr,
                                   YTSettingsSectionItemManager *manager,
                                   id targetDelegate) {
    __weak YTSettingsSectionItemManager *weakManager = manager;
    __weak id weakDelegate = targetDelegate;
    return [%c(YTSettingsSectionItem) itemWithTitle:title
        titleDescription:desc
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            NSInteger percent = *percentPtr;
            if (percent == 100) return loadText(@"DEFAULT");
            return [NSString stringWithFormat:@"%.3gx", percent / 100.0];
        }
        selectBlock:^BOOL (id cell, NSUInteger arg1) {
            id strongDelegate = weakDelegate;
            YTSettingsSectionItemManager *strongManager = weakManager;
            NSInteger currentPercent = *percentPtr;
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
                        *percentPtr = val;
                        if (val != 100) {
                            gHasModifiedSlider = YES;
                            if (contextModifiedPtr) *contextModifiedPtr = YES;
                        }
                        [[NSUserDefaults standardUserDefaults] setInteger:val forKey:defaultsKey];
                        if (gHasModifiedSlider) {
                            refreshAllPlayerBars();
                        }
                        id reloadTarget = weakDelegate;
                        if ([reloadTarget respondsToSelector:@selector(reloadData)]) {
                            [reloadTarget reloadData];
                        }
                        return YES;
                    }];
                [rows addObject:rowItem];
            }

            Class pickerClass = %c(YTSettingsPickerViewController);
            if (pickerClass && [strongDelegate respondsToSelector:@selector(pushViewController:)]) {
                id parentResp = [strongManager respondsToSelector:@selector(parentResponder)] ? [strongManager parentResponder] : nil;
                UIViewController *picker = [[pickerClass alloc] initWithNavTitle:title
                    pickerSectionTitle:nil
                    rows:rows
                    selectedItemIndex:selectedIndex
                    parentResponder:parentResp];
                [strongDelegate pushViewController:picker];
            }
            return YES;
        }];
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

%hook YTMainAppVideoPlayerOverlayView
- (void)layoutSubviews {
    %orig;
    if (!gHasModifiedSlider || gNormalSliderPercent == gFullscreenSliderPercent || !self.window) return;
    CGFloat windowH = CGRectGetHeight(self.window.bounds);
    BOOL isFull = (windowH > 0.0 && CGRectGetHeight(self.bounds) >= windowH * 0.82);
    NSNumber *prevFull = objc_getAssociatedObject(self, kBGPWasFullscreenKey);
    if (!prevFull || prevFull.boolValue != isFull) {
        objc_setAssociatedObject(self, kBGPWasFullscreenKey, @(isFull), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        schedulePlayerBarRelayout(self);
    }
}
%end

%hook YTPlayerViewController
- (void)setPlayerViewLayout:(NSInteger)layout {
    %orig;
    if (gHasModifiedSlider && gNormalSliderPercent != gFullscreenSliderPercent) {
        __weak YTPlayerViewController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            YTPlayerViewController *strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.isViewLoaded) return;
            UIView *rootView = strongSelf.view;
            if (!rootView.window) return;
            UIView *overlay = findPlayerOverlayView(rootView, 0);
            if (overlay) {
                CGFloat windowH = CGRectGetHeight(overlay.window.bounds);
                BOOL isFull = (windowH > 0.0 && CGRectGetHeight(overlay.bounds) >= windowH * 0.82);
                NSNumber *prevFull = objc_getAssociatedObject(overlay, kBGPWasFullscreenKey);
                if (prevFull && prevFull.boolValue == isFull) {
                    return;
                }
                objc_setAssociatedObject(overlay, kBGPWasFullscreenKey, @(isFull), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                schedulePlayerBarRelayout(overlay);
                return;
            }
            schedulePlayerBarRelayout(rootView);
        });
    }
}
%end

%hook YTPlayerBarRectangleDecorationView
- (void)setFrame:(CGRect)frame {
    if (!gHasModifiedSlider) {
        %orig;
        return;
    }
    %orig(scaleTrackFrameForView(self, frame));
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        syncTrackViewThickness(self);
    }
}

- (void)layoutSubviews {
    %orig;
    if (gHasModifiedSlider &&
        self.layer.cornerRadius > 0.0 &&
        fabs(effectiveSliderThicknessScaleForView(self) - 1.0) > 0.001) {
        CGFloat expectedRadius = self.bounds.size.height / 2.0;
        if (fabs(self.layer.cornerRadius - expectedRadius) > 0.05) {
            self.layer.cornerRadius = expectedRadius;
        }
    }
}
%end

%hook YTPlayerBarProgressDecorationView
- (void)setFrame:(CGRect)frame {
    if (!gHasModifiedSlider) {
        %orig;
        return;
    }
    %orig(scaleTrackFrameForView(self, frame));
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        syncTrackViewThickness(self);
    }
}

- (void)layoutSubviews {
    %orig;
    if (gHasModifiedSlider &&
        self.layer.cornerRadius > 0.0 &&
        fabs(effectiveSliderThicknessScaleForView(self) - 1.0) > 0.001) {
        CGFloat expectedRadius = self.bounds.size.height / 2.0;
        if (fabs(self.layer.cornerRadius - expectedRadius) > 0.05) {
            self.layer.cornerRadius = expectedRadius;
        }
    }
}
%end

%hook YTPlayerBarSegmentView
- (void)setFrame:(CGRect)frame {
    if (!gHasModifiedSlider) {
        %orig;
        return;
    }
    %orig(scaleTrackFrameForView(self, frame));
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        syncTrackViewThickness(self);
    }
}
%end

%hook YTPlayerBarScrubberDotDecorationView
- (id)initWithModel:(id)model {
    self = %orig;
    if (self && gHasModifiedSlider) {
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_defaultScrubberDot"), effectiveScrubberDotScaleForView(self));
    }
    return self;
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        CGFloat dotScale = effectiveScrubberDotScaleForView(self);
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_defaultScrubberDot"), dotScale);
        BOOL isScaled = fabs(dotScale - 1.0) > 0.001;
        BOOL wasModified = [objc_getAssociatedObject(self, kBGPModifiedDotKey) boolValue];
        if (isScaled || wasModified) {
            __weak YTPlayerBarScrubberDotDecorationView *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                YTPlayerBarScrubberDotDecorationView *strongSelf = weakSelf;
                if (strongSelf && strongSelf.window) {
                    forceDecorationScaleRefresh(strongSelf);
                }
            });
        }
    }
}
%end

%hook YTPlayerBarScrubberDotDecorationViewV2
- (void)transformScrubberScale:(CGFloat)scale {
    if (!gHasModifiedSlider) {
        %orig;
        return;
    }
    CGFloat dotScale = effectiveScrubberDotScaleForView(self);
    if (fabs(dotScale - 1.0) > 0.001) {
        if (!objc_getAssociatedObject(self, kBGPModifiedDotKey)) {
            objc_setAssociatedObject(self, kBGPModifiedDotKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        scale *= dotScale;
    } else if (objc_getAssociatedObject(self, kBGPModifiedDotKey)) {
        objc_setAssociatedObject(self, kBGPModifiedDotKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    %orig(scale);
}
%end

%hook YTModularPlayerBarView
- (id)initWithModel:(id)model delegate:(id)delegate {
    self = %orig;
    if (self && gHasModifiedSlider) {
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_scrubberCircle"), effectiveScrubberDotScaleForView(self));
    }
    return self;
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        BOOL isScaled = (effectiveSliderPercentForView(self) != 100);
        BOOL wasModified = [objc_getAssociatedObject(self, kBGPModifiedContainerKey) boolValue];
        if (isScaled || wasModified) {
            schedulePlayerBarRelayout(self);
        }
    }
}

- (void)layoutSubviews {
    %orig;
    if (!gHasModifiedSlider) return;
    if (fabs(effectiveSliderThicknessScaleForView(self) - 1.0) <= 0.001) return;

    if (self.clipsToBounds) {
        self.clipsToBounds = NO;
    }
    if (!objc_getAssociatedObject(self, kBGPModifiedContainerKey)) {
        objc_setAssociatedObject(self, kBGPModifiedContainerKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

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
    if (self && gHasModifiedSlider) {
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_scrubberCircle"), effectiveScrubberDotScaleForView(self));
    }
    return self;
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_scrubberCircle"), effectiveScrubberDotScaleForView(self));
    }
}
%end

%hook YTInlinePlayerBarView
- (id)init {
    self = %orig;
    if (self && gHasModifiedSlider) {
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_scrubberCircle"), effectiveScrubberDotScaleForView(self));
    }
    return self;
}

- (void)didMoveToWindow {
    %orig;
    if (!gHasModifiedSlider) return;
    if (objc_getAssociatedObject(self, kBGPCachedKindKey)) {
        objc_setAssociatedObject(self, kBGPCachedKindKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    if (self.window) {
        applyScrubberCircleScaleIfNeeded(safeGetObjectIvar(self, "_scrubberCircle"), effectiveScrubberDotScaleForView(self));
    }
}

- (void)layoutSubviews {
    %orig;
    if (!gHasModifiedSlider) return;
    UIView *playingProgress = safeGetObjectIvar(self, "_playingProgress");
    if (![playingProgress isKindOfClass:[UIView class]]) return;

    CGFloat scale = effectiveSliderThicknessScaleForView(self);
    BOOL isScaled = fabs(scale - 1.0) > 0.001;
    BOOL wasModified = [objc_getAssociatedObject(playingProgress, kBGPModifiedTrackKey) boolValue];
    if (!isScaled && !wasModified) return;

    if (isScaled && self.clipsToBounds) {
        self.clipsToBounds = NO;
    }
    CGRect scaled = scaleTrackFrameForView(playingProgress, playingProgress.frame);
    if (!CGRectEqualToRect(scaled, playingProgress.frame)) {
        playingProgress.frame = scaled;
    }
}
%end

%hook YTWatchFloatingMiniplayerProgressBarView
- (void)setFrame:(CGRect)frame {
    if (!gHasModifiedNormal) {
        %orig;
        return;
    }
    %orig(scaleTrackFrameForView(self, frame));
}

- (void)didMoveToWindow {
    %orig;
    if (self.window && gHasModifiedNormal) {
        syncTrackViewThickness(self);
    }
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

    NSArray<NSNumber *> *compactPresets = @[@50, @75, @100, @125, @150, @200, @250];
    NSArray<NSNumber *> *fullscreenPresets = @[@50, @75, @100, @125, @150, @200, @250, @300, @400];

    [uiItems addObject:buildThicknessPickerItem(loadText(@"T3"), loadText(@"D3"), compactPresets, kBGPNormalSliderKey, &gNormalSliderPercent, &gHasModifiedNormal, self, targetDelegate)];
    [uiItems addObject:buildThicknessPickerItem(loadText(@"T4"), loadText(@"D4"), fullscreenPresets, kBGPFullscreenSliderKey, &gFullscreenSliderPercent, NULL, self, targetDelegate)];
    [uiItems addObject:buildThicknessPickerItem(loadText(@"T5"), loadText(@"D5"), compactPresets, kBGPShortsSliderKey, &gShortsSliderPercent, NULL, self, targetDelegate)];

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
        kBGPNormalSliderKey: @100,
        kBGPFullscreenSliderKey: @100,
        kBGPShortsSliderKey: @100,
    }];
    gBGPState = [defaults boolForKey:kBGPStateKey];
    gHideDIState = [defaults boolForKey:kBGPHideDIKey];
    gNormalSliderPercent = sanitizeSliderPercent([defaults integerForKey:kBGPNormalSliderKey]);
    gFullscreenSliderPercent = sanitizeSliderPercent([defaults integerForKey:kBGPFullscreenSliderKey]);
    gShortsSliderPercent = sanitizeSliderPercent([defaults integerForKey:kBGPShortsSliderKey]);
    gHasModifiedNormal = (gNormalSliderPercent != 100);
    gHasModifiedSlider = (gNormalSliderPercent != 100 || gFullscreenSliderPercent != 100 || gShortsSliderPercent != 100);
}
