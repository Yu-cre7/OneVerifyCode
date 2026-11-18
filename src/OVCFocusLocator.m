#import "OVCFocusLocator.h"
#import <ApplicationServices/ApplicationServices.h>

@implementation OVCFocusLocator

+ (BOOL)accessibilityTrusted {
    return AXIsProcessTrusted();
}

+ (void)promptAccessibilityIfNeeded {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

+ (CGRect)focusedElementRect {
    if (!AXIsProcessTrusted()) { return NSZeroRect; }

    AXUIElementRef system = AXUIElementCreateSystemWide();
    if (!system) { return NSZeroRect; }

    CFTypeRef focused = NULL;
    AXError focusError = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute, &focused);
    CFRelease(system);
    if (focusError != kAXErrorSuccess || focused == NULL) {
        if (focused) { CFRelease(focused); }
        return NSZeroRect;
    }

    AXUIElementRef element = (AXUIElementRef)focused;
    CGPoint origin = CGPointZero;
    CGSize size = CGSizeZero;

    CFTypeRef positionValue = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXPositionAttribute, &positionValue) == kAXErrorSuccess && positionValue) {
        AXValueGetValue((AXValueRef)positionValue, kAXValueTypeCGPoint, &origin);
        CFRelease(positionValue);
    }
    CFTypeRef sizeValue = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &sizeValue) == kAXErrorSuccess && sizeValue) {
        AXValueGetValue((AXValueRef)sizeValue, kAXValueTypeCGSize, &size);
        CFRelease(sizeValue);
    }
    CFRelease(element);

    if (size.width <= 1.0 || size.height <= 1.0) { return NSZeroRect; }

    NSScreen *primary = NSScreen.screens.firstObject;
    if (!primary) { return NSZeroRect; }
    CGFloat primaryHeight = primary.frame.size.height;

    return CGRectMake(origin.x, primaryHeight - origin.y - size.height, size.width, size.height);
}

+ (CGRect)focusedTextInputRect {
    if (![self focusedElementIsTextInput]) { return NSZeroRect; }
    return [self focusedElementRect];
}

+ (BOOL)focusedElementIsTextInput {
    if (!AXIsProcessTrusted()) { return NO; }

    AXUIElementRef system = AXUIElementCreateSystemWide();
    if (!system) { return NO; }
    CFTypeRef focused = NULL;
    AXError error = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute, &focused);
    CFRelease(system);
    if (error != kAXErrorSuccess || focused == NULL) {
        if (focused) { CFRelease(focused); }
        return NO;
    }

    AXUIElementRef element = (AXUIElementRef)focused;
    BOOL editable = NO;
    NSString *role = nil;
    NSString *subrole = nil;

    CFTypeRef roleValue = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &roleValue) == kAXErrorSuccess && roleValue) {
        if (CFGetTypeID(roleValue) == CFStringGetTypeID()) { role = (__bridge NSString *)roleValue; }
        CFRelease(roleValue);
    }
    CFTypeRef subroleValue = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &subroleValue) == kAXErrorSuccess && subroleValue) {
        if (CFGetTypeID(subroleValue) == CFStringGetTypeID()) { subrole = (__bridge NSString *)subroleValue; }
        CFRelease(subroleValue);
    }
    CFTypeRef editableValue = NULL;
    if (AXUIElementCopyAttributeValue(element, CFSTR("AXEditable"), &editableValue) == kAXErrorSuccess && editableValue) {
        if (CFGetTypeID(editableValue) == CFBooleanGetTypeID()) {
            editable = CFBooleanGetValue((CFBooleanRef)editableValue);
        }
        CFRelease(editableValue);
    }
    CFRelease(element);

    if ([subrole isEqualToString:(__bridge NSString *)kAXSecureTextFieldSubrole]) { return NO; }
    BOOL knownRole = [role isEqualToString:(__bridge NSString *)kAXTextFieldRole] ||
                     [role isEqualToString:(__bridge NSString *)kAXTextAreaRole] ||
                     [role isEqualToString:(__bridge NSString *)kAXComboBoxRole];
    return editable && knownRole;
}

+ (BOOL)sendPasteShortcut {
    if (!AXIsProcessTrusted()) { return NO; }

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef down = CGEventCreateKeyboardEvent(source, (CGKeyCode)9, true);
    CGEventRef up = CGEventCreateKeyboardEvent(source, (CGKeyCode)9, false);
    if (down) {
        CGEventSetFlags(down, kCGEventFlagMaskCommand);
        CGEventPost(kCGHIDEventTap, down);
        CFRelease(down);
    }
    if (up) {
        CGEventSetFlags(up, kCGEventFlagMaskCommand);
        CGEventPost(kCGHIDEventTap, up);
        CFRelease(up);
    }
    BOOL ok = down != NULL;
    if (source) { CFRelease(source); }
    return ok;
}

+ (void)openAccessibilitySettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

+ (void)openFullDiskAccessSettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

@end
