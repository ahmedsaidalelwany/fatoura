import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:fatoura/core/precision/currency_formatter.dart';
import 'package:fatoura/features/invoices/domain/entities/invoice.dart';

class InvoicePdfGenerator {
  InvoicePdfGenerator._();

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _loadFonts() async {
    if (_regularFont == null || _boldFont == null) {
      final regData = await rootBundle.load('assets/fonts/AppFont-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/AppFont-Bold.ttf');
      _regularFont = pw.Font.ttf(regData);
      _boldFont = pw.Font.ttf(boldData);
    }
  }

  /// Generates a professional, print-ready PDF for an invoice
  static Future<Uint8List> generateInvoicePdf({
    required Invoice invoice,
    required bool isArabic,
  }) async {
    await _loadFonts();

    pw.MemoryImage? logoImage;
    if (invoice.shopLogoPath.isNotEmpty) {
      try {
        final file = File(invoice.shopLogoPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    pw.MemoryImage? signatureImage;
    if (invoice.shopSignaturePath.isNotEmpty) {
      try {
        final file = File(invoice.shopSignaturePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          signatureImage = pw.MemoryImage(bytes);
        }
      } catch (_) {}
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
    );

    final textDirection = isArabic
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    final alignment = isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final formattedDate = dateFormat.format(invoice.issueDate);

    // Labels based on template
    final String title;
    final String descHeader;
    final String qtyHeader;
    final String priceHeader;
    final isMixed = invoice.template == InvoiceTemplate.mixed;
    final typeHeader = isArabic ? 'النوع' : 'Type';

    switch (invoice.template) {
      case InvoiceTemplate.service:
        title = isArabic
            ? 'فاتورة خدمات مهنية'
            : 'PROFESSIONAL SERVICES INVOICE';
        descHeader = isArabic
            ? 'بيان الخدمة / نطاق العمل'
            : 'Service Description / Scope';
        qtyHeader = isArabic ? 'الوحدات / الساعات' : 'Units / Hours';
        priceHeader = isArabic ? 'معدل الوحدة' : 'Rate';
        break;
      case InvoiceTemplate.mixed:
        title = isArabic
            ? 'فاتورة مبيعات وخدمات'
            : 'PRODUCTS & SERVICES INVOICE';
        descHeader = isArabic ? 'البيان' : 'Description';
        qtyHeader = isArabic ? 'الكمية' : 'Qty';
        priceHeader = isArabic ? 'سعر الوحدة' : 'Unit Price';
        break;
      case InvoiceTemplate.product:
        title = isArabic ? 'فاتورة مبيعات منتجات' : 'PRODUCT SALES INVOICE';
        descHeader = isArabic ? 'المنتج / الصنف' : 'Product / Item';
        qtyHeader = isArabic ? 'الكمية' : 'Qty';
        priceHeader = isArabic ? 'سعر الوحدة' : 'Unit Price';
        break;
    }

    final invNumLabel = isArabic ? 'رقم الفاتورة:' : 'Invoice No:';
    final dateLabel = isArabic ? 'تاريخ الإصدار:' : 'Date:';
    final billToLabel = isArabic ? 'بيانات العميل:' : 'Bill To:';
    final cashSaleLabel = isArabic
        ? 'عميل نقدي / مبيعات عامة'
        : 'Cash / Anonymous Sale';
    final taxNoLabel = isArabic ? 'الرقم الضريبي:' : 'Tax No:';
    final totalHeader = isArabic ? 'الإجمالي' : 'Total';
    final subtotalLabel = isArabic ? 'المجموع الفرعي:' : 'Subtotal:';
    final discountLabel = isArabic ? 'الخصم:' : 'Discount:';
    final taxableBaseLabel = isArabic ? 'الوعاء الضريبي:' : 'Taxable Base:';
    final taxLabel = isArabic
        ? 'ضريبة القيمة المضافة (${invoice.taxRate}%):'
        : 'Tax (${invoice.taxRate}%):';
    final finalTotalLabel = isArabic ? 'الإجمالي النهائي:' : 'Total Payable:';
    final paidLabel = isArabic ? 'المبلغ المسدد:' : 'Amount Paid:';
    final balanceLabel = isArabic ? 'الرصيد المتبقي:' : 'Remaining Balance:';
    final statusCancelled = isArabic ? 'ملغاة' : 'CANCELLED';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: textDirection,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: pw.EdgeInsets.only(
                            right: isArabic ? 0 : 12,
                            left: isArabic ? 12 : 0,
                          ),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            invoice.shopName.isNotEmpty
                                ? invoice.shopName
                                : (isArabic ? 'متجر فاتورة' : 'Fatoura Shop'),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                          if (invoice.shopPhone.isNotEmpty)
                            pw.Text(
                              invoice.shopPhone,
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          if (invoice.shopAddress.isNotEmpty)
                            pw.Text(
                              invoice.shopAddress,
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          if (invoice.shopTaxNumber.isNotEmpty)
                            pw.Text(
                              '$taxNoLabel ${invoice.shopTaxNumber}',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: isArabic
                        ? pw.CrossAxisAlignment.end
                        : pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.isCancelled
                              ? PdfColors.red800
                              : PdfColors.blue900,
                        ),
                      ),
                      if (invoice.isCancelled)
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red50,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.red800),
                          ),
                          child: pw.Text(
                            statusCancelled,
                            style: pw.TextStyle(
                              color: PdfColors.red800,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '$invNumLabel ${invoice.invoiceNumber}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                      pw.Text(
                        '$dateLabel $formattedDate',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Customer / Bill-To Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      billToLabel,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      invoice.customerName.isNotEmpty
                          ? invoice.customerName
                          : cashSaleLabel,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (invoice.customerPhone.isNotEmpty)
                      pw.Text(
                        invoice.customerPhone,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    if (invoice.customerAddress.isNotEmpty)
                      pw.Text(
                        invoice.customerAddress,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Line Items Table
              if (isMixed)
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue50,
                      ),
                      children: [
                        _buildTableCell(
                          descHeader,
                          isHeader: true,
                          align: alignment,
                        ),
                        _buildTableCell(
                          typeHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          qtyHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          priceHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          totalHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                      ],
                    ),
                    // Items
                    ...invoice.items.map(
                      (item) => pw.TableRow(
                        children: [
                          _buildTableCell(item.description, align: alignment),
                          _buildTableCell(
                            item.isService
                                ? (isArabic ? 'خدمة' : 'Service')
                                : (isArabic ? 'منتج' : 'Product'),
                            align: pw.Alignment.center,
                          ),
                          _buildTableCell(
                            item.quantity.toString(),
                            align: pw.Alignment.center,
                          ),
                          _buildTableCell(
                            CurrencyFormatter.format(
                              item.unitPrice,
                              currency: invoice.currency,
                              isArabic: isArabic,
                            ),
                            align: pw.Alignment.center,
                          ),
                          _buildTableCell(
                            CurrencyFormatter.format(
                              item.lineTotal,
                              currency: invoice.currency,
                              isArabic: isArabic,
                            ),
                            align: pw.Alignment.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue50,
                      ),
                      children: [
                        _buildTableCell(
                          descHeader,
                          isHeader: true,
                          align: alignment,
                        ),
                        _buildTableCell(
                          qtyHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          priceHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          totalHeader,
                          isHeader: true,
                          align: pw.Alignment.center,
                        ),
                      ],
                    ),
                    // Items
                    ...invoice.items.map(
                      (item) => pw.TableRow(
                        children: [
                          _buildTableCell(item.description, align: alignment),
                          _buildTableCell(
                            item.quantity.toString(),
                            align: pw.Alignment.center,
                          ),
                          _buildTableCell(
                            CurrencyFormatter.format(
                              item.unitPrice,
                              currency: invoice.currency,
                              isArabic: isArabic,
                            ),
                            align: pw.Alignment.center,
                          ),
                          _buildTableCell(
                            CurrencyFormatter.format(
                              item.lineTotal,
                              currency: invoice.currency,
                              isArabic: isArabic,
                            ),
                            align: pw.Alignment.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              pw.SizedBox(height: 16),

              // Summary Calculations Box
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Notes Area
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (invoice.notes.isNotEmpty) ...[
                          pw.Text(
                            isArabic ? 'ملاحظات:' : 'Notes:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColors.blue800,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invoice.notes,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                        if (invoice.isCancelled &&
                            invoice.cancellationReason != null) ...[
                          pw.SizedBox(height: 8),
                          pw.Text(
                            isArabic ? 'سبب الإلغاء:' : 'Cancellation Reason:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                              color: PdfColors.red800,
                            ),
                          ),
                          pw.Text(
                            invoice.cancellationReason!,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),

                  // Financial Totals
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow(
                          subtotalLabel,
                          CurrencyFormatter.format(
                            invoice.subtotal,
                            currency: invoice.currency,
                            isArabic: isArabic,
                          ),
                        ),
                        if (invoice.discountAmount > 0)
                          _buildSummaryRow(
                            discountLabel,
                            '-${CurrencyFormatter.format(invoice.discountAmount, currency: invoice.currency, isArabic: isArabic)}',
                            color: PdfColors.red700,
                          ),
                        if (invoice.taxAmount > 0) ...[
                          _buildSummaryRow(
                            taxableBaseLabel,
                            CurrencyFormatter.format(
                              invoice.taxableBase,
                              currency: invoice.currency,
                              isArabic: isArabic,
                            ),
                          ),
                          _buildSummaryRow(
                            taxLabel,
                            '+${CurrencyFormatter.format(invoice.taxAmount, currency: invoice.currency, isArabic: isArabic)}',
                          ),
                        ],
                        pw.Divider(color: PdfColors.blue800, thickness: 1),
                        _buildSummaryRow(
                          finalTotalLabel,
                          CurrencyFormatter.format(
                            invoice.finalTotal,
                            currency: invoice.currency,
                            isArabic: isArabic,
                          ),
                          isBold: true,
                          fontSize: 12,
                          color: PdfColors.blue900,
                        ),
                        _buildSummaryRow(
                          paidLabel,
                          CurrencyFormatter.format(
                            invoice.totalPaid,
                            currency: invoice.currency,
                            isArabic: isArabic,
                          ),
                          color: PdfColors.green800,
                        ),
                        _buildSummaryRow(
                          balanceLabel,
                          CurrencyFormatter.format(
                            invoice.remainingBalance,
                            currency: invoice.currency,
                            isArabic: isArabic,
                          ),
                          isBold: true,
                          color: invoice.remainingBalance > 0
                              ? PdfColors.red800
                              : PdfColors.green800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (signatureImage != null) ...[
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: isArabic
                      ? pw.MainAxisAlignment.start
                      : pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 140,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            isArabic
                                ? 'التوقيع والختم المعتمد'
                                : 'Authorized Signature & Stamp',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            height: 44,
                            child: pw.Image(
                              signatureImage,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              pw.Spacer(),

              // Footer Note
              pw.Center(
                child: pw.Text(
                  isArabic
                      ? 'تم إصدار هذه الوثيقة إلكترونياً بواسطة نظام فاتورة'
                      : 'Generated electronically via Fatoura Invoicing System',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blue900 : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 9,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates standard A4 PDF (alias for generateInvoicePdf)
  static Future<Uint8List> generateA4Pdf({
    required Invoice invoice,
    required bool isArabic,
  }) async {
    return generateInvoicePdf(invoice: invoice, isArabic: isArabic);
  }

  /// Generates a dedicated narrow thermal receipt layout (standard 80mm roll)
  static Future<Uint8List> generateThermalReceiptPdf({
    required Invoice invoice,
    required bool isArabic,
    double paperWidthMm = 80.0,
  }) async {
    await _loadFonts();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
    );

    final textDirection = isArabic
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final formattedDate = dateFormat.format(invoice.issueDate);

    final title = switch (invoice.template) {
      InvoiceTemplate.service =>
        (isArabic ? 'إيصال خدمات مهنية' : 'SERVICE RECEIPT'),
      InvoiceTemplate.product => (isArabic ? 'إيصال مبيعات' : 'SALES RECEIPT'),
      InvoiceTemplate.mixed =>
        (isArabic ? 'إيصال مبيعات وخدمات' : 'SALES RECEIPT'),
    };

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          paperWidthMm * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        textDirection: textDirection,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Center
              pw.Center(
                child: pw.Text(
                  invoice.shopName.isNotEmpty
                      ? invoice.shopName
                      : (isArabic ? 'متجر فاتورة' : 'Fatoura Shop'),
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (invoice.shopPhone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    invoice.shopPhone,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              if (invoice.shopTaxNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    '${isArabic ? 'الرقم الضريبي:' : 'Tax No:'} ${invoice.shopTaxNumber}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              pw.SizedBox(height: 4),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 4),

              // Title & Info
              pw.Center(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              _buildThermalRow(
                isArabic ? 'رقم الفاتورة:' : 'Invoice No:',
                invoice.invoiceNumber,
              ),
              _buildThermalRow(isArabic ? 'التاريخ:' : 'Date:', formattedDate),
              if (invoice.customerName.isNotEmpty)
                _buildThermalRow(
                  isArabic ? 'العميل:' : 'Customer:',
                  invoice.customerName,
                ),
              pw.SizedBox(height: 4),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 4),

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isArabic ? 'الصنف / الكمية × السعر' : 'Item / Qty x Price',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    isArabic ? 'الإجمالي' : 'Total',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 2),

              // Items List
              ...invoice.items.map((item) {
                final typeTag = invoice.template == InvoiceTemplate.mixed
                    ? (item.isService
                          ? (isArabic ? ' [خدمة]' : ' [Service]')
                          : (isArabic ? ' [منتج]' : ' [Product]'))
                    : '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        '${item.description}$typeTag',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item.quantity} × ${CurrencyFormatter.format(item.unitPrice, currency: invoice.currency, isArabic: isArabic)}',
                            style: const pw.TextStyle(
                              fontSize: 7.5,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Text(
                            CurrencyFormatter.format(
                              item.lineTotal,
                              currency: invoice.currency,
                              isArabic: isArabic,
                            ),
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 4),

              // Totals
              _buildThermalRow(
                isArabic ? 'المجموع الفرعي:' : 'Subtotal:',
                CurrencyFormatter.format(
                  invoice.subtotal,
                  currency: invoice.currency,
                  isArabic: isArabic,
                ),
              ),
              if (invoice.discountAmount > 0)
                _buildThermalRow(
                  isArabic ? 'الخصم:' : 'Discount:',
                  '-${CurrencyFormatter.format(invoice.discountAmount, currency: invoice.currency, isArabic: isArabic)}',
                ),
              if (invoice.taxAmount > 0)
                _buildThermalRow(
                  '${isArabic ? 'الضريبة' : 'Tax'} (${invoice.taxRate}%):',
                  '+${CurrencyFormatter.format(invoice.taxAmount, currency: invoice.currency, isArabic: isArabic)}',
                ),
              pw.SizedBox(height: 2),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 2),

              // Final Total (Prominent)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isArabic ? 'الإجمالي النهائي:' : 'TOTAL:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    CurrencyFormatter.format(
                      invoice.finalTotal,
                      currency: invoice.currency,
                      isArabic: isArabic,
                    ),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildThermalRow(
                isArabic ? 'المدفوع:' : 'Paid:',
                CurrencyFormatter.format(
                  invoice.totalPaid,
                  currency: invoice.currency,
                  isArabic: isArabic,
                ),
              ),
              if (invoice.remainingBalance > 0)
                _buildThermalRow(
                  isArabic ? 'المتبقي:' : 'Balance:',
                  CurrencyFormatter.format(
                    invoice.remainingBalance,
                    currency: invoice.currency,
                    isArabic: isArabic,
                  ),
                  isBold: true,
                ),

              pw.SizedBox(height: 6),
              _buildThermalDashedLine(),
              pw.SizedBox(height: 6),

              // Footer Note
              pw.Center(
                child: pw.Text(
                  isArabic
                      ? 'شكراً لتعاملكم معنا'
                      : 'Thank you for your business!',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'فاتورة • Fatoura',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildThermalDashedLine() {
    return pw.Container(
      height: 1,
      child: pw.LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints?.maxWidth ?? 200;
          const dashWidth = 3.0;
          const dashSpace = 2.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: List.generate(
              dashCount,
              (_) => pw.SizedBox(
                width: dashWidth,
                height: 0.5,
                child: pw.DecoratedBox(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey500),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static pw.Widget _buildThermalRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
