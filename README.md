# TranslateBar

TranslateBar is an independent menu bar translation utility for macOS.

## Features

- Compact menu bar interface
- Automatic source language detection
- Global keyboard shortcut
- Optional clipboard translation
- macOS Services integration for selected text
- Dictation and spoken translations

## Requirements

- macOS 14 or later
- Xcode Command Line Tools

## Build and run

```bash
./script/build_and_run.sh
```

The application bundle will be created at `dist/TranslateBar.app`.

## Test

```bash
./script/verify_all.sh
```

## Privacy

Text submitted for translation is sent to a remote translation service. Clipboard text is processed only when automatic clipboard translation is enabled. Dictation requires microphone and speech recognition permissions. TranslateBar does not include analytics or advertising.

## License

TranslateBar is available under the MIT License. See [LICENSE](LICENSE).
