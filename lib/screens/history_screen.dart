import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/screens/export_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _selectedJobId;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have a job filter from arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('jobId')) {
      final jobId = args['jobId'] as String;
      // Set the filter to show only entries for this job
      setState(() {
        _selectedJobId = jobId;
      });
    }
  }

  Future<void> _selectDateRange(
    BuildContext context,
    TimeEntriesProvider provider,
  ) async {
    HapticFeedback.selectionClick();

    final initialDateRange = DateTimeRange(start: _startDate, end: _endDate);

    final pickedDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: provider.locale,
    );

    if (pickedDateRange != null) {
      setState(() {
        _startDate = pickedDateRange.start;
        _endDate = pickedDateRange.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 7));
      _endDate = DateTime.now();
      _selectedJobId = null;
    });
  }

  // Navigate to export screen with current filters
  void _navigateToExport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ExportScreen(
              startDate: _startDate,
              endDate: _endDate,
              jobId: _selectedJobId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final jobsProvider = Provider.of<JobsProvider>(context);
    List<TimeEntry> entries = timeEntriesProvider.timeEntries;

    // Filter entries by date range and job
    entries =
        entries.where((entry) {
          return entry.clockInTime.isAfter(_startDate) &&
              entry.clockInTime.isBefore(_endDate.add(const Duration(days: 1)));
        }).toList();

    // Apply job filter if selected
    if (_selectedJobId != null && _selectedJobId != 'all') {
      entries =
          entries.where((entry) => entry.jobId == _selectedJobId).toList();
    }

    // Sort entries by date (newest first)
    entries.sort((a, b) => b.clockInTime.compareTo(a.clockInTime));

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate total hours for the filtered entries
    int totalFilteredMinutes = 0;
    for (var entry in entries) {
      totalFilteredMinutes += entry.duration.inMinutes;
    }
    final totalFilteredHours = totalFilteredMinutes ~/ 60;
    final totalFilteredRemainingMinutes = totalFilteredMinutes % 60;

    // Group entries by date
    final Map<String, List<TimeEntry>> entriesByDate = {};
    for (var entry in entries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.clockInTime);
      if (!entriesByDate.containsKey(dateStr)) {
        entriesByDate[dateStr] = [];
      }
      entriesByDate[dateStr]!.add(entry);
    }

    // Sort dates in descending order (newest first)
    final sortedDates =
        entriesByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    // Format date range for display
    String dateRangeText = timeEntriesProvider.translate('allDates');
    if (_startDate != DateTime.now().subtract(const Duration(days: 7)) ||
        _endDate != DateTime.now()) {
      final startFormatted = DateFormat('MMM d, yyyy').format(_startDate);
      final endFormatted = DateFormat('MMM d, yyyy').format(_endDate);
      dateRangeText = '$startFormatted - $endFormatted';
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title section with export button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeEntriesProvider.translate('history'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Export button
                    if (_startDate !=
                            DateTime.now().subtract(const Duration(days: 7)) ||
                        _selectedJobId != null)
                      IconButton(
                        icon: const Icon(Icons.file_present_outlined),
                        onPressed: () => _navigateToExport(context),
                      ),
                  ],
                ),
              ),

              // Date range selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date range button
                    InkWell(
                      onTap:
                          () => _selectDateRange(context, timeEntriesProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateRangeText,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Job filter section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          timeEntriesProvider.translate('filterByJob'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        // Total hours display
                        Text(
                          '$totalFilteredHours ${timeEntriesProvider.translate('klst')} $totalFilteredRemainingMinutes ${timeEntriesProvider.translate('mín')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Job selection - exactly like home page
                    _buildJobFilter(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Entries list
              Expanded(
                child:
                    entriesByDate.isEmpty
                        ? Center(
                          child: Text(
                            timeEntriesProvider.translate('noEntries'),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                        : ListView.builder(
                          itemCount: sortedDates.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final date = sortedDates[index];
                            final dateEntries = entriesByDate[date]!;

                            // Calculate total hours for this date
                            int totalMinutes = 0;
                            for (var entry in dateEntries) {
                              totalMinutes += entry.duration.inMinutes;
                            }
                            final totalHours = totalMinutes ~/ 60;
                            final remainingMinutes = totalMinutes % 60;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date header with total hours
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeEntriesProvider.formatDate(
                                        DateTime.parse(date),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '$totalHours ${timeEntriesProvider.translate('klst')} $remainingMinutes ${timeEntriesProvider.translate('mín')}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Time entries for this date - same card design as home page
                                ...dateEntries.map((entry) {
                                  return Dismissible(
                                    key: Key(entry.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder:
                                            (context) => Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  20.0,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.red,
                                                      size: 48,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      timeEntriesProvider
                                                          .translate(
                                                            'deleteEntry',
                                                          ),
                                                      style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      timeEntriesProvider
                                                          .translate(
                                                            'deleteEntryConfirm',
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceEvenly,
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      false,
                                                                    ),
                                                            style: OutlinedButton.styleFrom(
                                                              side: BorderSide(
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade300,
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              timeEntriesProvider
                                                                  .translate(
                                                                    'cancel',
                                                                  ),
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .grey[700],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(true),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              timeEntriesProvider
                                                                  .translate(
                                                                    'delete',
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      timeEntriesProvider.deleteTimeEntry(
                                        entry.id,
                                      );
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Job name and duration
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        color: entry.jobColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      entry.jobName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Time range
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${timeEntriesProvider.formatTime(entry.clockInTime)} - ${timeEntriesProvider.formatTime(entry.clockOutTime)}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Description if available
                                            if (entry.description != null &&
                                                entry.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: Text(
                                                  entry.description!,
                                                  style: TextStyle(
                                                    color:
                                                        isDarkMode
                                                            ? Colors
                                                                .grey
                                                                .shade500
                                                            : Colors
                                                                .grey
                                                                .shade700,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),

                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSelectButton(String text, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
          highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Period button widget that exactly matches the home page style
  Widget _buildPeriodButton(String text, bool isSelected, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? color.withOpacity(0.2)
                  : isDarkMode
                  ? Colors.grey.shade900
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                isSelected
                    ? color
                    : isDarkMode
                    ? Colors.grey.shade100
                    : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Job filter widget
  Widget _buildJobFilter() {
    final jobsProvider = Provider.of<JobsProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildJobFilterButton(
            timeEntriesProvider.translate('allJobs'),
            null,
            _selectedJobId == null,
          ),
          ...jobsProvider.jobs.map((job) {
            return _buildJobFilterButton(
              job.name,
              job.id,
              _selectedJobId == job.id,
              job.color,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJobFilterButton(
    String text,
    String? jobId,
    bool isSelected, [
    Color? jobColor,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedJobId = jobId;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (jobColor?.withOpacity(0.2) ??
                        Theme.of(context).primaryColor.withOpacity(0.1))
                    : Colors.grey.shade100,
            border: Border.all(
              color:
                  isSelected
                      ? (jobColor ?? Theme.of(context).primaryColor)
                      : Colors.grey.shade300,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (jobColor != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: jobColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color:
                      isSelected
                          ? (jobColor ?? Theme.of(context).primaryColor)
                          : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
