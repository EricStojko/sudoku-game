# StojkoDoku 🧩

A modern, beautifully designed Sudoku game built using Flutter.

This project was built and designed with the help of **AI** (Google DeepMind's Antigravity assistant).

## Features

- **Dynamic Sudoku Generation**: Generates valid puzzles dynamically across three difficulty levels (Easy, Medium, and Hard).
- **Premium Pastel UI**: A beautiful, custom Material 3 aesthetic featuring soft pastel colors, clean typography, and elegant shadows.
- **Smart Highlighting**: Automatically highlights rows, columns, and matching numbers to assist your focus.
- **Assistance Tools**:
  - **Check**: Temporarily highlights incorrect numbers in red for 2 seconds.
  - **Hint**: Automatically fills the selected cell with its correct value.
- **Game Mechanics**: Keep track of your duration with a live timer and watch out for mistakes (limit of 3 mistakes before Game Over).
- **Leaderboards**: Persistent Top 10 rankings per difficulty using `shared_preferences` to track dates, times, and names.
- **Win Celebrations**: Dynamic confetti overlay when you successfully complete a puzzle!

## Getting Started

### Prerequisites

Make sure you have the Flutter SDK installed on your machine. See the [official Flutter installation guide](https://docs.flutter.dev/get-started/install) for details.

### Running the App

To run the application on Chrome (or your default emulator/device):

```bash
flutter run -d chrome
```

## AI Contribution

This game's logic (including the board generation, shuffling algorithm, state management, and M3 layout styling) was generated and refined in collaboration with an advanced AI coding assistant.
