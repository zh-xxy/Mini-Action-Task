import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../services/task_provider.dart';
import 'package:intl/intl.dart';

import 'wishlist_screen.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  static const List<String> _importanceOptions = ['主线', '支线', '副本', '习惯', '日常'];

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('数据统计')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('数据统计'),
            actions: [
              IconButton(
                icon: const Icon(Icons.card_giftcard),
                tooltip: '愿望清单',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()));
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('过去 7 天完成任务能量', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildEnergyLineChart(provider.recentLogs),
              const SizedBox(height: 32),

              const Text('过去 4 周完成任务数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildWeeklyTaskGroupedBarChart(provider.recentLogs, provider.allTasks),
              const SizedBox(height: 32),

              const Text('完成动作热力图', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildActionHeatmap(provider.recentLogs, weeks: 21),
              const SizedBox(height: 32),

              const Text('过去 7 天高效率时段', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildEfficiencyHourChart(provider.recentLogs),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnergyLineChart(List<LogEntry> logs) {
    final now = DateTime.now();
    List<FlSpot> spots = [];
    double maxY = 0;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      double dailyEnergy = 0;
      
      for (var log in logs) {
        if (log.action == 'done' && 
            log.createdAt.year == day.year && 
            log.createdAt.month == day.month && 
            log.createdAt.day == day.day) {
          dailyEnergy += log.energyValue;
        }
      }
      if (dailyEnergy > maxY) maxY = dailyEnergy;
      spots.add(FlSpot((6 - i).toDouble(), dailyEnergy));
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index > 6) return const SizedBox.shrink();
                  final date = now.subtract(Duration(days: 6 - index));
                  return Text(DateFormat('MM-dd').format(date), style: const TextStyle(fontSize: 10));
                },
              )
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minY: 0,
          maxY: maxY < 10 ? 10 : maxY + 5,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  int _logUnits(LogEntry log) {
    final match = RegExp(r'units=(\d+)').firstMatch(log.note);
    if (match == null) return 1;
    final parsed = int.tryParse(match.group(1) ?? '');
    if (parsed == null || parsed < 1) return 1;
    return parsed;
  }

  Widget _buildWeeklyTaskGroupedBarChart(List<LogEntry> logs, List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = _weekStartSunday(today);
    final weekStarts = List<DateTime>.generate(4, (index) => currentWeekStart.subtract(Duration(days: (3 - index) * 7)));
    final weekKeys = weekStarts.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    final weeklyCounts = <String, Map<String, int>>{
      for (final key in weekKeys) key: {for (final option in _importanceOptions) option: 0}
    };
    final importanceByTaskId = <String, String>{for (final task in tasks) task.id: task.importance};

    for (final log in logs) {
      if (log.action.toLowerCase() != 'done') continue;
      final dt = log.createdAt.toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      final weekStart = _weekStartSunday(day);
      final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
      if (!weeklyCounts.containsKey(weekKey)) continue;
      final importance = importanceByTaskId[log.taskId];
      if (importance == null || !_importanceOptions.contains(importance)) continue;
      weeklyCounts[weekKey]![importance] = (weeklyCounts[weekKey]![importance] ?? 0) + 1;
    }

    final barGroups = <BarChartGroupData>[];
    double maxY = 1;
    for (int i = 0; i < weekStarts.length; i++) {
      final weekKey = weekKeys[i];
      final rods = <BarChartRodData>[];
      for (int j = 0; j < _importanceOptions.length; j++) {
        final importance = _importanceOptions[j];
        final count = (weeklyCounts[weekKey]![importance] ?? 0).toDouble();
        if (count > maxY) maxY = count;
        rods.add(BarChartRodData(
          toY: count,
          width: 7,
          borderRadius: BorderRadius.circular(2),
          color: _importanceBarColor(importance),
        ));
      }
      barGroups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 3));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY < 4 ? 4 : maxY + 1,
              barGroups: barGroups,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= weekStarts.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_formatYearWeek(weekStarts[index]), style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: _importanceOptions
              .map(
                (importance) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: _importanceBarColor(importance)),
                    const SizedBox(width: 4),
                    Text(importance, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  DateTime _weekStartSunday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final offset = d.weekday % 7;
    return d.subtract(Duration(days: offset));
  }

  String _formatYearWeek(DateTime date) {
    final year = date.year;
    final week = _weekNumberSundayFirst(date);
    return '$year${week.toString().padLeft(2, '0')}';
  }

  int _weekNumberSundayFirst(DateTime date) {
    final weekStart = _weekStartSunday(date);
    final jan1 = DateTime(date.year, 1, 1);
    final firstWeekStart = _weekStartSunday(jan1);
    return weekStart.difference(firstWeekStart).inDays ~/ 7 + 1;
  }

  Color _importanceBarColor(String importance) {
    switch (importance) {
      case '主线':
        return Colors.red.shade400;
      case '支线':
        return Colors.orange.shade400;
      case '副本':
        return Colors.blue.shade400;
      case '习惯':
        return Colors.green.shade400;
      case '日常':
      default:
        return Colors.grey.shade500;
    }
  }

  Widget _buildEfficiencyHourChart(List<LogEntry> logs) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    
    final eventTimes = <DateTime>[];
    final countByHour = List<int>.filled(24, 0);
    for (final log in logs) {
      final action = log.action.toLowerCase();
      if (action != 'done' && action != 'advance') continue;
      final dt = log.createdAt.toLocal();
      if (dt.isBefore(cutoff)) continue;
      final units = _logUnits(log);
      countByHour[dt.hour] += units;
      eventTimes.add(dt);
    }
    eventTimes.sort();
    final densityByHour = List<double>.filled(24, 0);
    DateTime? prev;
    for (final t in eventTimes) {
      final hour = t.hour;
      if (prev != null) {
        final gap = t.difference(prev).inMinutes.abs();
        if (gap <= 45) {
          densityByHour[hour] += (46 - gap) / 46;
        }
      }
      prev = t;
    }
    final bars = <BarChartGroupData>[];
    final densitySpots = <FlSpot>[];
    final ranked = <Map<String, dynamic>>[];
    
    double maxCount = 1;
    double maxDensity = 1;
    for (int h = 0; h < 24; h++) {
      if (countByHour[h] > maxCount) maxCount = countByHour[h].toDouble();
      if (densityByHour[h] > maxDensity) maxDensity = densityByHour[h];
      
      bars.add(BarChartGroupData(x: h, barRods: [BarChartRodData(toY: countByHour[h].toDouble(), color: Colors.indigo.shade300, width: 6)]));
      ranked.add({'hour': h, 'score': countByHour[h] + densityByHour[h] * 2});
    }

    final displayMaxY = maxCount < 2 ? 2.0 : maxCount + 1;
    for (int h = 0; h < 24; h++) {
      final mappedY = maxDensity <= 0 ? 0.0 : (densityByHour[h] / maxDensity) * displayMaxY;
      densitySpots.add(FlSpot(h.toDouble(), mappedY));
    }

    ranked.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final topHours = ranked.where((e) => (e['score'] as double) > 0).take(3).map((e) => e['hour'] as int).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200, 
          child: Stack(
            children: [
              BarChart(
                BarChartData(
                  maxY: displayMaxY,
                  barGroups: bars, 
                  borderData: FlBorderData(show: false), 
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final h = value.toInt();
                          if (h % 3 != 0) return const SizedBox.shrink();
                          return Text('${h}h', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  )
                )
              ),
              IgnorePointer(
                child: LineChart(
                  LineChartData(
                    minX: 0, maxX: 23, minY: 0, maxY: displayMaxY,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: densitySpots,
                        isCurved: true,
                        color: Colors.deepOrange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.bar_chart, size: 14, color: Colors.indigo),
            SizedBox(width: 4),
            Text('完成数量', style: TextStyle(fontSize: 12)),
            SizedBox(width: 12),
            Icon(Icons.show_chart, size: 14, color: Colors.deepOrange),
            SizedBox(width: 4),
            Text('心流密度', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Text(topHours.isEmpty ? '高效率时段：暂无足够记录' : '预计高产时段：${topHours.map((h) => '$h时').join('、')}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _buildActionHeatmap(List<LogEntry> logs, {int weeks = 21}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: 6 - (today.weekday - 1)));
    final start = end.subtract(Duration(days: weeks * 7 - 1));

    final countsByDay = <String, int>{};
    for (final log in logs) {
      final action = log.action.toLowerCase();
      if (action != 'done' && action != 'advance') continue;
      final dt = log.createdAt.toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final key = DateFormat('yyyy-MM-dd').format(day);
      countsByDay[key] = (countsByDay[key] ?? 0) + _logUnits(log);
    }

    int maxCount = countsByDay.values.isEmpty ? 1 : countsByDay.values.reduce((a, b) => a > b ? a : b);

    final columns = <Widget>[];
    DateTime cursor = start;
    for (int w = 0; w < weeks; w++) {
      final cells = <Widget>[];
      for (int d = 0; d < 7; d++) {
        final cellDate = cursor;
        final key = DateFormat('yyyy-MM-dd').format(cellDate);
        final count = countsByDay[key] ?? 0;
        cells.add(
          GestureDetector(
            onTap: () {
              final dateText = DateFormat('yyyy-MM-dd').format(cellDate);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$dateText：完成 $count 个动作'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _heatColor(count, maxCount),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      columns.add(Column(children: cells));
    }

    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: columns));
  }

  Color _heatColor(int count, int maxCount) {
    if (count <= 0) return Colors.grey.shade200;
    final ratio = count / maxCount;
    if (ratio <= 0.3) return Colors.green.shade100;
    if (ratio <= 0.6) return Colors.green.shade300;
    return Colors.green.shade600;
  }
}
