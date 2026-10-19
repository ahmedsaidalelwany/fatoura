# فاتورة — Fatoura
### Cross-Platform Invoicing & Small Business Accounting Application
#### (تطبيق إدارة الفواتير والحسابات للأنشطة التجارية الصغيرة)

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-blue.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-green.svg)]()
[![License](https://img.shields.io/badge/License-Proprietary-orange.svg)]()

---

## 🌟 Overview (نظرة عامة)

**فاتورة (Fatoura)** is a modern, reliable, and completely offline-first invoicing and accounting application crafted specifically for small businesses, retail shops, freelancers, and service providers. It is built natively with Flutter and Dart, supporting **Windows Desktop** and **Android (Phones & Tablets)**.

### Core Values:
- **Local-First & Private:** All business records, customer ledgers, and financial balances remain strictly on your local device. No required cloud accounts, no subscription lock-ins, and zero forced network dependencies.
- **Bilingual Interface:** First-class native support for **Arabic (العربية)** and **English** with full right-to-left (RTL) typography and bidirectional shaping.
- **Financial Precision:** Guaranteed exact monetary arithmetic using rational decimal calculations (`Decimal`) to completely eliminate floating-point rounding errors.
- **Audit-Ready & Immutable:** Invoices cannot be silently modified or erased once issued. Adjustments require explicit cancellation with mandatory reasons or formal sales returns.
- **Segregated Ledgers:** Customer receivables (money owed to you) and Supplier payables (money you owe to suppliers) are kept strictly separate.

---

## 🚀 Key Features (المميزات الرئيسية)

1. **Dashboard & Analytics:**
   - Real-time sales, collections, customer receivables, and supplier payables summaries.
   - 7-day visual sales trend chart.
   - Quick action shortcuts for issuing invoices, registering customers, and logging purchases.

2. **Sales Invoices (فواتير المبيعات):**
   - Sequential, tamper-evident daily numbering format: `Ftr-DD.MM.YYYY-NNNN`.
   - Line items with automatic unit price lookup from product catalog.
   - Item-level and invoice-level discounts (Fixed amount or Percentage).
   - Taxable base calculation with configurable VAT (default 15%).
   - Partial payment support and instant remaining balance calculation.
   - Cancellation with mandatory reason audit trail.

3. **Payments & Collections (المدفوعات والمقبوضات):**
   - Support for Cash, Bank Transfer, and Card payments.
   - Overpayment protection (payments cannot exceed outstanding balance).
   - Instant allocation against invoices.

4. **Customers & Suppliers (العملاء والموردون):**
   - Detailed contact info, tax registration numbers, and notes.
   - Real-time balances and transaction history.
   - Filterable customer and supplier statements.

5. **Products & Inventory (المنتجات والمخزون):**
   - Product catalog with SKU, sale price, purchase cost, and initial stock quantities.
   - Real-time stock decrement on sales and increment on returns and purchases.

6. **Purchases (فواتير المشتريات):**
   - Supplier invoice logging with unique sequence format: `Pur-DD.MM.YYYY-NNNN`.
   - Inventory auto-restocking and supplier payable balance tracking.

7. **Sales Returns (مرتجع المبيعات):**
   - Return against original invoices with sequential numbering: `Ret-DD.MM.YYYY-NNNN`.
   - Proportional refund calculations including discount and tax adjustments.
   - Choice of Cash Refund or Customer Account Credit Note.

8. **PDF Export & Printing (الطباعة وتصدير PDF):**
   - Clean, professional invoice templates rendered offline with embedded TrueType fonts (`AppFont`) for crisp Arabic RTL shaping and English text.
   - Direct thermal/desktop printer support via the `printing` package.

9. **Backup & Disaster Recovery (النسخ الاحتياطي والاستعادة):**
   - One-click JSON backup export with embedded **SHA-256 cryptographic checksum**.
   - Strict tamper verification prior to restoration.
   - Automatic pre-restore rollback snapshot preventing data corruption.

---

## 🛠️ Technology Stack & Architecture

- **Framework:** Flutter (3.47.1+) with Dart (3.13.1+)
- **Architecture:** Clean Architecture with Feature-First modular structure
- **State Management:** `flutter_bloc` (Cubit pattern)
- **Local Database:** `Hive` (typed, lightweight, fast Key-Value database)
- **Application Preferences:** `shared_preferences`
- **Financial Arithmetic:** `decimal` with immutable `Money` Value Object
- **PDF & Printing:** `pdf` and `printing` with embedded TrueType font assets
- **Security & Integrity:** `crypto` (SHA-256 checksums)

---

## 📂 Project Structure

```
d:/Projects/fatoura/
├── assets/
│   ├── fonts/               # Embedded TrueType fonts for RTL Arabic
│   └── images/              # Fatoura logo assets
├── lib/
│   ├── main.dart            # Application entrypoint
│   ├── bootstrap.dart       # Local storage & dependency injection
│   ├── app.dart             # MaterialApp root, themes & routing
│   ├── core/                # Core engines (precision, storage, PDF, backup)
│   └── features/            # Feature modules (invoices, parties, products, etc.)
├── test/
│   ├── core/precision/      # Decimal financial calculator tests
│   ├── features/backup/     # Tamper-detection & recovery tests
│   ├── features/invoices/   # Invoicing workflow & sequence tests
│   └── widget_test.dart     # First-run app boot test
└── docs/
    ├── ARCHITECTURE.md      # Detailed technical architecture spec
    └── IMPLEMENTATION_STATUS.md # Requirement compliance matrix
```

---

## 🏃 Getting Started (التشغيل والإعداد)

### Prerequisites:
- Flutter SDK (3.47+)
- Dart SDK (3.13+)
- Windows: Visual Studio 2022+ with "Desktop development with C++"
- Android: Android Studio / Android SDK (Platform 34+)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Static Analysis & Linter
```bash
flutter analyze
```
*(Codebase passes with 0 errors, 0 warnings, and 0 linter issues)*

### 3. Run Automated Tests
```bash
flutter test
```
*(Executes all 13 unit, integration, and widget tests)*

### 4. Run on Windows Desktop
```bash
flutter run -d windows
```

### 5. Build Release for Windows
```bash
flutter build windows
```
The compiled standalone executable will be located in:
`build\windows\x64\runner\Release\fatoura.exe`

### 6. Build Release for Android
```bash
flutter build apk --release
```
The signed/unsigned APK will be located in:
`build\app\outputs\flutter-apk\app-release.apk`

---

## 📄 License & Attribution

Designed and engineered for business owners seeking a dependable, local-first financial recordkeeping tool. All rights reserved.
