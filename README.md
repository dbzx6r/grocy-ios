# Grocy v2 — iOS App

A polished, feature-complete iOS 26 client for [Grocy](https://grocy.info) — the self-hosted grocery and household management system. Built to replace the abandoned, outdated App Store app.

![iOS 26](https://img.shields.io/badge/iOS-26%2B-34C759?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

## Features

- **📦 Stock Management** — View pantry, add/consume/open items, track expiry dates
- **🛒 Shopping Lists** — Swipe-to-complete, auto-fill from low stock, multiple lists
- **✅ Tasks & Chores** — Track household tasks and recurring chores with due dates
- **🍽️ Recipes & Meal Plan** — Browse recipes, check stock fulfillment, weekly meal planning
- **📸 Barcode Scanner** — Scan any product barcode to instantly add or consume stock
- **🧪 Demo Mode** — Try the app against demo.grocy.info with no setup required

## Design

Built for iOS 26 with Apple's Liquid Glass design language:
- Fresh green accent color
- Spring animations throughout
- Haptic feedback on all interactions
- Full Dark Mode support
- Dynamic Type accessibility support
- Confetti celebrations for completed tasks 🎉

## Requirements

- iPhone running iOS 26+
- Xcode 26.2+
- A running [Grocy](https://grocy.info) server (or use the Demo mode)

## Setup

1. Clone this repo
2. Open `GrocyV2.xcodeproj` in Xcode 26.2
3. Build & run on your device or simulator
4. On first launch: enter your Grocy server URL + API key, or tap "Try Demo"

**Getting your API key:** In Grocy → ☰ Menu → Manage API Keys → Add

## Architecture

```
SwiftUI + Swift 6 + @Observable MVVM
├── No third-party dependencies
├── Keychain for credential storage
├── URLSession async/await networking
├── DataScannerViewController for barcodes
└── Swift Charts for price history
```

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Part of the [dbzx6r/homelab](https://github.com/dbzx6r/homelab) ecosystem.*
