import 'package:flutter/material.dart';
import 'api.dart';

/// Holidays page displaying company and optional holidays:
/// `GET /holidays?year=$year&sortBy=date&sortDir=asc&pageSize=500`
///
/// Features:
/// - Year selector (defaults to current year, e.g. 2026)
/// - Search input by holiday name
/// - Total count indicator
/// - Premium card layout (card UI, no calendar as requested)
/// - Type badge (Company holiday / Optional holiday)
class HolidaysPage extends StatefulWidget {
  final Api api;
  final int? initialYear;

  const HolidaysPage({
    super.key,
    required this.api,
    this.initialYear,
  });

  @override
  State<HolidaysPage> createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  static const Color _ink = Color(0xFF1B2A4A);
  static const Color _soft = Color(0xFF6E7C8A);
  static const Color _cardBorder = Color(0xFFE8E2D9);
  static const Color _green = Color(0xFF16A34A);
  static const Color _greenBg = Color(0xFFE7F6EE);
  static const Color _amber = Color(0xFFD97706);
  static const Color _amberBg = Color(0xFFFEF3C7);
  static const Color _pageBg = Color(0xFFFAF8F5);

  late int? _selectedYear;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _holidays = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _loadHolidays();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHolidays() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'pageSize': 500,
        'sortBy': 'date',
        'sortDir': 'asc',
      };
      if (_selectedYear != null) {
        queryParams['year'] = _selectedYear!;
      }

      final res = await widget.api.v1(
        'GET',
        '/holidays',
        query: queryParams,
      );

      if (!mounted) return;

      final items = (res is Map && res['items'] is List)
          ? res['items'] as List
          : (res is List ? res : []);

      setState(() {
        _holidays = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredHolidays {
    if (_searchQuery.trim().isEmpty) return _holidays;
    final q = _searchQuery.trim().toLowerCase();
    return _holidays.where((h) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      final date = (h['date'] ?? '').toString().toLowerCase();
      return name.contains(q) || date.contains(q);
    }).toList();
  }

  void _pickYear() {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - 3 + i);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select Holiday Year',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.all_inclusive_rounded, color: _soft),
                  title: const Text('All Years', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _selectedYear == null ? const Icon(Icons.check, color: _green) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedYear = null);
                    _loadHolidays();
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: years.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final y = years[idx];
                      final isSelected = _selectedYear == y;
                      return ListTile(
                        leading: Icon(
                          Icons.calendar_today_rounded,
                          color: isSelected ? _green : _soft,
                          size: 20,
                        ),
                        title: Text(
                          '$y',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? _green : _ink,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check, color: _green) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedYear = y);
                          _loadHolidays();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredHolidays;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          'Holidays',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: _ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHolidays,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Breadcrumb / Title section
            const Text(
              'HRMS / Holidays',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _soft,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Holidays',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Company holidays are excluded from leave duration (unless a policy counts them) and are not marked absent. Optional holidays are informational.',
              style: TextStyle(
                fontSize: 13,
                color: _soft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Controls Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x061B2A4A),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Year selector pill
                      Material(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _pickYear,
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedYear != null ? '${_selectedYear!}' : 'All Years',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (_selectedYear != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedYear = null);
                                      _loadHolidays();
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: _soft,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 20,
                                    color: _soft,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Search by holiday name
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'By Holiday Name',
                              hintStyle: const TextStyle(fontSize: 13.5, color: _soft),
                              prefixIcon: const Icon(Icons.search, size: 18, color: _soft),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _green, width: 1.5),
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Summary row: "5 holidays in 2026"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedYear != null
                            ? '${list.length} holidays in $_selectedYear'
                            : '${list.length} holidays total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.style_outlined, size: 14, color: _soft),
                            SizedBox(width: 4),
                            Text(
                              'Card view',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _soft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Content Area: Loading, Error, Empty, or Cards
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load holidays: $_error',
                        style: const TextStyle(color: _soft, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _loadHolidays,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (list.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.beach_access_outlined,
                          size: 32,
                          color: _soft,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No holidays found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No holidays match "$_searchQuery".'
                            : 'No holidays listed for $_selectedYear.',
                        style: const TextStyle(color: _soft, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final holiday in list) ...[
                _buildHolidayCard(holiday),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayCard(Map<String, dynamic> holiday) {
    final rawDate = holiday['date']?.toString() ?? '';
    DateTime? dt;
    try {
      if (rawDate.isNotEmpty) {
        dt = DateTime.parse(rawDate);
      }
    } catch (_) {}

    final name = holiday['name']?.toString() ?? 'Holiday';
    final isOptional = holiday['isOptional'] == true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = dt != null && dt.year == today.year && dt.month == today.month && dt.day == today.day;
    final isPast = dt != null && dt.isBefore(today);

    final dayName = dt != null ? _weekdayName(dt.weekday) : '';
    final dayNumber = dt != null ? '${dt.day}' : '';
    final monthShort = dt != null ? _monthShort(dt.month) : '';
    final year = dt != null ? '${dt.year}' : '';

    int? daysDiff;
    if (dt != null && !isPast && !isToday) {
      daysDiff = dt.difference(today).inDays;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? _green : _cardBorder,
          width: isToday ? 1.8 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x061B2A4A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Prominent Date Block
            Container(
              width: 58,
              height: 62,
              decoration: BoxDecoration(
                color: isToday
                    ? _greenBg
                    : (isOptional ? _amberBg : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday
                      ? _green.withValues(alpha: 0.3)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthShort.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isToday ? _green : (isOptional ? _amber : _soft),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayNumber,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isToday ? _green : _ink,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Holiday Info: Name, Date string, Weekday
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isPast ? _soft : _ink,
                          ),
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _soft,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        '$dayNumber $monthShort $year',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _soft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Badges: Company holiday vs Optional holiday & Relative time
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOptional ? _amberBg : _greenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOptional ? 'Optional holiday' : 'Company holiday',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOptional ? _amber : _green,
                          ),
                        ),
                      ),
                      if (daysDiff != null && daysDiff > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            daysDiff == 1 ? 'Tomorrow' : 'In $daysDiff days',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _soft,
                            ),
                          ),
                        ),
                      if (isPast)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  static String _monthShort(int month) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return m[month - 1];
    return '';
  }
}
