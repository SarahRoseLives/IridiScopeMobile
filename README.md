# IridiScope Mobile

Android app for receiving Iridium satellite signals with a HackRF (or from an
IQ recording), built with Flutter and a native C/C++ FFI library.

## Features

- Live HackRF One receive at 2–10 MSPS.
- IQ file playback (WAV `ci16`/`ci8`/`cf32`, and headerless `ci8`/`ci16`/`cf32`).
- Scrolling spectrum + waterfall with configurable FFT size and colour map.
- Iridium burst detection, DQPSK demodulation and native message parser
  (IRA, IBC, IDA, IMS, ITL, SY, IP, VOC/VOD/VO6, ...).
- ACARS, SBD, SMS and pager reassembly panels.
- AMBE voice decoding via osmo-ir77, with automatic playback of finished calls.
- Equirectangular satellite / ground-beam map from IRA ring alerts.

## Architecture

```text
Flutter / Dart
  ├─ IridiScopeService ──FFI──> libiridiscope.so
  │     ├─ poll_spectrum  -> Float32List
  │     ├─ poll_events    -> JSON (messages, ACARS/SBD/SMS/pager, voice, map)
  │     └─ open/start/stop/tune/pause
  └─ HackRfService ──MethodChannel──> HackRfBridge.kt
                                            │
                                      hackrf-android USB driver
                                            │
                                            └─ JNI nativeFeedIq(byte[]) -> PushIqSource
```

The native library vendors the Iridium DSP/parser from IridiScope, a KissFFT
backed FFTW API shim, cJSON, and the osmo-ir77 AMBE codec. HackRF IQ stays
native; only spectrum frames and decoded events cross into Flutter.

## Build

Prerequisites:

- Flutter 3.47+ / Dart 3.13+
- Android SDK 36
- Android NDK `28.2.13676358`
- CMake `3.22.1`
- JDK 21

```powershell
flutter pub get
flutter build apk --debug
flutter install
```

Or run directly on a connected Android device:

```powershell
flutter run
```

The app targets `arm64-v8a` and `x86_64`.

## IQ file naming

The native file source reads the capture centre frequency from the filename,
looking for a `<number>Hz` token. Keep it in the name when creating excerpts:

```text
baseband_1623000000Hz_10msps_3min.wav
```

If the token is missing, use the app's frequency controls to set the correct
centre before relying on IRA/IP classification.

## Native layout

- `android/app/src/main/cpp/vendor/iridiscope/` — engine, parser, ACARS/pager,
  file source, Iridium pipeline wrapper.
- `android/app/src/main/cpp/vendor/iridium-sniffer/` — burst detector,
  downmix, DQPSK demodulator, SIMD kernels.
- `android/app/src/main/cpp/vendor/osmo-ir77/` — AMBE vocoder.
- `android/app/src/main/cpp/vendor/kissfft/` — FFT backend.
- `android/app/src/main/cpp/shim/` — FFTW3f compatibility layer.
- `android/app/src/main/cpp/mobile/` — FFI bridge, push IQ source, JNI feed,
  voice manager.
- `android/app/src/main/java/com/mantz_it/hackrf_android/` — Android USB HackRF
  driver.

## Credits and licensing

This project is a combined work built on:

- **IridiScope** and **iridium-sniffer** (GPL-3.0)
- **iridium-toolkit** (message-format reference)
- **osmo-ir77** (AGPL-3.0) — Iridium AMBE vocoder
- **hackrf-android** (GPL-2.0-or-later) — Android HackRF USB driver
- **KissFFT** (BSD-3-Clause)
- **cJSON** (MIT)

Because osmo-ir77 is AGPL-3.0, the combined application is distributed under
the **GNU Affero General Public License v3.0**. See [LICENSE](LICENSE).
