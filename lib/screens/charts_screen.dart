import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/task.dart';
import '../models/log_entry.dart';
import '../services/db_service.dart';
import 'package:intl/intl.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final DBService _dbService = DBService();
  
  List<LogEntry> _logs = [];
  List<Task> _tasks = [];
  bool _isLoading = true;
  static const List<String> _importanceOptions = ['日常', '习惯', '支线', '副本', '主线'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await _dbService.getAllLogs();
    final tasks = await _dbService.getAllTasks();
    setState(() {
      _logs = logs;
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Widget _buildEnergyLineChart() {
    final now = DateTime.now();
    List<FlSpot> spots = [];
    double maxY = 0;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      double dailyEnergy = 0;
      
      for (var log in _logs) {
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
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = now.subtract(Duration(days: 6 - value.toInt()));
                  return Text(DateFormat('MM-dd').format(date), style: const TextStyle(fontSize: 10));
                },
              )
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: maxY < 10 ? 10 : maxY + 5,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBarChart() {
    final now = DateTime.now();
    List<BarChartGroupData> barGroups = [];
    final energyByWeek = <double>[];
    final lineSpots = <FlSpot>[];
    double maxY = 0;
    double maxEnergy = 0;
    const barOrder = ['主线', '支线', '副本', '习惯', '日常'];
    final colors = <String, Color>{
      '主线': Colors.red,
      '支线': Colors.orange,
      '副本': Colors.purple,
      '习惯': Colors.green,
      '日常': Colors.blue,
    };

    final importanceByTaskId = <String, String>{for (final t in _tasks) t.id: t.importance};

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i * 7) + 7));
      final weekEnd = now.subtract(Duration(days: i * 7));

      final counts = <String, int>{for (final k in barOrder) k: 0};
      double weekEnergy = 0;
      for (var log in _logs) {
        if (log.action != 'done') continue;
        if (log.createdAt.isBefore(weekStart)) continue;
        if (!log.createdAt.isBefore(weekEnd)) continue;
        weekEnergy += log.energyValue;
        final importance = importanceByTaskId[log.taskId];
        if (importance != null && counts.containsKey(importance)) {
          counts[importance] = (counts[importance] ?? 0) + 1;
        }
      }
      energyByWeek.add(weekEnergy);
      if (weekEnergy > maxEnergy) maxEnergy = weekEnergy;
      for (final k in barOrder) {
        final v = (counts[k] ?? 0).toDouble();
        if (v > maxY) maxY = v;
      }

      barGroups.add(BarChartGroupData(
        x: 3 - i,
        barsSpace: 6,
        barRods: barOrder.map((k) {
          return BarChartRodData(
            toY: (counts[k] ?? 0).toDouble(),
            color: colors[k] ?? Colors.grey,
            width: 8,
            borderRadius: BorderRadius.circular(2),
          );
        }).toList(),
      ));
    }
    final displayMaxY = maxY < 3 ? 3.0 : maxY + 1;
    for (int i = 0; i < energyByWeek.length; i++) {
      final weekEnergy = energyByWeek[i];
      final mappedY = maxEnergy <= 0 ? 0.0 : (weekEnergy / maxEnergy) * displayMaxY;
      lineSpots.add(FlSpot(i.toDouble(), mappedY));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index > 3) return const SizedBox.shrink();
                          final weekStart = now.subtract(Duration(days: ((3 - index) * 7) + 7));
                          return Text(_formatYearWeek(weekStart), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  maxY: displayMaxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        const order = ['主线', '支线', '副本', '习惯', '日常'];
                        final label = order[rodIndex];
                        return BarTooltipItem('$label: ${rod.toY.toInt()}', const TextStyle(color: Colors.white));
                      },
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 3,
                    minY: 0,
                    maxY: displayMaxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: lineSpots,
                        isCurved: true,
                        color: Colors.black87,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(radius: 2.8, color: Colors.black87, strokeWidth: 0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ...barOrder.map((k) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: colors[k] ?? Colors.grey),
                  const SizedBox(width: 6),
                  Text(k, style: const TextStyle(fontSize: 12)),
                ],
              );
            }),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.show_chart, size: 14, color: Colors.black87),
                SizedBox(width: 6),
                Text('每周总完成能量', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEfficiencyHourChart() {
    final doneTimes = <DateTime>[];
    for (final task in _tasks) {
      if (task.status == 'deleted') continue;
      for (final item in task.actionHistory) {
        final endedAt = item['endedAt']?.toString();
        if (endedAt == null || endedAt.isEmpty) continue;
        final dt = DateTime.tryParse(endedAt);
        if (dt == null) continue;
        doneTimes.add(dt.toLocal());
      }
    }
    doneTimes.sort();
    final countByHour = List<int>.filled(24, 0);
    final densityByHour = List<double>.filled(24, 0);
    DateTime? prev;
    for (final t in doneTimes) {
      final hour = t.hour;
      countByHour[hour] += 1;
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
    double maxCount = 1;
    double maxDensity = 1;
    for (int h = 0; h < 24; h++) {
      final count = countByHour[h].toDouble();
      final density = densityByHour[h];
      if (count > maxCount) maxCount = count;
      if (density > maxDensity) maxDensity = density;
      bars.add(
        BarChartGroupData(
          x: h,
          barRods: [
            BarChartRodData(
              toY: count,
              color: Colors.indigo.shade300,
              width: 7,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }
    final displayMaxY = maxCount < 2 ? 2.0 : maxCount + 1;
    for (int h = 0; h < 24; h++) {
      final mappedY = maxDensity <= 0 ? 0.0 : (densityByHour[h] / maxDensity) * displayMaxY;
      densitySpots.add(FlSpot(h.toDouble(), mappedY));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              BarChart(
                BarChartData(
                  minY: 0,
                  maxY: displayMaxY,
                  barGroups: bars,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, horizontalInterval: 1, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final h = value.toInt();
                          if (h % 3 != 0) return const SizedBox.shrink();
                          return Text('${h.toString().padLeft(2, '0')}时', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 23,
                    minY: 0,
                    maxY: displayMaxY,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
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
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.bar_chart, size: 14, color: Colors.indigo),
            SizedBox(width: 6),
            Text('动作完成数量', style: TextStyle(fontSize: 12)),
            SizedBox(width: 14),
            Icon(Icons.show_chart, size: 14, color: Colors.deepOrange),
            SizedBox(width: 6),
            Text('连续完成密度', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Color _heatColor(int count, int maxCount) {
    if (count <= 0) return Colors.grey.shade200;
    final ratio = maxCount <= 0 ? 1.0 : (count / maxCount);
    if (ratio <= 0.25) return Colors.green.shade200;
    if (ratio <= 0.5) return Colors.green.shade400;
    if (ratio <= 0.75) return Colors.green.shade600;
    return Colors.green.shade800;
  }

  String _formatYearWeek(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final thursday = target.add(Duration(days: 4 - target.weekday));
    final weekYear = thursday.year;
    final firstThursday = DateTime(weekYear, 1, 4);
    final firstWeekMonday = firstThursday.subtract(Duration(days: firstThursday.weekday - 1));
    final currentWeekMonday = thursday.subtract(Duration(days: thursday.weekday - 1));
    final week = (currentWeekMonday.difference(firstWeekMonday).inDays ~/ 7) + 1;
    return '${weekYear}${week.toString().padLeft(2, '0')}';
  }

  Widget _buildActionHeatmap({int weeks = 20}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekdayIndex = today.weekday - DateTime.monday;
    final end = today.add(Duration(days: 6 - weekdayIndex));
    final start = end.subtract(Duration(days: weeks * 7 - 1));

    final countsByDay = <String, int>{};
    for (final t in _tasks) {
      if (t.status == 'deleted') continue;
      for (final item in t.actionHistory) {
        final endedAt = item['endedAt'];
        if (endedAt == null) continue;
        final dt = DateTime.tryParse(endedAt.toString());
        if (dt == null) continue;
        final local = dt.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        if (day.isBefore(start) || day.isAfter(end)) continue;
        final key = DateFormat('yyyy-MM-dd').format(day);
        countsByDay[key] = (countsByDay[key] ?? 0) + 1;
      }
    }

    int maxCount = 0;
    for (final v in countsByDay.values) {
      if (v > maxCount) maxCount = v;
    }

    final columns = <Widget>[];
    DateTime cursor = start;
    for (int w = 0; w < weeks; w++) {
      final cells = <Widget>[];
      for (int d = 0; d < 7; d++) {
        final key = DateFormat('yyyy-MM-dd').format(cursor);
        final count = countsByDay[key] ?? 0;
        cells.add(
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$key 完成动作 $count 个'),
                  duration: const Duration(milliseconds: 1300),
                ),
              );
            },
            child: Tooltip(
              message: '$key：完成动作 $count 个',
              child: Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: _heatColor(count, maxCount),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      columns.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: cells,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: columns),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('少', style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(width: 8),
            ...[0.0, 0.25, 0.5, 0.75, 1.0].map((r) {
              final c = maxCount == 0 ? 0 : (maxCount * r).round();
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: _heatColor(c, maxCount),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
            const SizedBox(width: 6),
            const Text('多', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据统计')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('过去 7 天完成任务能量', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildEnergyLineChart(),
              const SizedBox(height: 32),

              const Text('过去 4 周完成任务数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildWeeklyBarChart(),
              const SizedBox(height: 32),

              const Text('完成动作热力图', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildActionHeatmap(),
              const SizedBox(height: 32),

              const Text('高效率时段（完成时间与密度）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildEfficiencyHourChart(),
              const SizedBox(height: 32),
            ],
          ),
    );
  }
}
