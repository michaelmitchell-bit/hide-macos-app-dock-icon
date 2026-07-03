# dockless-agent

Run any macOS app as a background **agent** — no Dock icon, no ⌘-Tab entry —
even apps that insist on showing themselves in the Dock.

`LSUIElement`/`LSBackgroundOnly` in an app's `Info.plist` are supposed to hide
it from the Dock, but many apps override that at runtime by calling
`-[NSApplication setActivationPolicy:]` (often through a dynamically-registered
selector, so editing the plist or byte-patching the binary won't reliably stop
them). `dockless-agent` replaces that method's implementation with a tiny
injected library, so **every** activation-policy call resolves to
`Accessory` — the app runs windowed but Dock-less.

## How it works

1. `src/dockless.m` swizzles `-[NSApplication setActivationPolicy:]` to always
   pass `NSApplicationActivationPolicyAccessory`.
2. `install.sh` builds it into a universal dylib, then adds
   `LSEnvironment → DYLD_INSERT_LIBRARIES` to the target app's `Info.plist` so
   the hook loads on every launch, and ad-hoc re-signs the app.

## Usage

```sh
sudo ./install.sh /Applications/SomeApp.app
# restart the app, then verify:
lsappinfo info -app <bundle-id> | grep type=   # expect type="UIElement"
```

Undo:

```sh
sudo ./uninstall.sh /Applications/SomeApp.app
```

## Surviving app updates

An app that auto-updates will overwrite its `Info.plist` and revert the change.
Install a watcher that re-applies it automatically:

```sh
sudo ./launchagent/setup-autoreapply.sh /Applications/SomeApp.app
```

## Caveats

- **Re-signing changes the app's code identity.** macOS may ask you to
  re-grant Privacy permissions (Screen Recording, Accessibility, etc.) the
  first time after installing.
- This drops the app's original Developer ID signature in favor of an ad-hoc
  one, and disables its hardened runtime (required for `DYLD_INSERT_LIBRARIES`
  to be honored). Only do this to apps you trust on machines you control.
- Requires the Xcode Command Line Tools (`clang`) and admin rights.
- Tested on Apple Silicon, macOS 14/15.

## Scope

This only affects Dock/⌘-Tab visibility (an app's activation policy). It does
not touch, hide, or suppress any macOS privacy or security indicators.

## License

MIT — see [LICENSE](LICENSE).
