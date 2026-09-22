# TranslateBar

TranslateBar is an independent menu bar translation utility for macOS.

## Features

- Compact menu bar interface
- On-device translation powered by macOS
- Automatic source language detection
- Global keyboard shortcut
- Optional clipboard translation
- macOS Services integration for selected text
- Dictation and spoken translations

## Requirements

- macOS 15 or later
- Xcode 16 or later

## Build and run

```bash
./script/build_and_run.sh
```

The script builds the Xcode app target and creates `dist/TranslateBar.app`.

You can also open `TranslateBar.xcodeproj` in Xcode to run, archive, and distribute the app.

## Test

```bash
./script/verify_all.sh
```

## Privacy

Translation is handled by macOS on the device. Clipboard text is processed only when automatic clipboard translation is enabled. Dictation requires microphone and speech recognition permissions and is configured for on-device recognition. TranslateBar does not include analytics, advertising, or third-party translation services. See [PRIVACY.md](PRIVACY.md) or the [public privacy policy](https://www.arenovo.com/projects/translatebar/privacy/).

## Website

The public website is maintained in the [Arenovo repository](https://github.com/iwbinb/arenovo/tree/main/projects/translatebar).

- Product: https://www.arenovo.com/projects/translatebar/
- Privacy: https://www.arenovo.com/projects/translatebar/privacy/
- Support: https://www.arenovo.com/projects/translatebar/support/

`Website/` is now only the legacy-domain redirect bundle. It contains Cloudflare Pages 301 rules and small HTML fallbacks; do not add product content there.

### Migration release order

1. Publish the Arenovo changes first and verify all three pages, images, and navigation at the URLs above.
2. Verify the existing legacy host serves the `Website/` directory through Cloudflare Pages before publishing this redirect bundle. If the host uses a different platform, configure equivalent HTTP 301 redirects there.
3. Keep `translatebar.arenovo.com` and its TLS/domain binding active. Verify `/`, `/privacy/`, and `/support/` redirect to their corresponding new pages, including links opened from an older app version.
4. Update Marketing URL, Support URL, and Privacy Policy URL in App Store Connect wherever they still reference the old domain. Ship the updated in-app links with the next app release.

## License

TranslateBar is available under the MIT License. See [LICENSE](LICENSE).
