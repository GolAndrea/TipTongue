# TipTongue

> Rescue the single missing word when you pause mid-sentence in a second language — in any setting, across 24 languages, with camera off and live audio automatically erased after 30 seconds.

**[Live Web App](https://tip-on-my-tongue.tip-on-my-tongue.workers.dev/)** · **[Project Case Study](https://portfolio.golloandrea.workers.dev/tip-on-my-tongue.html)**

## Origin & Credits

The original concept behind **TipTongue** was proposed by **[Lillian Murtonen](https://www.linkedin.com/in/lmurtonen/)** ([@hackyfan](https://github.com/hackyfan)) during early Meta Ray-Ban smart-glasses project brainstorming at **Junction 2026**. Building on her initial idea, **[Andrea Gollo](https://www.linkedin.com/in/gollo-andrea/)** expanded the interaction design and developed the cross-platform Flutter app, Meta Wearables DAT v1.0.1 integration, open-domain hesitation engine, and Meta Ray-Ban Display Web App companion.

## Key Capabilities

- **Open-domain, ready-to-speak single word (`< 2 s`):** Works in any everyday conversation (restaurant, pharmacy, travel, work, friends) without preset scenario toggles. Prompts fast lightweight LLMs (`llama-3.1-8b-instant` on Groq LPU, `gemini-3.5-flash-lite`, OpenRouter `:free`, or local Ollama `llama3.2`) under a strict `1.9 s` response budget to return **one word already conjugated and declined** for the paused clause — zero grammar tags on the lens.
- **24 searchable languages:** Built-in BCP-47 support across 24 languages (`EN, ES, FR, DE, IT, PT, NL, SV, FI, NO, DA, PL, CS, EL, TR, RU, UK, AR, HI, ZH, JA, KO, VI, ID`) with instant search from the app header, dedicated syntactic-cliff hesitation markers across 12 European languages, and universal mid-clause pause detection across all 24.
- **Privacy-by-Design (Meta AUP):**
  - **Camera & unused sensors off:** `mwdat-camera` / `MWDATCamera`, Android `CAMERA`, iOS `NSCameraUsageDescription` are omitted, and Web enforces `Permissions-Policy: camera=()`.
  - **Zero audio stored — erased after 30 seconds:** Ephemeral rolling RAM buffer clears automatically after `30 s` or immediately once a word is rescued; only the rescued word + short gloss remain in today's notebook.
  - **Explicit DAT analytics opt-out:** `ANALYTICS_OPT_OUT = true` (Android) and `MWDAT.Analytics.OptOut` (iOS).
- **Meta Wearables DAT v1.0.1 & Audio Routing:**
  - Native Android bridge (`android/app/src/main/kotlin/com/tiponmytongue/tip_on_my_tongue/DatGlassesBridge.kt`) against official Maven Central `mwdat-core`, `mwdat-display`, and `mwdat-mockdevice` (`1.0.1`), including live `DeviceState` auto-pause when glasses are removed or folded and automatic Bluetooth HFP ↔ A2DP routing.
  - Fixed calibrated mid-sentence hesitation threshold (`850 ms` base, accelerating on fillers/syntactic cliffs) for zero setup friction, designed internally for future light per-speaker personalisation.
- **Meta Ray-Ban Display Web App Companion (`display_webapp/`):**
  - React 19 + TypeScript companion built on Meta's official UI Toolkit (`@wearables-ui-toolkit/mrbd`) at exact `600×600` (`#000000` transparent additive waveguide background, D-pad / Neural Band navigation with 2 clean controls: *Next word* and *Hide gloss*) plus guarded **WebMCP** (`document.modelContext.registerTool` for `tiptongue_state` and `tiptongue_lookup`).

## Local Preview & Builds

### 1. Meta Ray-Ban Display Web App (Chrome Simulator)
```bash
cd display_webapp
npm install
npm run build
npm run preview
```
Open `http://127.0.0.1:4173/` in Chrome with Meta's official **Meta Ray-Ban Display Simulator** extension (`jpjlmmodokemlepklkdbimceggpbjcll`) and navigate with arrow keys + `Enter`.

### 2. Flutter Mobile & Web App
```bash
# Static analysis & automated unit/widget tests (13 checks)
dart analyze --fatal-infos
flutter test

# Android Release APK (with Meta Wearables DAT v1.0.1)
flutter build apk --release

# Cloudflare Workers Web App
flutter build web --release --no-wasm-dry-run
```
