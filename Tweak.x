#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

static NSString * const kBGPStateKey = @"BGPToggleStatus";
static NSString * const kBGPHideDIKey = @"BGPHideDIToggleStatus";
static const NSInteger kBGPSectionID = 2610;
static const NSInteger kTweakGroupID = 'psyt';

static BOOL fetchBGPState() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kBGPStateKey];
}

static BOOL fetchHideDIState() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kBGPHideDIKey];
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
    return @"";
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
@end

@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSArray *)items forCategory:(NSInteger)category title:(NSString *)title icon:(id)icon titleDescription:(NSString *)desc headerHidden:(BOOL)hidden;
- (void)setSectionItems:(NSArray *)items forCategory:(NSInteger)category title:(NSString *)title titleDescription:(NSString *)desc headerHidden:(BOOL)hidden;
@end

@interface YTSettingsSectionItemManager : NSObject
- (void)buildCustomBGPSection:(id)entry;
@end

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
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBGPHideDIKey];
            if (enabled) {
                [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
            }
            return YES;
        }
        settingItemId:1];
    [uiItems addObject:diSwitch];

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
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kBGPStateKey: @NO,
        kBGPHideDIKey: @NO,
    }];
}
