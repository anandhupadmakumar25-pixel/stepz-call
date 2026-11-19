import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum DatePreset { allTime, today, yesterday, last7Days, thisMonth, lastMonth, custom }

class DateRangeFilterBar extends StatefulWidget {
  final DatePreset initialPreset;
  final void Function(String? dateFrom, String? dateTo) onChanged;

  const DateRangeFilterBar({
    super.key,
    this.initialPreset = DatePreset.allTime,
    required this.onChanged,
  });

  @override
  State<DateRangeFilterBar> createState() => _DateRangeFilterBarState();
}

class _DateRangeFilterBarState extends State<DateRangeFilterBar> {
  late DatePreset _preset;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _preset = widget.initialPreset;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _selectPreset(DatePreset p) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? f;
    DateTime? t;

    switch (p) {
      case DatePreset.allTime:
        f = null;
        t = null;
        break;
      case DatePreset.today:
        f = today;
        t = today;
        break;
      case DatePreset.yesterday:
        f = today.subtract(const Duration(days: 1));
        t = f;
        break;
      case DatePreset.last7Days:
        f = today.subtract(const Duration(days: 6));
        t = today;
        break;
      case DatePreset.thisMonth:
        f = DateTime(today.year, today.month, 1);
        t = today;
        break;
      case DatePreset.lastMonth:
        final firstThisMonth = DateTime(today.year, today.month, 1);
        t = firstThisMonth.subtract(const Duration(days: 1));
        f = DateTime(t.year, t.month, 1);
        break;
      case DatePreset.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2022),
          lastDate: DateTime(2035),
          initialDateRange: (_from != null && _to != null)
              ? DateTimeRange(start: _from!, end: _to!)
              : DateTimeRange(start: today.subtract(const Duration(days: 7)), end: today),
        );
        if (picked == null) return;
        f = picked.start;
        t = picked.end;
        break;
    }

    setState(() {
      _preset = p;
      _from = f;
      _to = t;
    });
    widget.onChanged(f != null ? _fmt(f) : null, t != null ? _fmt(t) : null);
  }

  @override
  Widget build(BuildContext context) {
    final chips = <(DatePreset, String)>[
      (DatePreset.allTime, 'All Time'),
      (DatePreset.today, 'Today'),
      (DatePreset.yesterday, 'Yesterday'),
      (DatePreset.last7Days, 'Last 7 Days'),
      (DatePreset.thisMonth, 'This Month'),
      (DatePreset.lastMonth, 'Last Month'),
      (
        DatePreset.custom,
        _preset == DatePreset.custom && _from != null && _to != null
            ? '${_fmt(_from!)} → ${_fmt(_to!)}'
            : 'Custom Range'
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF475569)),
          const SizedBox(width: 6),
          ...chips.map((entry) {
            final isSelected = _preset == entry.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                selected: isSelected,
                label: Text(
                  entry.$2,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                  ),
                ),
                selectedColor: const Color(0xFFDBEAFE),
                backgroundColor: Colors.white,
                side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                onSelected: (_) => _selectPreset(entry.$1),
              ),
            );
          }),
        ],
      ),
    );
  }
}

