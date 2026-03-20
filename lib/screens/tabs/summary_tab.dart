import 'package:flutter/material.dart';
import '../charts_screen.dart';

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the existing ChartsScreen content
    // ChartsScreen is a Scaffold, but inside a tab we might not want nested Scaffolds if we want to share the app bar or have none.
    // However, the prompt says "第3个tab叫汇总,也就是当前的图表页". 
    // Since ChartsScreen has its own AppBar, let's just wrap it or refactor it.
    // To avoid refactoring ChartsScreen too much, we can just return it. 
    // If ChartsScreen has a Scaffold, it will work but might look nested if MainScreen has an AppBar (which it doesn't currently for the body).
    return const ChartsScreen();
  }
}
