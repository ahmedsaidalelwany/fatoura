import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: _regularFont!, bold: _boldFont!),
    );

    final textDirection = isArabic
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    final alignment = isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final formattedDate = dateFormat.format(invoice.issueDate);

    // Labels
    final title = isArabic ? 'فاتورة مبيعات' : 'SALES INVOICE';
    final invNumLabel = isArabic ? 'رقم الفاتورة:' : 'Invoice No:';
    final dateLabel = isArabic ? 'تاريخ الإصدار:' : 'Date:';
    final billToLabel = isArabic ? 'بيانات العميل:' : 'Bill To:';
    final cashSaleLabel = isArabic
        ? 'عميل نقدي / مبيعات عامة'
        : 'Cash / Anonymous Sale';
    final taxNoLabel = isArabic ? 'الرقم الضريبي:' : 'Tax No:';
    final descHeader = isArabic ? 'البيان / الصنف' : 'Description';
    final qtyHeader = isArabic ? 'الكمية' : 'Qty';
    final priceHeader = isArabic ? 'سعر الوحدة' : 'Unit Price';
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
                  pw.Column(
                    crossAxisAlignment: isArabic
                        ? pw.CrossAxisAlignment.start
                        : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        invoice.shopName.isNotEmpty
                            ? invoice.shopName
                            : (isArabic ? 'متجر فاتورة' : 'Fatoura Shop'),
                        style: pw.TextStyle(
                          fontSize: 20,
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
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
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
                          '${item.unitPrice.toStringAsFixed(2)} ${invoice.currency}',
                          align: pw.Alignment.center,
                        ),
                        _buildTableCell(
                          '${item.lineTotal.toStringAsFixed(2)} ${invoice.currency}',
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
                          '${invoice.subtotal.toStringAsFixed(2)} ${invoice.currency}',
                        ),
                        if (invoice.discountAmount > 0)
                          _buildSummaryRow(
                            discountLabel,
                            '-${invoice.discountAmount.toStringAsFixed(2)} ${invoice.currency}',
                            color: PdfColors.red700,
                          ),
                        if (invoice.taxAmount > 0) ...[
                          _buildSummaryRow(
                            taxableBaseLabel,
                            '${invoice.taxableBase.toStringAsFixed(2)} ${invoice.currency}',
                          ),
                          _buildSummaryRow(
                            taxLabel,
                            '+${invoice.taxAmount.toStringAsFixed(2)} ${invoice.currency}',
                          ),
                        ],
                        pw.Divider(color: PdfColors.blue800, thickness: 1),
                        _buildSummaryRow(
                          finalTotalLabel,
                          '${invoice.finalTotal.toStringAsFixed(2)} ${invoice.currency}',
                          isBold: true,
                          fontSize: 12,
                          color: PdfColors.blue900,
                        ),
                        _buildSummaryRow(
                          paidLabel,
                          '${invoice.totalPaid.toStringAsFixed(2)} ${invoice.currency}',
                          color: PdfColors.green800,
                        ),
                        _buildSummaryRow(
                          balanceLabel,
                          '${invoice.remainingBalance.toStringAsFixed(2)} ${invoice.currency}',
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
}
