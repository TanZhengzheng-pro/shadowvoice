# ShadowVoice iOS Client

## Structure
- `ShadowVoiceIOS/`: SwiftUI iOS app that records user audio, optionally imports a reference WAV, and calls the backend `/analyze` endpoint.
- `ShadowVoiceClientCore/`: small Swift package with request/response types and endpoint normalization logic, covered by `swift test`.

## Open In Xcode
1. Start the backend from `backend/`.
2. Open `ios/ShadowVoiceIOS/ShadowVoiceIOS.xcodeproj` in Xcode.
3. Choose an iOS Simulator or device.
4. Run the app.

## Backend URL
- iOS Simulator: `http://127.0.0.1:8000`
- Physical device: use your Mac's LAN IP, for example `http://192.168.1.20:8000`

The app exposes the backend URL as an editable field so you can switch between local and remote environments.

## Current MVP Flow
1. Enter target text.
2. Record user audio as WAV inside the app.
3. Optionally import a reference WAV from Files.
4. Tap Analyze.
5. Read overall score, worst segments, and notes returned by the backend.

## Validation Done Here
- `cd ios/ShadowVoiceClientCore && swift test`
- `plutil -lint` on the iOS app plist and Xcode project metadata

Full iOS build validation still requires a machine with full Xcode installed.
