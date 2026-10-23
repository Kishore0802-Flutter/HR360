import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'design.dart';

class PayslipPage extends StatefulWidget {
  final Api api;
  const PayslipPage({super.key, required this.api});
  @override
  State<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends State<PayslipPage> {
  late DateTime month;
  bool busy = false;
  List<Json>? slips;
  Object? error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month - 1);
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.get('/payslips');
      final rows = items(result);
      if (!mounted) return;
      setState(() {
        slips = rows;
        error = null;
        if (rows.isNotEmpty) {
          rows.sort((a, b) {
            final ay =
                ((a['year'] as num?) ?? 0) * 12 + ((a['month'] as num?) ?? 0);
            final by =
                ((b['year'] as num?) ?? 0) * 12 + ((b['month'] as num?) ?? 0);
            return by.compareTo(ay);
          });
          final latest = rows.first;
          month = DateTime(
            (latest['year'] as num).toInt(),
            (latest['month'] as num).toInt(),
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Json? get slip {
    for (final row in slips ?? const <Json>[]) {
      if (row['year'] is num &&
          row['month'] is num &&
          (row['year'] as num).toInt() == month.year &&
          (row['month'] as num).toInt() == month.month) {
        return row;
      }
    }
    return null;
  }

  bool get ready => slip != null;

  int _amount(String key) => (slip?[key] as num?)?.round() ?? 0;
  int get basic => _amount('basic');
  int get hra => _amount('hra');
  int get allowance => _amount('allowances');
  int get deduction => _amount('deductions');
  int get gross =>
      slip?['gross'] == null ? basic + hra + allowance : _amount('gross');
  int get net => slip?['net'] == null ? gross - deduction : _amount('net');

  Json get profile => widget.api.profile ?? {};

  String get employeeId {
    final code = profile['code']?.toString() ?? '';
    if (code.isNotEmpty) return code;
    return profile['id']?.toString() ?? '';
  }

  String get employeeName {
    final name = profile['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Employee' : name;
  }

  String get department => profile['department']?.toString() ?? 'People';
  String get designation => profile['designation']?.toString() ?? 'Team member';

  String get office {
    final value = profile['office'];
    if (value is Map && value['name'] != null) return value['name'].toString();
    return 'Chennai';
  }

  String get period {
    final end = DateTime(month.year, month.month + 1, 0);
    return '${_mon(month)} 01 – ${_mon(month)} ${end.day}, ${month.year}';
  }

  String get payDate {
    final paid = DateTime(month.year, month.month + 1, 6);
    return '${_mon(paid)} ${paid.day.toString().padLeft(2, '0')}, ${paid.year}';
  }

  String get runId =>
      'PR-${month.year}${month.month.toString().padLeft(2, '0')}';

  Future<File> _pdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'HR#360  ·  Payslip ${_mon(month)} ${month.year}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('$employeeName  ·  $employeeId'),
            pw.Text('$department  ·  $designation'),
            pw.Text('Pay period $period'),
            pw.Text('Pay date $payDate'),
            pw.SizedBox(height: 16),
            pw.Text('Basic salary  Rs ${_inr(basic)}'),
            pw.Text('House rent allowance  Rs ${_inr(hra)}'),
            pw.Text('Allowances  Rs ${_inr(allowance)}'),
            pw.Text('Total earnings  Rs ${_inr(gross)}'),
            pw.SizedBox(height: 8),
            pw.Text('Deductions  Rs ${_inr(deduction)}'),
            pw.SizedBox(height: 8),
            pw.Text(
              'Net pay  Rs ${_inr(net)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Payslip-${_mon(month)}-${month.year}.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  Future<void> download() async {
    setState(() => busy = true);
    try {
      await _pdf();
      if (mounted) message(context, 'Payslip saved on this device.');
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> share() async {
    setState(() => busy = true);
    try {
      final file = await _pdf();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Payslip ${_mon(month)} ${month.year}',
        ),
      );
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickMonth() async {
    final now = DateTime.now();
    final months = List.generate(12, (i) => DateTime(now.year, now.month - i));
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Pay month',
                style: TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final item in months)
              ListTile(
                title: Text('${_mon(item)} ${item.year}'),
                trailing: item.year == month.year && item.month == month.month
                    ? const Icon(Icons.check, color: primary)
                    : null,
                onTap: () => Navigator.pop(sheet, item),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => month = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6F7FB),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: ink),
              ),
              const Expanded(
                child: Text(
                  'Payslip',
                  style: TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: pickMonth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: Color(0xFF6E7C8A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_mon(month)} ${month.year}',
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const Icon(Icons.expand_more, color: Color(0xFF8B93A7)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (slips == null && error == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            FailureView(error!, load)
          else if (!ready)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: EmptyView(
                'Not generated yet',
                'This month’s payslip appears after the pay run is complete.',
              ),
            )
          else ...[
            _card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2559),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HR#360',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          office,
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        const Text(
                          'India',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'PAY SLIP',
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_mon(month)} ${month.year}',
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFF1B7F56)),
                          SizedBox(width: 4),
                          Text(
                            'Generated',
                            style: TextStyle(
                              color: Color(0xFF1B7F56),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _grid([
              _pair('Employee ID', employeeId),
              _pair('Pay Period', period),
              _pair('Employee Name', employeeName),
              _pair('Pay Date', payDate),
              _pair('Department', department),
              _pair('Payroll Run ID', runId),
              _pair('Designation', designation),
              _pair('Status', 'Completed'),
            ]),
            const SizedBox(height: 12),
            _moneyBlock(
              icon: Icons.payments_outlined,
              title: 'Earnings',
              tint: const Color(0xFFE7F6EE),
              accent: const Color(0xFF1B7F56),
              rows: [
                ('Basic Salary', _inr(basic)),
                ('House Rent Allowance (HRA)', _inr(hra)),
                ('Allowances', _inr(allowance)),
              ],
              totalLabel: 'Total Earnings (Gross)',
              total: _inr(gross),
            ),
            const SizedBox(height: 12),
            _moneyBlock(
              icon: Icons.receipt_long_outlined,
              title: 'Deductions',
              tint: const Color(0xFFFDECEC),
              accent: const Color(0xFFE15B64),
              rows: [('Deductions', _inr(deduction))],
              totalLabel: 'Total Deductions',
              total: _inr(deduction),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Net Pay',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Amount credited to your bank',
                          style: TextStyle(
                            color: Color(0xFF6E7C8A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${_inr(net)}',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF8B93A7)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This is a system generated payslip and does not require a signature.',
                    style: TextStyle(color: Color(0xFF8B93A7), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B2559),
                      side: const BorderSide(color: Color(0xFFD5DBE8)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy ? null : download,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2559),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy ? null : share,
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Payslip'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _card({required Widget child}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE6EAF0)),
  ),
  child: child,
);

Widget _grid(List<Widget> cells) => Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE6EAF0)),
  ),
  child: Table(
    border: const TableBorder(
      horizontalInside: BorderSide(color: Color(0xFFE6EAF0)),
      verticalInside: BorderSide(color: Color(0xFFE6EAF0)),
    ),
    children: [
      for (var i = 0; i < cells.length; i += 2)
        TableRow(children: [cells[i], cells[i + 1]]),
    ],
  ),
);

Widget _pair(String label, String value) => Padding(
  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
);

Widget _moneyBlock({
  required IconData icon,
  required String title,
  required Color tint,
  required Color accent,
  required List<(String, String)> rows,
  required String totalLabel,
  required String total,
}) => Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE6EAF0)),
  ),
  child: Column(
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              'Amount (₹)',
              style: TextStyle(
                color: accent.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.$1,
                  style: const TextStyle(color: ink, fontSize: 13),
                ),
              ),
              Text(
                row.$2,
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                totalLabel,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              total,
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ],
  ),
);

String _mon(DateTime date) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[date.month - 1];
}

String _inr(int value) {
  final digits = value.abs().toString();
  if (digits.length <= 3) return digits;
  final tail = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${parts.join(',')},$tail';
}
