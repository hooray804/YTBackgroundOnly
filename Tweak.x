#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString * const kBGPStateKey = @"BGPToggleStatus";
static const NSInteger kBGPSectionID = 2610;
static const NSInteger kTweakGroupID = 'psyt';

static BOOL fetchBGPState() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kBGPStateKey];
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
    if ([key isEqualToString:@"T"]) {
        return @"YTBackgroundOnly";
    }
    if ([key isEqualToString:@"D"]) {
        return isKor ? @"앱을 종료하거나 화면을 꺼도 오디오 재생을 유지하며, '동영상이 일시중지되었습니다. 이어서 시청하시겠습니까?' 시청 확인창을 차단합니다." : @"Allows audio to continue playing in the background and prevents the 'Video paused. Continue watching?' prompt.";
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
    if (fetchBGPState()) {
        return YES;
    }
    return %orig;
}
%end

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground {
    if (fetchBGPState()) {
        return YES;
    }
    return %orig;
}
%end

%hook YTPlaybackData
- (BOOL)isPlayableInBackground {
    if (fetchBGPState()) {
        return YES;
    }
    return %orig;
}
%end

%hook YTIPlayerResponse
- (BOOL)isPlayableInBackground {
    if (fetchBGPState()) {
        return YES;
    }
    return %orig;
}
%end

%hook YTColdConfig
- (BOOL)enableYouthereCommandsOnIos {
    if (fetchBGPState()) {
        return NO;
    }
    return %orig;
}
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt {
    if (fetchBGPState()) {
        return NO;
    }
    return %orig;
}
- (void)showYouTherePrompt {
    if (!fetchBGPState()) {
        %orig;
    }
}
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt {
    if (fetchBGPState()) {
        return NO;
    }
    return %orig;
}
- (void)showYouTherePrompt {
    if (!fetchBGPState()) {
        %orig;
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

    if (isYouGroupSettingsActive()) {
        return groups;
    }

    for (id item in groups) {
        if (isTweakGroupItem(item)) {
            return groups;
        }
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
        if (origTitle && origTitle.length > 0) {
            return origTitle;
        }
        return @"Tweaks";
    }
    return %orig;
}

- (NSArray <NSNumber *> *)orderedCategoriesForGroupType:(NSUInteger)type {
    NSArray *baseArr = %orig;
    if (type == kTweakGroupID) {
        NSMutableArray *modArr = baseArr ? [baseArr mutableCopy] : [NSMutableArray array];
        if (![modArr containsObject:@(kBGPSectionID)]) {
            [modArr addObject:@(kBGPSectionID)];
        }
        return modArr.copy;
    }
    return baseArr;
}

- (NSArray <NSNumber *> *)orderedCategories {
    NSArray *baseArr = %orig;
    if (self.type == kTweakGroupID) {
        NSMutableArray *modArr = baseArr ? [baseArr mutableCopy] : [NSMutableArray array];
        if (![modArr containsObject:@(kBGPSectionID)]) {
            [modArr addObject:@(kBGPSectionID)];
        }
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
    id tSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:loadText(@"T")
        titleDescription:loadText(@"D")
        accessibilityIdentifier:nil
        switchOn:fetchBGPState()
        switchBlock:^BOOL (id cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kBGPStateKey];
            return YES;
        }
        settingItemId:0];
    
    [uiItems addObject:tSwitch];

    YTIIcon *iConfig = [%c(YTIIcon) new];
    if ([iConfig respondsToSelector:@selector(setIconType:)]) {
        iConfig.iconType = 44;
    }

    if ([targetDelegate respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        [targetDelegate setSectionItems:uiItems forCategory:kBGPSectionID title:loadText(@"T") icon:iConfig titleDescription:nil headerHidden:NO];
    } else if ([targetDelegate respondsToSelector:@selector(setSectionItems:forCategory:title:titleDescription:headerHidden:)]) {
        [targetDelegate setSectionItems:uiItems forCategory:kBGPSectionID title:loadText(@"T") titleDescription:nil headerHidden:NO];
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
    }];
}
