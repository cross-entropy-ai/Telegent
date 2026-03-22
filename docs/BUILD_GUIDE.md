# Building Telegent (Telegram iOS) from Source

## Prerequisites

- macOS 26+ (Tahoe)
- Xcode 26.2+ (install from App Store or developer.apple.com)
- Python 3
- Git
- An Apple Developer account (for device deployment)

## 1. Clone the Repository

```bash
git clone --recursive https://github.com/cross-entropy-ai/Telegent.git
cd Telegent
```

If you already cloned without `--recursive`, initialize submodules manually:

```bash
git submodule update --init --recursive
```

**Note:** Two submodules (`tgcalls` and `rlottie`) point to upstream TelegramMessenger repos. If `git submodule update` fails for any submodule, check the `.gitmodules` URLs.

After cloning, verify that submodule directories are not empty. Some submodules may check out with an empty working tree. If you find an empty submodule directory (e.g. `third-party/dav1d/dav1d/` has no files), fix it:

```bash
cd third-party/dav1d/dav1d
git checkout HEAD -- .
cd -
```

## 2. Configure the Build

Copy the template configuration and fill in your values:

```bash
cp build-system/template_minimal_development_configuration.json \
   build-system/my_development_configuration.json
```

Edit `build-system/my_development_configuration.json`:

```json
{
    "bundle_id": "com.yourcompany.telegram",
    "api_id": "<get from https://my.telegram.org/apps>",
    "api_hash": "<get from https://my.telegram.org/apps>",
    "team_id": "<your Apple Developer Team ID>",
    "app_center_id": "0",
    "is_internal_build": "true",
    "is_appstore_build": "false",
    "appstore_id": "0",
    "app_specific_url_scheme": "tg",
    "premium_iap_product_id": "",
    "enable_siri": false,
    "enable_icloud": false
}
```

## 3. Generate the Xcode Project

```bash
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=build-system/my_development_configuration.json \
    --xcodeManagedCodesigning \
    --disableProvisioningProfiles
```

If your Xcode version doesn't match the one in `versions.json`, add `--overrideXcodeVersion`. You can also update the `"xcode"` field in `versions.json` to match your installed version.

The first run downloads Bazel automatically and generates `Telegram/Telegram.xcodeproj`.

## 4. Build with Bazel (CLI)

```bash
./build-input/bazel-*/bazel build \
    //Telegram:Telegram \
    --ios_multi_cpus=arm64 \
    --define=buildNumber=10000 \
    --define=telegramVersion=12.5 \
    --//Telegram:disableExtensions \
    --//Telegram:disableStripping \
    --disk_cache="$HOME/telegram-bazel-cache" \
    --verbose_failures
```

The output is `bazel-bin/Telegram/Telegram.ipa`.

The first build takes ~20 minutes. Subsequent builds are much faster thanks to the disk cache.

## 5. Install on Device

```bash
# List connected devices
xcrun devicectl list devices

# Install
xcrun devicectl device install app \
    --device <DEVICE_UUID> \
    bazel-bin/Telegram/Telegram.ipa

# Launch
xcrun devicectl device process launch \
    --device <DEVICE_UUID> \
    <your.bundle.id>
```

## Troubleshooting

### "Could not determine Xcode version"

Bazel's `xcode-locator` may fail on newer macOS versions. If you see this error, the generated Xcode config at `<output_base>/external/bazel_tools+xcode_configure_extension+local_config_xcode/BUILD` may be empty. Check with:

```bash
cat $(bazel info output_base)/external/bazel_tools+xcode_configure_extension+local_config_xcode/BUILD
```

If it shows an `xcode-locator` error, replace the BUILD file with a manual config:

```bash
XCODE_BUILD=$(xcodebuild -version | grep "Build version" | awk '{print $3}')
XCODE_VER=$(xcodebuild -version | head -1 | awk '{print $2}')

cat > "$(bazel info output_base)/external/bazel_tools+xcode_configure_extension+local_config_xcode/BUILD" << EOF
package(default_visibility = ['//visibility:public'])
xcode_version(
  name = 'version',
  version = '${XCODE_VER}.${XCODE_BUILD}',
  aliases = ['${XCODE_BUILD}', '${XCODE_VER}'],
  default_ios_sdk_version = '26.2',
  default_tvos_sdk_version = '26.2',
  default_macos_sdk_version = '26.2',
  default_visionos_sdk_version = '26.2',
  default_watchos_sdk_version = '26.2',
)
xcode_config(name = 'host_xcodes', versions = [':version'], default = ':version')
available_xcodes(name = 'host_available_xcodes', versions = [':version'], default = ':version')
EOF
```

### `wrapped_clang` not created (macOS 26)

The `apple_support` rule uses `env -i` to build the clang wrapper, which is broken on macOS 26 (Tahoe). The fix is applied in `build-system/bazel-rules/apple_support/crosstool/universal_exec_tool.bzl` — the `env -i` prefix is removed from the `xcrun` invocation.

### Submodule clone failures

If `cross-entropy-ai/tgcalls` or `cross-entropy-ai/rlottie` repos are not found, the `.gitmodules` file has been updated to point to the official upstream repos at `TelegramMessenger/tgcalls` and `TelegramMessenger/rlottie`.

### Code signature verification failed on device install

Make sure you're building for device (`--ios_multi_cpus=arm64`), not simulator. The build configuration must include your Team ID and a valid provisioning profile.
