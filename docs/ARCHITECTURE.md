# FATOURA (فاتورة) — ARCHITECTURE & TECHNICAL SPECIFICATION

## 1. High-Level Architecture Overview

Fatoura is an offline-first, local business management and financial recordkeeping application designed for small business owners and merchants. It runs natively across Android phones/tablets and Windows desktop computers.

The application follows strict **Clean Architecture** principles structured by **Feature-First** modular boundaries:

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│   (Flutter Widgets, Responsive Layout, Cubit States)   │
└───────────────────────────┬────────────────────────────┘
                            │ depends on
┌───────────────────────────▼────────────────────────────┐
│                      Domain Layer                      │
│   (Entities, Business Rules, Repository Contracts)     │
└───────────────────────────▲────────────────────────────┘
                            │ implemented by
┌───────────────────────────┴────────────────────────────┐
│                       Data Layer                       │
│    (Hive Adapters, Box Repositories, File Storage)     │
└────────────────────────────────────────────────────────┘
```

### Key Architectural Tenets:
1. **Zero Cloud Lock-in**: Designed strictly local-first with offline persistence. No mandatory cloud accounts, network telemetry, or remote lock-in.
2. **Deterministic Financial Precision**: Raw floating-point arithmetic (`double`) is completely eliminated from financial calculations in favor of exact `Decimal` arithmetic wrapped in an immutable `Money` Value Object.
3. **Immutability of Invoices**: Invoices once issued cannot be silently altered or deleted. Adjustments require explicit mandatory-reason cancellation or formal sales returns.
4. **Strict Counterparty Segregation**: Customer receivables (sales debits, receipts) and Supplier payables (purchase credits, disbursements) are maintained in strictly segregated sub-ledgers, even if a counterparty has identical contact information.
5. **Atomic Sequence Generation**: Daily invoice sequences (`Ftr-DD.MM.YYYY-NNNN`) are incremented atomically under database transaction locks with collision fallback detection.
6. **Self-Contained Arabic Typography**: Bundled TrueType font `assets/fonts/AppFont-Regular.ttf` and `AppFont-Bold.ttf` guarantee accurate bidirectional RTL Arabic shaping and English rendering without internet access or missing system glyphs.

---

## 2. Directory Structure

```
d:/Projects/fatoura/
├── assets/
│   ├── fonts/
│   │   ├── AppFont-Regular.ttf
│   │   └── AppFont-Bold.ttf
│   └── images/
│       └── logo.png
├── lib/
│   ├── main.dart             # Application entrypoint
│   ├── bootstrap.dart        # Infrastructure bootstrap & DI
│   ├── app.dart              # Root MaterialApp shell, BlocProviders & Theme
│   ├── core/
│   │   ├── backup/           # BackupService (SHA-256 integrity, JSON export/restore)
│   │   ├── localization/     # Typed AppLocalizations (Arabic & English)
│   │   ├── pdf/              # InvoicePdfGenerator (RTL-shaped Arabic PDF export & printing)
│   │   ├── precision/        # Money value object & FinancialCalculator
│   │   ├── responsive/       # Breakpoint-aware layout helper (Desktop / Tablet / Mobile)
│   │   ├── settings/         # AppSettingsCubit & SharedPreferences persistence
│   │   ├── storage/          # HiveDatabase & SequenceManager
│   │   ├── theme/            # AppColors & AppTheme (Light and Dark)
│   │   └── widgets/          # Responsive AppScaffold shell & navigation rails
│   └── features/
│       ├── audit/            # Audit logging entities & repository
│       ├── backup/           # Backup & Restore UI
│       ├── dashboard/        # Live sales metrics, KPI cards & sales charts
│       ├── invoices/         # Invoice creation, listing, detail, cancellation
│       ├── parties/          # Customer & Supplier management and ledger statements
│       ├── payments/         # Payment recording, allocation, receipt issuance
│       ├── products/         # Catalog, inventory pricing, tax flags
│       ├── purchases/        # Purchase invoice logging & supplier payables
│       ├── reports/          # Sales, collections, debt, tax, customer/supplier reports
│       ├── returns/          # Sales return processing & inventory restock
│       ├── settings/         # App language, theme mode, shop profile navigation
│       └── shop_setup/       # Initial wizard & shop profile configuration
└── test/
    ├── core/precision/       # FinancialCalculator precision unit tests
    ├── features/backup/      # Backup/restore tampering and rollback tests
    ├── features/invoices/    # Invoice workflow, numbering, cancellation tests
    └── widget_test.dart      # Application boot & first-run widget test
```

---

## 3. Financial Calculation Engine (`FinancialCalculator`)

The financial engine executes all monetary arithmetic using rational decimal numbers (`Decimal` package) rounded to 2 decimal places using half-up arithmetic:

### Core Formulas:
- **Line Gross Subtotal**:
  $$\text{gross} = \sum (\text{item.quantity} \times \text{item.unitPrice})$$
- **Discount Allocation**:
  - *Fixed Discount*: $\text{discount} = \min(\text{fixedValue}, \text{gross})$
  - *Percentage Discount*: $\text{discount} = \text{gross} \times \left(\frac{\text{percent}}{100}\right)$
- **Taxable Base**:
  $$\text{taxableBase} = \max(0, \text{gross} - \text{discount})$$
- **Tax Calculation (15% VAT / configurable)**:
  $$\text{tax} = \text{taxableBase} \times \left(\frac{\text{taxRate}}{100}\right)$$
- **Invoice Final Total**:
  $$\text{total} = \text{taxableBase} + \text{tax}$$
- **Outstanding Balance**:
  $$\text{remainingBalance} = \max(0, \text{finalTotal} - \text{paidAmount} - \text{refundedAmount})$$

---

## 4. Sequential Document Numbering Engine

Document numbering follows the format:
- **Sales Invoices**: `Ftr-DD.MM.YYYY-NNNN`
- **Purchase Invoices**: `Pur-DD.MM.YYYY-NNNN`
- **Sales Returns**: `Ret-DD.MM.YYYY-NNNN`

### Numbering Algorithm:
1. Current date formatted as `DD.MM.YYYY`.
2. Atomic sequence key constructed: `prefix:DD.MM.YYYY`.
3. In-box sequence counter atomically incremented.
4. If an unexpected sequence collision exists in historical documents, sequence manager auto-increments until a unique identifier is guaranteed.

---

## 5. Backup & Integrity Architecture (`BackupService`)

To safeguard small business financial records:
1. **JSON Consolidation**: Exports entire Hive database collections (`shopProfile`, `parties`, `products`, `invoices`, `payments`, `salesReturns`, `purchases`, `auditLogs`, `sequenceCounters`).
2. **SHA-256 Tamper Detection**: Computes a cryptographic SHA-256 checksum over the raw JSON payload and embeds it in the backup header.
3. **Pre-Restore Rollback Snapshot**: Before replacing any live data during restore, an in-memory or temporary disk snapshot of the current database is preserved. If validation or restoration encounters an anomaly, the snapshot is automatically rolled back.
