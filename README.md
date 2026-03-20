# Mini Action Task

[中文文档](./README.zh-CN.md)

Mini Action Task is an offline-first Flutter app that helps you move work forward with small, actionable steps.  
It combines task decomposition, energy-aware scheduling, and progress visualization into one lightweight workflow.

## Why This App

- Reduce task-start friction with clear next actions.
- Keep momentum even on low-energy days.
- Balance long-term goals and daily execution.
- Review your progress with simple visual analytics.

## Core Features

- **Task Lifecycle Management**: Organize tasks across selectable, in-progress, completed, frozen, and deleted states.
- **Next-Action Decomposition**: Add multiple actionable next steps, one per line, to break complex work into executable units.
- **Energy-Aware Planning**: Assign energy scores (0.0-5.0) and mark low-energy-friendly tasks for better daily matching.
- **Smart Recommendation Card**: Get suggested tasks based on current context and recent task energy signals.
- **Auto Freeze Protection**: Automatically freeze long-unfinished tasks to reduce backlog pressure.
- **Activity Logging**: Track actions and updates for better personal review and continuity.
- **Stats & Trends**: View completion trends and action heatmaps to understand execution rhythm.
- **Personal Utilities**: Configure profile details, reminders, and data backup/import-export workflows.
- **Offline First**: Store data locally on-device for reliable use without network dependency.

## Task Model

Each task can include:

- **Importance**: Mainline, Daily, Habit
- **Priority Level**: Relative urgency/importance for execution order
- **Energy Estimate**: Required energy level for completion
- **Low Energy OK**: Whether the task is suitable for low-capacity moments
- **Due Window**: Remaining days before due date
- **Next Actions**: Concrete executable steps that move the task forward

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Persistence**: Local SQLite database
- **Identifier Strategy**: UUID-based IDs
- **Architecture**: Layered Flutter app with models, services, screens, and widgets

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio or VS Code with Flutter/Dart plugins
- Android/iOS emulator or physical device

### Run Locally

1. Clone this repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Launch the app:
   ```bash
   flutter run
   ```

## Suitable For

- People who want to start tasks faster instead of over-planning.
- Builders who prefer converting goals into concrete action lists.
- Anyone improving personal execution with lightweight, offline tracking.
