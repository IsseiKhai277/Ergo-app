import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/job_post.dart';
import '../../services/job_service.dart';
import '../../theme/app_theme.dart';
import 'job_details_screen.dart';

class JobCalendarScreen extends StatefulWidget {
  final String viewMode;

  const JobCalendarScreen({super.key, required this.viewMode});

  @override
  State<JobCalendarScreen> createState() => _JobCalendarScreenState();
}

class _JobCalendarScreenState extends State<JobCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  Color get _themeColor => widget.viewMode == 'client' ? const Color(0xFF6B4EFF) : AppColors.primary;
  Color get _accentColor => widget.viewMode == 'client' ? const Color(0xFFF3E8FF) : AppColors.accentLight;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  List<DateTime> _generateCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInM = DateTime(month.year, month.month + 1, 0).day;
    int startOffset = firstDayOfMonth.weekday - 1;
    final List<DateTime> days = [];

    // Previous month padding
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final daysInPrevM = DateTime(month.year, month.month, 0).day;
    for (int i = startOffset - 1; i >= 0; i--) {
      days.add(DateTime(prevMonth.year, prevMonth.month, daysInPrevM - i));
    }

    // Current month
    for (int i = 1; i <= daysInM; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    // Next month padding
    int remaining = 42 - days.length;
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    for (int i = 1; i <= remaining; i++) {
      days.add(DateTime(nextMonth.year, nextMonth.month, i));
    }

    return days;
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobsStream = widget.viewMode == 'client'
        ? JobService.myPostedJobsStream
        : JobService.myWorkerJobsStream;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Job Calendar',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: StreamBuilder<List<JobPost>>(
        stream: jobsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final allJobs = snapshot.data ?? [];
          
          // Filter jobs: status must be accepted, active, arrived, active_arrived, or completed.
          // And scheduledAt must be non-null.
          final acceptedJobs = allJobs.where((j) {
            final s = j.status.toLowerCase();
            return (s == 'accepted' ||
                    s == 'active' ||
                    s == 'arrived' ||
                    s == 'active_arrived' ||
                    s == 'completed') &&
                j.scheduledAt != null;
          }).toList();

          // Group by date
          final Map<DateTime, List<JobPost>> jobDates = {};
          for (final job in acceptedJobs) {
            final dateKey = DateTime(job.scheduledAt!.year, job.scheduledAt!.month, job.scheduledAt!.day);
            if (!jobDates.containsKey(dateKey)) {
              jobDates[dateKey] = [];
            }
            jobDates[dateKey]!.add(job);
          }

          final calendarDays = _generateCalendarDays(_focusedMonth);
          final selectedDateKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
          final selectedDayJobs = jobDates[selectedDateKey] ?? [];
          // Sort daily jobs chronologically
          selectedDayJobs.sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

          // Count jobs this month
          int jobsThisMonthCount = acceptedJobs.where((j) => j.scheduledAt!.month == _focusedMonth.month && j.scheduledAt!.year == _focusedMonth.year).length;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Calendar Panel
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              // Calendar Header (Month navigation)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                                    onPressed: _prevMonth,
                                  ),
                                  Text(
                                    DateFormat('MMMM yyyy').format(_focusedMonth),
                                    style: GoogleFonts.manrope(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                                    onPressed: _nextMonth,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Days of Week Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                                  return SizedBox(
                                    width: 36,
                                    child: Center(
                                      child: Text(
                                        day,
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              // Calendar Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: 42,
                                itemBuilder: (context, index) {
                                  final day = calendarDays[index];
                                  final isCurrentMonth = day.month == _focusedMonth.month;
                                  final isSelected = day.year == _selectedDay.year &&
                                      day.month == _selectedDay.month &&
                                      day.day == _selectedDay.day;
                                  final dateKey = DateTime(day.year, day.month, day.day);
                                  final hasJobs = jobDates.containsKey(dateKey);

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDay = day;
                                        // If user tapped a padded day from prev/next month, update focused month
                                        if (day.month != _focusedMonth.month) {
                                          _focusedMonth = DateTime(day.year, day.month, 1);
                                        }
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? _themeColor : Colors.transparent,
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: _themeColor.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            '${day.day}',
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: isSelected || hasJobs ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isCurrentMonth
                                                      ? AppColors.textPrimary
                                                      : AppColors.textSecondary.withOpacity(0.4)),
                                            ),
                                          ),
                                          if (hasJobs && !isSelected)
                                            Positioned(
                                              bottom: 4,
                                              child: Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: _themeColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Stats Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Jobs This Month',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$jobsThisMonthCount',
                                    style: GoogleFonts.manrope(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _themeColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.bar_chart_rounded, color: _themeColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Schedule Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Schedule',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('MMMM d').format(_selectedDay),
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Schedule List
                        if (selectedDayJobs.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textHint),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No jobs scheduled for this day',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: selectedDayJobs.length,
                            itemBuilder: (context, idx) {
                              final job = selectedDayJobs[idx];
                              final isLast = idx == selectedDayJobs.length - 1;
                              
                              Color statusColor = _themeColor;
                              if (job.status == 'completed') {
                                statusColor = Colors.grey;
                              } else if (job.status == 'active' || job.status == 'arrived' || job.status == 'active_arrived') {
                                statusColor = const Color(0xFF10B981);
                              }

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Time Column
                                    Container(
                                      width: 60,
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            DateFormat('hh:mm').format(job.scheduledAt!),
                                            style: GoogleFonts.manrope(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('a').format(job.scheduledAt!),
                                            style: GoogleFonts.manrope(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Node line Column
                                    SizedBox(
                                      width: 24,
                                      child: Stack(
                                        alignment: Alignment.topCenter,
                                        children: [
                                          if (!isLast)
                                            Container(
                                              width: 2,
                                              color: AppColors.outline.withOpacity(0.2),
                                            ),
                                          Positioned(
                                            top: 16,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: statusColor,
                                                  width: 2.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Card details Column
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 20),
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => JobDetailsScreen(job: job),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: AppColors.outline.withOpacity(0.15)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.01),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                )
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        job.title,
                                                        style: GoogleFonts.manrope(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w700,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'RM ${job.price.toStringAsFixed(0)}',
                                                      style: GoogleFonts.manrope(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    _StatusBadge(status: job.status, roleColor: statusColor),
                                                    const SizedBox(width: 8),
                                                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                                    const SizedBox(width: 2),
                                                    Expanded(
                                                      child: Text(
                                                        job.location,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (job.description.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    job.description,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color roleColor;

  const _StatusBadge({required this.status, required this.roleColor});

  @override
  Widget build(BuildContext context) {
    String label = status.toUpperCase();
    Color bg = roleColor.withOpacity(0.1);
    Color fg = roleColor;

    if (status == 'active' || status == 'arrived' || status == 'active_arrived') {
      label = 'ACTIVE';
      bg = const Color(0xFF10B981).withOpacity(0.1);
      fg = const Color(0xFF10B981);
    } else if (status == 'completed') {
      label = 'COMPLETED';
      bg = Colors.grey.withOpacity(0.1);
      fg = Colors.grey;
    } else if (status == 'accepted') {
      label = 'ACCEPTED';
      bg = roleColor.withOpacity(0.1);
      fg = roleColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
