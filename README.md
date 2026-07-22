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

Translation is handled by macOS on the device. Clipboard text is processed only when automatic clipboard translation is enabled. Dictation requires microphone and speech recognition permissions and is configured for on-device recognition. TranslateBar does not include analytics, advertising, or third-party translation services. See [PRIVACY.md](PRIVACY.md) or the [public privacy policy](https://translatebar.arenovo.com/privacy/).

## License

TranslateBar is available under the MIT License. See [LICENSE](LICENSE).
