# Mini Action Task

A Flutter-based task management application designed for offline use, focusing on energy management and task prioritization.

## Features

- **Task Management**: Create, view, and manage tasks with detailed attributes.
- **Energy Estimation**: Assign energy values (0.0 - 5.0) to tasks to better plan your day based on your current capacity.
- **Priority & Urgency**: Categorize tasks by importance (Mainline, Daily, Habit) and set priority levels.
- **Next Action Tracking**: Keep track of the immediate next step for every task.
- **Activity Logging**: Automatic logging of task creations and actions for progress tracking.
- **Offline First**: All data is stored locally on the device using a local database.

## Technical Details

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: Uses modern Flutter practices.
- **Database**: Local SQLite storage for persistence.
- **Identifiers**: UUIDs for robust data handling.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extension
- An Android/iOS emulator or physical device

### Installation

1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Run `flutter run` to start the application.

## Task Attributes

Each task in the system includes:
- **Importance**: Mainline (主线), Daily (日常), or Habit (习惯).
- **Energy Estimate**: How much "mana" or energy the task requires.
- **Low Energy OK**: Flag for tasks that can be done when tired.
- **Due Date**: Days remaining until the deadline.
- **Next Action**: The specific concrete step to move the task forward.
