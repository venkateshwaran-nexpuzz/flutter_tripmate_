import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class SupervisorPrintService {
  /// Generates and prints an institutional Daily Bus Verification Log Sheet
  static Future<void> printDailyLogSheet({
    required Map<String, dynamic> bus,
    required Map<String, dynamic> log,
    required String supervisorName,
    String? driverName,
    String? routeName,
  }) async {
    final pdf = pw.Document();

    final dateStr = log['km_date']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now());
    final busNo = bus['bus_number']?.toString() ?? '';
    final regNo = bus['registration_no']?.toString() ?? '';
    final openKm = log['opening_km'] != null ? '${NumberFormat('#,##0.0').format(double.tryParse(log['opening_km'].toString()) ?? 0)} km' : '—';
    final closeKm = log['closing_km'] != null ? '${NumberFormat('#,##0.0').format(double.tryParse(log['closing_km'].toString()) ?? 0)} km' : '—';
    final totalKm = log['total_km'] != null ? '${NumberFormat('#,##0.0').format(double.tryParse(log['total_km'].toString()) ?? 0)} km' : '0.0 km';
    final status = log['verification_status']?.toString().toUpperCase() ?? 'VERIFIED';
    final remarks = log['verification_remarks']?.toString() ?? 'Daily readings checked and verified with vehicle odometer ($status).';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Institution Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 2)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VELALAR EDUCATIONAL TRUST (VET)',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.Text(
                          'TRANSPORT DEPARTMENT • DAILY BUS LOG VERIFICATION SLIP',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Text(
                      'DATE: $dateStr',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Bus & Personnel Details Table
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BUS ASSET: Bus $busNo ($regNo)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          pw.SizedBox(height: 4),
                          pw.Text('ASSIGNED ROUTE: ${routeName ?? 'Campus Fleet'}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BUS SUPERVISOR: $supervisorName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text('DRIVER NAME: ${driverName ?? 'Assigned Driver'}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // Odometer Verification Breakdown
              pw.Text('ODOMETER AUDIT & KM METRICS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue800)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Audit Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Driver / GPS Log', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Supervisor Verified Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Opening Odometer (AM Departure)', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(openKm, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(openKm, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Closing Odometer (PM Arrival)', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(closeKm, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(closeKm, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Net Day Run (Total KM)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(totalKm, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(totalKm, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // Supervisor Notes
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SUPERVISOR INSPECTION NOTES / VEHICLE CONDITION:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Text(remarks, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 130, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Driver Signature', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Bus Supervisor ($supervisorName)', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Transport Manager Approval', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text('Generated by TripMate Fleet Control System • Velalar Educational Trust', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'VET_Daily_Bus_Log_${busNo}_$dateStr.pdf',
    );
  }

  /// Generates and prints a Maintenance Ticket & PO Purchase Requisition Voucher
  static Future<void> printPoVoucher({
    required Map<String, dynamic> ticket,
    required List<dynamic> items,
  }) async {
    final pdf = pw.Document();

    final ticketNo = ticket['ticket_no']?.toString() ?? 'PO-NEW';
    final dateStr = ticket['created_at'] != null
        ? DateFormat('dd-MMM-yyyy (hh:mm a)').format(DateTime.tryParse(ticket['created_at'].toString()) ?? DateTime.now())
        : DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final busNo = ticket['bus_number']?.toString() ?? '';
    final regNo = ticket['registration_no']?.toString() ?? '';
    final supervisor = ticket['supervisor_name']?.toString() ?? 'Bus Supervisor';
    final category = ticket['category']?.toString().toUpperCase() ?? 'MECHANICAL';
    final priority = ticket['priority']?.toString().toUpperCase() ?? 'MEDIUM';
    final title = ticket['title']?.toString() ?? '';
    final description = ticket['description']?.toString() ?? '';
    final odo = ticket['current_odometer'] != null ? '${ticket['current_odometer']} km' : '—';
    final vendor = ticket['vendor_suggestion']?.toString() ?? 'Local Authorized Spares Store';
    final estTotal = double.tryParse(ticket['estimated_total_cost']?.toString() ?? '0') ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Formal Institutional Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo900, width: 2.5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('VELALAR EDUCATIONAL TRUST', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        pw.Text('VEHICLE WORKSHOP & MAINTENANCE PURCHASE REQUISITION', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PO / TICKET NO:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(ticketNo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                        pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Bus & Category Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BUS: Bus $busNo ($regNo)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('CURRENT METER: $odo', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('RAISED BY: $supervisor', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CATEGORY: $category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('PRIORITY: $priority', style: pw.TextStyle(fontSize: 9, color: priority == 'CRITICAL' ? PdfColors.red : PdfColors.black)),
                        pw.Text('VENDOR: $vendor', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Issue Details
              pw.Text('ISSUE / COMPLAINT DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 3),
                    pw.Text(description, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Requisition Items Table
              pw.Text('PARTS / SPARES REQUISITION (PURCHASE LIST):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('S.No', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Est. Rate (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total (Rs.)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  if (items.isEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('1', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('In-House Repair / Labour (No parts to purchase)', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('1', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Job', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('0.00', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('0.00', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      ],
                    )
                  else
                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final it = entry.value as Map<String, dynamic>;
                      final q = double.tryParse(it['quantity']?.toString() ?? '1') ?? 1.0;
                      final p = double.tryParse(it['estimated_price']?.toString() ?? '0') ?? 0.0;
                      final total = q * p;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['item_name']?.toString() ?? '', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$q', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(it['unit']?.toString() ?? 'Nos', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(NumberFormat('#,##0.00').format(p), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(NumberFormat('#,##0.00').format(total), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                        ],
                      );
                    }),
                ],
              ),

              pw.SizedBox(height: 8),

              // Total Amount
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('TOTAL ESTIMATED REQUISITION COST: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Rs. ${NumberFormat('#,##0.00').format(estTotal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.indigo900)),
                ],
              ),

              pw.Spacer(),

              // Signatures Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Bus Supervisor', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('($supervisor)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Workshop Incharge', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('(Technical Verification)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 130, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Transport Manager', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('(Requisition Approved)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Stores / Accounts', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('(Cash / Goods Issued)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Velalar Educational Trust • Fleet Management & Procurement Automation System', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'VET_PO_Voucher_$ticketNo.pdf',
    );
  }
}
