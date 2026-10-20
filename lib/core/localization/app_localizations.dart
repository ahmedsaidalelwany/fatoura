import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  // Application Info
  String get appName => isArabic ? 'فاتورة' : 'Fatoura';
  String get appTagline => isArabic
      ? 'إدارة الفواتير والحسابات للشركات الصغيرة'
      : 'Invoicing & Accounting for Small Business';

  // Navigation Items
  String get navDashboard => isArabic ? 'الرئيسية' : 'Dashboard';
  String get navInvoices => isArabic ? 'المبيعات' : 'Sales Invoices';
  String get navPurchases => isArabic ? 'المشتريات' : 'Purchases';
  String get navCustomers => isArabic ? 'العملاء' : 'Customers';
  String get navSuppliers => isArabic ? 'الموردين' : 'Suppliers';
  String get navProducts => isArabic ? 'المنتجات' : 'Products';
  String get navReturns => isArabic ? 'المرتجعات' : 'Returns';
  String get navReports => isArabic ? 'التقارير' : 'Reports';
  String get navSettings => isArabic ? 'الإعدادات' : 'Settings';
  String get navBackup => isArabic ? 'النسخ الاحتياطي' : 'Backup & Restore';

  // First Run Setup
  String get setupTitle => isArabic ? 'إعداد المتجر والنشاط' : 'Shop Setup';
  String get setupSubtitle => isArabic
      ? 'أدخل بيانات نشاطك التجاري للبدء في استخدام فاتورة'
      : 'Enter your business details to get started with Fatoura';
  String get shopNameLabel =>
      isArabic ? 'اسم المتجر / الشركة *' : 'Shop / Business Name *';
  String get shopTypeLabel => isArabic ? 'نوع النشاط *' : 'Business Type *';
  String get shopPhoneLabel => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get shopAddressLabel => isArabic ? 'العنوان' : 'Address';
  String get defaultCurrencyLabel =>
      isArabic ? 'العملة الافتراضية *' : 'Default Currency *';
  String get taxNumberLabel =>
      isArabic ? 'الرقم الضريبي (اختياري)' : 'Tax Number (Optional)';
  String get completeSetupBtn => isArabic ? 'حفظ والبدء' : 'Save and Start';
  String get setupRequiredField =>
      isArabic ? 'هذا الحقل مطلوب' : 'This field is required';

  // Dashboard
  String get dashboardTotalSales =>
      isArabic ? 'إجمالي المبيعات' : 'Total Sales';
  String get dashboardCollected =>
      isArabic ? 'المبالغ المحصلة' : 'Amount Collected';
  String get dashboardReceivables =>
      isArabic ? 'مستحقات على العملاء' : 'Customer Debts';
  String get dashboardPayables =>
      isArabic ? 'مستحقات للموردين' : 'Supplier Payables';
  String get dashboardTotalPurchases =>
      isArabic ? 'إجمالي المشتريات' : 'Total Purchases';
  String get dashboardRecentActivity =>
      isArabic ? 'النشاط الأخير' : 'Recent Activity';
  String get dashboardQuickActions =>
      isArabic ? 'إجراءات سريعة' : 'Quick Actions';
  String get dashboardSalesTrend =>
      isArabic ? 'حركة المبيعات (آخر 7 أيام)' : 'Sales Trend (Last 7 Days)';
  String get dashboardNoActivity =>
      isArabic ? 'لا توجد أنشطة مسجلة بعد' : 'No recorded activity yet';

  // Quick Actions
  String get actionNewInvoice =>
      isArabic ? 'فاتورة بيع جديدة' : 'New Sales Invoice';
  String get actionNewPurchase =>
      isArabic ? 'فاتورة شراء جديدة' : 'New Purchase';
  String get actionAddCustomer => isArabic ? 'إضافة عميل' : 'Add Customer';
  String get actionAddSupplier => isArabic ? 'إضافة مورد' : 'Add Supplier';
  String get actionAddProduct =>
      isArabic ? 'إضافة منتج جديد' : 'Add New Product';
  String get actionRecordPayment => isArabic ? 'تسجيل دفعة' : 'Record Payment';
  String get actionNewReturn => isArabic ? 'تسجيل مرتجع' : 'New Return';

  // Invoices & Items
  String get invoiceNumber => isArabic ? 'رقم الفاتورة' : 'Invoice Number';
  String get invoiceDate => isArabic ? 'تاريخ الإصدار' : 'Issue Date';
  String get customerLabel => isArabic ? 'العميل' : 'Customer';
  String get cashCustomer =>
      isArabic ? 'عميل نقدي (عام)' : 'Cash / Anonymous Sale';
  String get supplierLabel => isArabic ? 'المورد' : 'Supplier';
  String get itemsSection => isArabic ? 'بنود الفاتورة' : 'Line Items';
  String get addItemBtn => isArabic ? 'إضافة بند' : 'Add Item';
  String get itemDescription =>
      isArabic ? 'البيان / الصنف' : 'Description / Item';
  String get itemQuantity => isArabic ? 'الكمية' : 'Quantity';
  String get itemUnitPrice => isArabic ? 'سعر الوحدة' : 'Unit Price';
  String get itemTotal => isArabic ? 'الإجمالي' : 'Line Total';
  String get subtotalLabel => isArabic ? 'المجموع الفرعي' : 'Subtotal';
  String get discountLabel => isArabic ? 'الخصم' : 'Discount';
  String get discountTypeFixed => isArabic ? 'مبلغ ثابت' : 'Fixed Amount';
  String get discountTypePercent =>
      isArabic ? 'نسبة مئوية (%)' : 'Percentage (%)';
  String get discountValue => isArabic ? 'قيمة الخصم' : 'Discount Value';
  String get taxableBaseLabel =>
      isArabic ? 'المبلغ الخاضع للضريبة' : 'Taxable Base';
  String get taxRateLabel => isArabic ? 'نسبة الضريبة (%)' : 'Tax Rate (%)';
  String get taxAmountLabel => isArabic ? 'مبلغ الضريبة' : 'Tax Amount';
  String get finalTotalLabel => isArabic ? 'الإجمالي النهائي' : 'Final Total';
  String get amountPaidLabel => isArabic ? 'المبلغ المدفوع' : 'Amount Paid';
  String get remainingBalanceLabel =>
      isArabic ? 'المبلغ المتبقي' : 'Remaining Balance';
  String get notesLabel => isArabic ? 'ملاحظات' : 'Notes';
  String get issueInvoiceBtn => isArabic ? 'إصدار الفاتورة' : 'Issue Invoice';
  String get saveDraftBtn => isArabic ? 'حفظ كمسودة' : 'Save as Draft';

  // Document & Payment Status
  String get statusDraft => isArabic ? 'مسودة' : 'Draft';
  String get statusIssued => isArabic ? 'صادرة' : 'Issued';
  String get statusCancelled => isArabic ? 'ملغاة' : 'Cancelled';
  String get paymentStatusUnpaid => isArabic ? 'غير مسددة' : 'Unpaid';
  String get paymentStatusPartial =>
      isArabic ? 'مسددة جزئياً' : 'Partially Paid';
  String get paymentStatusPaid => isArabic ? 'مسددة بالكامل' : 'Fully Paid';
  String get paymentStatusRefunded => isArabic ? 'مسترجعة' : 'Refunded';

  // Payments & Allocations
  String get paymentHistoryTitle =>
      isArabic ? 'سجل الدفعات' : 'Payment History';
  String get paymentAmountLabel => isArabic ? 'مبلغ الدفعة' : 'Payment Amount';
  String get paymentDateLabel => isArabic ? 'تاريخ الدفع' : 'Payment Date';
  String get paymentMethodLabel => isArabic ? 'طريقة الدفع' : 'Payment Method';
  String get methodCash => isArabic ? 'نقداً (كاش)' : 'Cash';
  String get methodBank => isArabic ? 'تحويل بنكي' : 'Bank Transfer';
  String get methodCard => isArabic ? 'بطاقة بنكية' : 'Card';
  String get methodOther => isArabic ? 'أخرى' : 'Other';
  String get paymentReferenceLabel =>
      isArabic ? 'رقم الإشعار / المرجع' : 'Reference / Receipt No.';
  String get recordPaymentBtn => isArabic ? 'تسجيل الدفعة' : 'Record Payment';
  String get errorOverpayment => isArabic
      ? 'المبلغ المدفوع يتجاوز الرصيد المتبقي على الفاتورة'
      : 'Payment amount exceeds remaining balance';

  // Returns & Refunds
  String get returnTitle => isArabic ? 'تسجيل مرتجع مبيعات' : 'Sales Return';
  String get returnNumber => isArabic ? 'رقم المرتجع' : 'Return Number';
  String get returnDate => isArabic ? 'تاريخ المرتجع' : 'Return Date';
  String get originalInvoiceLabel =>
      isArabic ? 'الفاتورة الأصلية' : 'Original Invoice';
  String get returnQtyLabel => isArabic ? 'الكمية المرتجعة' : 'Return Qty';
  String get maxReturnableQty =>
      isArabic ? 'الحد الأقصى القابل للإرجاع' : 'Max returnable';
  String get returnReasonLabel => isArabic ? 'سبب المرتجع' : 'Return Reason';
  String get refundMethodLabel =>
      isArabic ? 'طريقة التسوية / الرد' : 'Refund Method';
  String get refundCash => isArabic ? 'رد نقدي فوري' : 'Direct Cash Refund';
  String get refundCredit =>
      isArabic ? 'رصيد دائن للعميل' : 'Customer Account Credit';
  String get calculatedRefundAmount =>
      isArabic ? 'إجمالي مبلغ الاسترداد' : 'Calculated Refund Amount';
  String get errorQtyExceedsSold => isArabic
      ? 'الكمية المرتجعة تتجاوز الكمية المباعة المتبقية'
      : 'Return quantity exceeds remaining sold quantity';
  String get confirmReturnBtn =>
      isArabic ? 'تأكيد وحفظ المرتجع' : 'Confirm Return';

  // Cancellation
  String get cancelInvoiceTitle =>
      isArabic ? 'إلغاء الفاتورة' : 'Cancel Invoice';
  String get cancelInvoiceWarning => isArabic
      ? 'تنبيه: لا يمكن حذف الفواتير الصادرة مالياً لضمان النزاهة المحاسبية. سيتم حفظ الفاتورة كملغاة مع الاحتفاظ برقمها وسجلاتها المالية.'
      : 'Warning: Issued financial documents cannot be permanently deleted. The invoice will be permanently marked as cancelled while retaining its number and audit trail.';
  String get cancelReasonLabel =>
      isArabic ? 'سبب الإلغاء (مطلوب) *' : 'Cancellation Reason (Required) *';
  String get confirmCancelBtn =>
      isArabic ? 'تأكيد الإلغاء' : 'Confirm Cancellation';

  // Customers & Suppliers
  String get nameLabel => isArabic ? 'الاسم *' : 'Name *';
  String get phoneLabel => isArabic ? 'الهاتف' : 'Phone';
  String get addressLabel => isArabic ? 'العنوان' : 'Address';
  String get emailLabel => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get openingBalanceLabel =>
      isArabic ? 'الرصيد الافتتاحي' : 'Opening Balance';
  String get currentBalanceLabel =>
      isArabic ? 'الرصيد الحالي' : 'Current Balance';
  String get statementTitle => isArabic ? 'كشف الحساب' : 'Account Statement';
  String get totalReceivable =>
      isArabic ? 'إجمالي الذمم المدينة' : 'Total Receivables';
  String get totalPayable =>
      isArabic ? 'إجمالي الذمم الدائنة' : 'Total Payables';
  String get selectSupplierBtn => isArabic ? 'اختر المورد' : 'Select Supplier';

  // Products
  String get productCatalogTitle =>
      isArabic ? 'دليل المنتجات والخدمات' : 'Products & Services Catalog';
  String get addProductBtn => isArabic ? 'إضافة منتج' : 'Add Product';
  String get skuLabel => isArabic ? 'رمز الصنف (SKU)' : 'SKU / Barcode';
  String get defaultPriceLabel =>
      isArabic ? 'سعر البيع الافتراضي' : 'Default Unit Price';
  String get sellingPriceLabel => isArabic ? 'سعر البيع' : 'Selling Price';
  String get categoryLabel => isArabic ? 'التصنيف' : 'Category';
  String get barcodeLabel => isArabic ? 'الباركود (Barcode)' : 'Barcode';
  String get costPriceLabel => isArabic ? 'سعر التكلفة' : 'Cost Price';
  String get stockQuantityLabel => isArabic ? 'كمية المخزون' : 'Stock Quantity';
  String get reorderLevelLabel => isArabic ? 'حد إعادة الطلب' : 'Reorder Level';
  String get trackInventoryLabel =>
      isArabic ? 'تتبع المخزون' : 'Track Inventory';
  String get inStockLabel => isArabic ? 'متوفر' : 'In Stock';
  String get lowStockLabel => isArabic ? 'مخزون منخفض' : 'Low Stock';
  String get outOfStockLabel => isArabic ? 'نفد المخزون' : 'Out of Stock';
  String get scanBarcodeBtn => isArabic ? 'مسح الباركود' : 'Scan Barcode';
  String get selectProductBtn =>
      isArabic ? 'إضافة من المنتجات' : 'Select from Catalog';
  String get productNotFound =>
      isArabic ? 'لم يتم العثور على المنتج' : 'Product not found';

  // Reports
  String get reportPeriodSales =>
      isArabic ? 'تقرير المبيعات لفترة' : 'Sales for Period';
  String get reportCollections =>
      isArabic ? 'تقرير التحصيلات والمستحقات' : 'Collections & Outstanding';
  String get reportCustomerDebts =>
      isArabic ? 'تقرير ديون العملاء' : 'Customer Debts';
  String get reportSupplierPayables =>
      isArabic ? 'تقرير مستحقات الموردين' : 'Supplier Payables';
  String get reportPurchases =>
      isArabic ? 'تقرير المشتريات' : 'Purchases for Period';
  String get reportReturns =>
      isArabic ? 'تقرير المرتجعات والاستردادات' : 'Sales Returns & Refunds';
  String get reportCancelled =>
      isArabic ? 'تقرير الفواتير الملغاة' : 'Cancelled Invoices';
  String get fromDateLabel => isArabic ? 'من تاريخ' : 'From Date';
  String get toDateLabel => isArabic ? 'إلى تاريخ' : 'To Date';
  String get applyFilterBtn => isArabic ? 'تطبيق التصفية' : 'Apply Filter';
  String get exportReportBtn => isArabic ? 'تصدير التقرير' : 'Export Report';
  String get noDataFound => isArabic
      ? 'لا توجد بيانات مطابقة للفترة المحددة'
      : 'No data found for the selected period';

  // Export & Print
  String get previewPdfBtn =>
      isArabic ? 'معاينة / طباعة PDF' : 'Preview / Print PDF';
  String get shareDocumentBtn => isArabic ? 'مشاركة الوثيقة' : 'Share Document';
  String get invoiceDocLanguage =>
      isArabic ? 'لغة الفاتورة' : 'Invoice Language';
  String get langArabic => isArabic ? 'العربية' : 'Arabic';
  String get langEnglish => isArabic ? 'الإنجليزية' : 'English';

  // Backup & Restore
  String get backupSectionTitle => isArabic
      ? 'النسخ الاحتياطي واستعادة البيانات'
      : 'Backup & Data Restoration';
  String get createBackupBtn =>
      isArabic ? 'إنشاء نسخة احتياطية الآن' : 'Create Backup Now';
  String get restoreBackupBtn =>
      isArabic ? 'استعادة من نسخة احتياطية' : 'Restore from Backup';
  String get backupNotice => isArabic
      ? 'يتم حفظ جميع الفواتير والحسابات وسجلات المتجر في ملف مشفر وموثق محلياً على جهازك.'
      : 'All invoices, accounts, and business records are saved locally in a verified archive on your device.';
  String get restoreWarning => isArabic
      ? 'تحذير: استعادة نسخة احتياطية ستستبدل البيانات الحالية ببيانات النسخة بعد التحقق من سلامتها. هل تريد المتابعة؟'
      : 'Warning: Restoring a backup will replace current data with the verified backup archive. Do you want to continue?';
  String get backupSuccess => isArabic
      ? 'تم إنشاء النسخة الاحتياطية بنجاح'
      : 'Backup created successfully';
  String get restoreSuccess =>
      isArabic ? 'تمت استعادة البيانات بنجاح' : 'Data restored successfully';
  String get backupInvalidError => isArabic
      ? 'ملف النسخة الاحتياطية غير صالح أو تالف'
      : 'Invalid or corrupted backup file';

  // Settings
  String get settingsTheme => isArabic ? 'المظهر' : 'Theme';
  String get themeSystem => isArabic ? 'حسب النظام' : 'Follow System';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get themeDark => isArabic ? 'داكن' : 'Dark';
  String get settingsLanguage =>
      isArabic ? 'لغة التطبيق' : 'Application Language';
  String get settingsShopProfile =>
      isArabic ? 'بيانات المتجر والنشاط' : 'Shop Profile';
  String get settingsTaxConfig =>
      isArabic ? 'إعدادات الضريبة الافتراضية' : 'Default Tax Configuration';
  String get taxEnabledLabel =>
      isArabic ? 'تفعيل الضريبة افتراضياً' : 'Enable Tax by Default';
  String get settingsInvoicePrefix =>
      isArabic ? 'نظام ترقيم الفواتير' : 'Invoice Numbering';
  String get numberingRuleDesc => isArabic
      ? 'تنسيق الترقيم اليومي المتسلسل: Ftr-DD.MM.YYYY-NNNN'
      : 'Daily sequential numbering format: Ftr-DD.MM.YYYY-NNNN';

  // Shop Identity & Signatures
  String get shopLogoLabel => isArabic ? 'شعار المتجر' : 'Shop Logo';
  String get pickLogoBtn => isArabic ? 'اختيار شعار' : 'Choose Logo';
  String get changeLogoBtn => isArabic ? 'تغيير الشعار' : 'Change Logo';
  String get removeLogoBtn => isArabic ? 'حذف الشعار' : 'Remove Logo';
  String get shopSignatureLabel =>
      isArabic ? 'التوقيع الإلكتروني والختم' : 'Electronic Signature & Stamp';
  String get pickSignatureBtn =>
      isArabic ? 'اختيار التوقيع / الختم' : 'Choose Signature / Stamp';
  String get changeSignatureBtn =>
      isArabic ? 'تغيير التوقيع' : 'Change Signature';
  String get removeSignatureBtn =>
      isArabic ? 'حذف التوقيع' : 'Remove Signature';
  String get authorizedSignatureLabel =>
      isArabic ? 'التوقيع والختم المعتمد' : 'Authorized Signature & Stamp';

  // Customer Selection & Payments in Invoices
  String get customerTypeLabel => isArabic ? 'نوع العميل' : 'Customer Type';
  String get walkInCustomer => isArabic ? 'عميل عام (نقدي)' : 'Walk-in (Cash)';
  String get existingCustomer => isArabic ? 'عميل مسجل' : 'Existing Customer';
  String get newCustomer => isArabic ? 'عميل جديد' : 'New Customer';
  String get walkInCustomerSubtitle => isArabic
      ? 'مبيعات نقدية مباشرة دون فتح حساب مديونية أو تسجيل اسم العميل'
      : 'Direct cash sale with no debt account or customer record';
  String get paymentOptionsTitle =>
      isArabic ? 'حالة السداد والدفع' : 'Payment & Settlement';
  String get paymentOptionFullyPaid =>
      isArabic ? 'تم الدفع بالكامل' : 'Fully Paid';
  String get paymentOptionPartiallyPaid =>
      isArabic ? 'دفع جزء من المبلغ' : 'Partially Paid';
  String get paymentOptionUnpaid =>
      isArabic ? 'آجل (لم يدفع بعد)' : 'Unpaid (On Credit)';
  String get amountReceivedLabel =>
      isArabic ? 'المبلغ المستلم' : 'Amount Received';
  String get serviceItemLabel => isArabic ? 'خدمة' : 'Service';

  // Common Actions
  String get saveBtn => isArabic ? 'حفظ' : 'Save';
  String get cancelBtn => isArabic ? 'إلغاء' : 'Cancel';
  String get deleteBtn => isArabic ? 'حذف' : 'Delete';
  String get editBtn => isArabic ? 'تعديل' : 'Edit';
  String get searchHint => isArabic ? 'بحث...' : 'Search...';
  String get allLabel => isArabic ? 'الكل' : 'All';
  String get detailsBtn => isArabic ? 'التفاصيل' : 'Details';
  String get closeBtn => isArabic ? 'إغلاق' : 'Close';
  String get successMsg =>
      isArabic ? 'تمت العملية بنجاح' : 'Operation completed successfully';
  String get errorMsg => isArabic
      ? 'حدث خطأ، يرجى المحاولة مرة أخرى'
      : 'An error occurred, please try again';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
