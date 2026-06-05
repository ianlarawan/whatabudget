# 🐷😎 What-A-Budget

> *The name of this application is dedicated to King 👑.*

**Privacy-First Personal Finance Tracker.**  
An on-device financial manager built with Flutter. Designed for data isolation, absolute privacy, and high-performance offline ledger keeping, with lean utility integrations.

## 🔐 Privacy & Network Architecture
What-A-Budget is designed from the ground up to keep your financial logs completely isolated. 
* **Data Isolation:** All transaction ledgers, bank balances, budgets, and settings are stored locally on your physical hardware. Zero cloud dependencies, zero external tracking.
* **On-Demand Utility Sync:** The application utilizes internet permissions exclusively for fetching real-time currency conversion rates from a secure, stable public API. No personal identifiers or financial metrics ever leave your device.

## 🚀 Core Features & Modules

### 💾 Local Ledger & Backups
* **Local SQLite Engine:** High-performance, low-latency relational database management system running fully on-device.
* **Data Portability Subsystem:** Integrated backup and restoration mechanisms exporting secure `WAB_Backup_YYYY-MM-DD.db` files that cleanly preserve transaction logs, database metadata, and active theme preferences.

### 📊 Advanced Budget Analytics
* **Variable Target Anchors:** Configurable budget caps with flexible tracking timeframes (Daily, Weekly, Bi-Weekly, Monthly, Yearly) and custom calendar start dates.
* **Dynamic Visualizations:** Rich, interactive donut chart analytics Powered by `fl_chart`, showcasing structural spending segments alongside an intelligent grey "Unused Allowance" slice.

### 💳 Debt & Credit Statement Automation
* **Automated Cycle Engines:** Date-driven tracking arrays that dynamically separate debt views into active Unbilled Cycles and Payment Due panels based on configured billing intervals.
* **Archived Statement Tracking:** Granular chronological history indexes that filter your logs down to the exact billing window selected.
* **Intelligent Settlement Tracking:** Real-time incoming payment monitors that automatically mark verified statement goals as PAID with responsive structural UI themes.

### 🧮 Workspace Utilities
* **Standard Calculator Engine:** An asynchronous, hardware-style 4x5 numpad matrix allowing mathematical evaluations to cascade seamlessly into sequential operators.
* **Real-Time Currency Matrix:** A live-syncing multi-currency hub tracking 31 global asset tickers via secure API handshakes. Features real-time calculation mirroring tied to row focus, adaptive symbol trimming, and alpha-faded typography.

## Vibe Code Notice
This entire project was vibe coded with AI assistance—shaping the architecture, fixing bugs, and writing code through iterative conversations.

While the logic and native asset configurations were synthesized through prompts, the engineering relies on continuous testing and refinement to keep things production-ready.