//
//  ShortcutsController.m
//  EmacsCtl
//
//  Created by Tony Tang on 2023/12/12.
//

#import "ShortcutsController.h"

#import <MASShortcut/Shortcut.h>

#import "EmacsCtl-Swift.h"

@implementation ShortcutsController

+ (void)bindShortcuts {
    MASShortcutBinder *binder = [MASShortcutBinder sharedBinder];
    [binder bindShortcutWithDefaultsKey:@"SwitchToEmacs" toAction:^{
        [EmacsControl switchToEmacs];
    }];
}

@end
