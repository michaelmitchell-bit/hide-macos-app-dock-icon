// dockless.m — force a macOS app to run as a background "agent" (Accessory)
//
// Some apps ship with LSUIElement/LSBackgroundOnly but then promote themselves
// into the Dock at runtime by calling -[NSApplication setActivationPolicy:]
// (often via a dynamically-registered selector, so a static plist flag or a
// binary patch can't reliably stop it). This library replaces that method's
// implementation so every call resolves to NSApplicationActivationPolicyAccessory:
// no Dock icon, no Cmd-Tab entry, but windows still work.
//
// Injected via DYLD_INSERT_LIBRARIES (see install.sh, which wires it into the
// target app's Info.plist LSEnvironment so it applies on every launch).
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static BOOL (*orig_setActivationPolicy)(id, SEL, NSInteger);

static BOOL forced_setActivationPolicy(id self, SEL _cmd, NSInteger policy) {
    (void)policy; // ignore requested policy; always run as a background agent
    return orig_setActivationPolicy(self, _cmd, NSApplicationActivationPolicyAccessory);
}

__attribute__((constructor))
static void dockless_install(void) {
    Class cls = objc_getClass("NSApplication");
    if (!cls) return;
    SEL sel = sel_registerName("setActivationPolicy:");
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    orig_setActivationPolicy = (BOOL (*)(id, SEL, NSInteger))method_getImplementation(m);
    method_setImplementation(m, (IMP)forced_setActivationPolicy);
}
