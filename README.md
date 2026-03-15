# Grocy iOS

A polished, feature-complete iOS client for [Grocy](https://grocy.info) — the self-hosted grocery and household management system. Built from scratch to replace the abandoned, outdated app currently on the App Store.

![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-34C759?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-lightgrey?style=flat-square)

---

## What is Grocy?

[Grocy](https://grocy.info) is a **free, open-source, self-hosted** web application for managing your household — primarily focused on groceries, pantry stock, shopping lists, chores, and recipes.

- **GitHub:** [grocy/grocy](https://github.com/grocy/grocy)
- **Website:** [grocy.info](https://grocy.info)
- **Demo:** [demo.grocy.info](https://demo.grocy.info) (live demo server, no sign-up required)

You run Grocy on your own server (home lab, NAS, VPS, etc.) and connect to it from any device. Your data never leaves your infrastructure.

### Running Grocy on your server

The easiest way to self-host Grocy is with Docker:

```bash
# Docker Compose (recommended)
version: "3"
services:
  grocy:
    image: lscr.io/linuxserver/grocy:latest
    container_name: grocy
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
    volumes:
      - ./grocy/config:/config
    ports:
      - 9283:80
    restart: unless-stopped
```

Then access Grocy at `http://your-server-ip:9283`.

Other install methods (bare metal PHP, Unraid, Portainer, Synology, etc.) are documented at [grocy.info/#installation](https://grocy.info/#installation).

---

## Why this app?

The existing Grocy iOS app on the App Store hasn't been updated in years — it's missing features, has a dated UI, and doesn't support modern iOS conventions. This app was built to be the Grocy iOS client that users deserve:

- Native SwiftUI with smooth spring animations
- Full feature parity with the Grocy web interface
- Family-friendly design with haptic feedback and celebratory confetti 🎉
- Barcode scanning with automatic product lookup via [Open Food Facts](https://world.openfoodfacts.org)
- Kroger price lookup when putting groceries away
- Demo mode — try the full app with no server required

---

## Screenshots

> _Coming soon_

---

## Features

### 📦 Stock Management
- Full pantry overview with expiry status indicators (good, due soon, overdue, expired)
- Add stock by amount, expiry date, and price
- Consume and open items with quantity tracking
- Barcode scan to instantly add or consume items
- Price history charts per product
- Filter and search across all stock

### 🛒 Shopping Lists
- Multiple shopping lists with create/rename/delete
- Add items manually or auto-populate from low stock
- Swipe to mark items as purchased
- **Put Away workflow** — after shopping, a dedicated sheet lets you set expiry dates and prices for each purchased item before adding it to stock
- Notes support for freeform items

### ✅ Tasks & Chores
- Create and manage one-off tasks with due dates and categories
- Recurring chores with configurable rescheduling behavior
- Mark tasks/chores complete with one tap
- Overdue and upcoming indicators

### 🍽️ Recipes & Meal Plan
- Browse all recipes with ingredient lists
- Stock fulfillment checker — see exactly what you have vs. what a recipe needs
- Weekly meal plan overview with nutritional info
- Add missing recipe ingredients directly to shopping list

### 📸 Barcode Scanner
- Scan UPC/EAN barcodes with `DataScannerViewController`
- Auto-lookup via Open Food Facts (name, brand, image, nutrition)
- Create new products or match to existing ones
- Link multiple barcodes to a single product

### 💰 Kroger Price Lookup _(optional)_
- Fetch current in-store prices from your nearest Kroger-family store (Kroger, Ralphs, Fred Meyer, King Soopers, etc.) when putting groceries away
- Uses the free [Kroger Developer API](https://developer.kroger.com)
- UPC barcode used when available for exact matches; falls back to product name search
- Price history logged per product in Grocy

### 🧪 Demo Mode
- Tap "Explore Demo" on the login screen to connect to `demo.grocy.info`
- Full read/write access — no account, no setup
- Great for evaluating the app before deploying your own server

---

## Requirements

| Requirement | Version |
|---|---|
| iOS | 18.0+ |
| Xcode | 16.0+ |
| Grocy server | 4.0.0+ |

---

## Building & Running

### 1. Clone the repo

```bash
git clone https://github.com/dbzx6r/grocy-ios.git
cd grocy-ios
```

### 2. Open in Xcode

```bash
open GrocyV2.xcodeproj
```

No dependencies to install — the project uses no third-party packages.

### 3. Configure signing

In Xcode → select the `GrocyV2` target → **Signing & Capabilities** → set your Team and Bundle Identifier.

### 4. Build & run

Select your device or a simulator running iOS 18+ and hit **Run** (⌘R).

---

## First-Time Setup in the App

1. **Enter your server URL** — e.g. `http://192.168.1.50:9283` or `https://grocy.yourdomain.com`
2. **Enter your API key** — In Grocy web UI → ☰ Menu → **Manage API Keys** → Add → copy the key
3. Tap **Connect**

Or tap **Explore Demo** to try the app instantly against Grocy's live demo server.

---

## Kroger Price Lookup Setup _(optional)_

This feature is entirely optional. To enable it:

1. Go to **Settings → Price Lookup (Kroger) → Setup Guide** in the app
2. Create a free account at [developer.kroger.com](https://developer.kroger.com)
3. Create a new app — select **Production** environment and check the **Product** scope
4. Copy your **Client ID** and **Client Secret** into Settings
5. Enter your **zip code** — this is required for Kroger to return store-specific prices

> **Note:** You need your own Kroger Developer account. Each user must create their own free credentials.

---

## Architecture

```
GrocyV2/
├── App/                    # Entry point, root view
├── Models/                 # Codable data models (Product, StockItem, etc.)
├── Networking/             # GrocyAPIClient — all API calls via URLSession async/await
├── Services/               # KrogerService — price lookup
├── Storage/                # KeychainHelper — credential storage
├── Utilities/              # HapticManager, DateFormatters
├── ViewModels/             # @Observable view models (MVVM)
│   ├── AppViewModel        # Server connection, global state
│   ├── DashboardViewModel
│   ├── ShoppingViewModel
│   ├── TasksViewModel
│   └── RecipesViewModel
└── Views/
    ├── Dashboard/          # Home screen cards
    ├── Onboarding/         # Login / server setup
    ├── Scanner/            # Barcode scanning
    ├── Settings/           # App settings, Kroger setup
    ├── Shopping/           # Shopping list + Put Away workflow
    ├── Stock/              # Pantry, product detail, settings
    └── Tasks/              # Tasks, chores
```

**Key design decisions:**
- **Zero third-party dependencies** — pure Swift/SwiftUI/Foundation
- **Swift 6 strict concurrency** — all networking is `async/await`, actors used where appropriate
- **`@Observable` MVVM** — clean separation, no `ObservableObject` boilerplate
- **Keychain storage** — server URL and API key never touch `UserDefaults`
- **`DataScannerViewController`** — native camera barcode scanning, no AVFoundation boilerplate

---

## Contributing

PRs and issues are very welcome!

- **Bug reports:** Open an issue with steps to reproduce
- **Feature requests:** Open an issue describing the use case
- **Code contributions:** Fork → branch → PR against `main`

Please keep PRs focused — one feature or fix per PR.

---

## Related

- [grocy/grocy](https://github.com/grocy/grocy) — the Grocy server (PHP)
- [grocy/grocy-docker](https://github.com/grocy/grocy-docker) — official Docker images
- [grocy/grocy-android](https://github.com/grocy/grocy-android) — the official Android client

---

## License

MIT License — see [LICENSE](LICENSE) for details.
