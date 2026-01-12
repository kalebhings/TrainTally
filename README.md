# TrainTally 🚂

A mobile score-tracking app for Ticket to Ride board games with cloud-synced leaderboards and family group support.

![Platform](https://img.shields.io/badge/platform-iOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-Proprietary-red)


## Screenshots
<p align="center">
  <img src="docs/images/home-screen.PNG" width="200" alt="Home Screen">
  <img src="docs/images/setup-screen.PNG" width="200" alt="Setup Screen">
  <img src="docs/images/scoring-screen.PNG" width="200" alt="Scoring Screen">
  <img src="docs/images/game-summary.PNG" width="200" alt="Game Summary">
  <img src="docs/images/history-screen.PNG" width="200" alt="Game History">
</p>


## Project Status

| Component | Status |
|-----------|--------|
| iOS App - Core Scoring | ✅ Complete |
| iOS App - Game History | ✅ Complete |
| iOS App - Multi-version Support | ✅ Complete |
| Local Persistence (SwiftData) | ✅ Complete |
| AWS Backend Infrastructure | ✅ Deployed |
| iOS App - AWS Integration | ✅ Complete |
| Cloud Leaderboards UI | ✅ Complete |
| iOS App - Authentication Flow | ✅ Complete |
| iOS App - Cloud Sync | ✅ Complete |
| Family Groups Backend | ✅ Deployed |
| Family Groups iOS UI | 🚧 In Progress |
| Game Config Refactor | 🔧 Planned Refactor |
| Camera Auto-Scoring | 🔮 Future |
| Destination Ticket Database | 🔮 Future |

### AWS Infrastructure ✅

- **Cognito User Pool** — Authentication and user management
- **API Gateway** — RESTful API with JWT authorization
- **Lambda Functions** — 8 serverless functions (Python 3.12)
- **DynamoDB Tables** — Games, Groups, and Leaderboards
- **CloudWatch** — Monitoring and alarms
- **iOS SDK Integration** — Full authentication and sync implementation

**Backend Documentation:** See [`backend/README.md`](backend/README.md) for API documentation and deployment guide.

### iOS App - Cloud Features

- **User Authentication** — Sign up, sign in, password reset via Cognito
- **Cloud Sync** — Automatic and manual game syncing to AWS
- **Leaderboards** — View global and filtered leaderboards by game version
- **Settings UI** — Manage cloud sync, view account status, and local games
- **Sync Status Indicators** — Visual feedback for synced vs. local-only games

## Features

### Implemented ✅
- **Multi-version scoring** — Supports USA Base Game, Germany, Old West with version-specific rules
- **Dynamic UI** — Route buttons, bonuses, and features adapt based on selected game version
- **Train car tracking** — Visual progress bar with over-limit warnings
- **Destination tickets** — Add completed (+points) or failed (-points) tickets
- **Meeple scoring** — Germany expansion passenger scoring with majority bonuses
- **Game history** — Persistent local storage of all completed games
- **Player name memory** — Remembers frequently used player names
- **AWS Backend** — Serverless infrastructure deployed and operational
- **Cloud Sync** — Optional cloud syncing with automatic retry for failed submissions
- **Authentication** — Cognito-based user accounts (optional, works offline-first)
- **Leaderboards** — Global leaderboards with filtering by game version

### In Progress 🚧
- **Family/Friend Groups** — Private groups with invite codes (backend ready, iOS UI pending)

### Planned 📋
- **Game Config Refactor** — Split monolithic `game-versions.json` into multiple files for better maintainability
- **Additional Game Versions** — Expand support for more Ticket to Ride expansions
- **Camera Auto-Scoring** — Use device camera to automatically score routes
- **Destination Ticket Database** — Create comprehensive database of destination tickets for all versions
  - May require image scanning/OCR + LLM extraction to build dataset
  - Would enable smart destination ticket selection during route completion
- **Cross-device sync improvements** — Real-time sync across multiple devices
- **Android port** — Kotlin/Compose implementation

## Tech Stack

### iOS App
| Technology | Purpose |
|------------|---------|
| Swift 5.9 | Primary language |
| SwiftUI | Declarative UI framework |
| SwiftData | Local persistence |
| MVVM | Architecture pattern |
| AWS Amplify (soon) | AWS SDK for Swift |

### Backend (Deployed ✅)
| Technology | Purpose | Status |
|------------|---------|--------|
| AWS Cognito | User authentication | ✅ Live |
| AWS Lambda | Serverless functions (Python 3.12) | ✅ Live |
| AWS API Gateway | REST API with JWT auth | ✅ Live |
| AWS DynamoDB | NoSQL database (Games, Groups, Leaderboards) | ✅ Live |
| AWS SAM | Infrastructure as Code | ✅ Deployed |
| AWS CloudWatch | Monitoring and logs | ✅ Active |

**API Endpoints:** 8 endpoints for game submission, history, leaderboards, and groups  
**Cost:** $0/month (within AWS free tier)

## Repository Structure

```
TrainTally/
├── ios/                    # iOS app (Swift/SwiftUI)
│   └── TrainTally/
│       ├── App/            # App entry point
│       ├── Models/         # Data models (Player, GameSession, etc.)
│       ├── Views/          # SwiftUI views
│       ├── ViewModels/     # View models (planned)
│       ├── Services/       # Business logic services
│       └── Config/         # Game version JSON
├── backend/                # AWS Lambda functions (planned)
│   ├── functions/          # Individual Lambda handlers
│   └── shared/             # Shared utilities
├── config/                 # Shared configuration
│   └── game-versions.json  # Game rules definition
├── infrastructure/         # AWS SAM/CloudFormation (planned)
└── docs/                   # Documentation and images
```

## Supported Game Versions

Game-specific rules are defined in `config/game-versions.json`, making it easy to add new versions without code changes.

| Version | Route Lengths | Special Features |
|---------|---------------|------------------|
| USA (Base Game) | 1-6 | Longest Route bonus |
| Germany | 1-7 | Meeples, Globetrotter bonus |
| Old West | 1-7 | 40 train cars, 6 players |

### Adding New Versions

To add a new game version, add an entry to `config/game-versions.json`:

```json
{
    "id": "version_id",
    "displayName": "Display Name",
    "minPlayers": 2,
    "maxPlayers": 5,
    "trainCarsPerPlayer": 45,
    "stationsPerPlayer": null,
    "playerColors": ["colors_available"],
    "routeScoring": [
    {"length": 1, "points": 1},
    {"length": 2, "points": 2},
    {"length": 3, "points": 4},
    {"length": 4, "points": 7},
    {"length": 5, "points": 10},
    {"length": 6, "points": 15}
    ],
    "features": {
    "hasStations": false,
    "hasMeeples": false,
    "hasFerries": false,
    "hasShips": false
    },
    "bonuses": [
    {
        "id": "bonus_id",
        "displayName": "bonus_display_name",
        "points": 10,
        "description": "description of the bonus",
        "isExclusive": true,
        "isPerItem": false,
        "maxCount": null
    },
    ],
    "meepleConfig": null
}
```

## Getting Started

### Prerequisites
- macOS with Xcode 15+
- iOS 26.2+ simulator or device

### Running the iOS App

1. Clone the repository:
   ```bash
   git clone https://github.com/kalebhings/TrainTally.git
   cd TrainTally
   ```

2. Open the Xcode project:
   ```bash
   open ios/TrainTally.xcodeproj
   ```

3. Select a simulator (iPhone 17 Pro recommended) and press `Cmd + R` to build and run.

### Backend Setup (Coming Soon)

Backend infrastructure will use AWS SAM for deployment. Instructions will be added once implemented.

## Architecture

### iOS App Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      SwiftUI Views                       │
│  ContentView → GameSetupView → ScoringView → Summary    │
├─────────────────────────────────────────────────────────┤
│                    ViewModels (MVVM)                     │
│         Manages state and business logic                 │
├─────────────────────────────────────────────────────────┤
│                      Models                              │
│  GameSession (SwiftData) | Player | GameVersion         │
├─────────────────────────────────────────────────────────┤
│                     Services                             │
│  GameConfigLoader | PlayerNameManager | (AWS Service)   │
├─────────────────────────────────────────────────────────┤
│                    Data Layer                            │
│         SwiftData (Local) | AWS (Cloud - planned)       │
└─────────────────────────────────────────────────────────┘
```

### Planned Cloud Architecture

```
┌──────────────┐     HTTPS/JWT    ┌──────────────┐     Invoke    ┌──────────────┐
│   iOS App    │─────────────────▶│ API Gateway  │──────────────▶│   Lambda     │
│  (SwiftUI)   │                   │  (REST API)  │               │ (Python 3.12)│
└──────────────┘                   └──────────────┘               └──────┬───────┘
       │                                                                  │
       │ Authenticate                                                     │
       │                                                                  │
       ▼                                                                  ▼
┌──────────────┐                                                  ┌──────────────┐
│   Cognito    │                                                  │  DynamoDB    │
│  User Pool   │                                                  │   Tables     │
│              │                                                  │ • Games      │
│ • Optional   │                                                  │ • Groups     │
│ • JWT Auth   │                                                  │ • Leaderboards│
└──────────────┘                                                  └──────────────┘
                                                                         │
                                                                         │
                                                                         ▼
                                                                  ┌──────────────┐
                                                                  │ CloudWatch   │
                                                                  │ Logs/Metrics │
                                                                  └──────────────┘
```

## Scoring Logic

### Route Points
Points are awarded based on route length as defined in each game version's configuration.

### Destination Tickets
- Completed tickets: Add face value to score
- Failed tickets: Subtract face value from score

### Bonuses
- **Longest Route** (10 pts) — Awarded to player with longest continuous path
- **Globetrotter** (15 pts, Germany) — Most completed destination tickets

### Meeple Scoring (Germany)
- 1st place in a passenger color: 20 points
- 2nd place in a passenger color: 10 points

## Roadmap

- [x] Core scoring calculator
- [x] Multiple game version support
- [x] Local game history
- [x] Player name persistence
- [x] AWS backend infrastructure
- [x] User authentication (optional)
- [x] Cloud leaderboards
- [x] Cloud game sync with automatic retry
- [ ] Family group sharing UI (backend ready)
- [ ] Game config refactoring (split JSON files)
- [ ] Additional game version support
- [ ] Destination ticket database creation
- [ ] Camera-based auto-scoring
- [ ] Android port (Kotlin/Compose)

## Contributing

This is a portfolio project, but suggestions and feedback are welcome! Feel free to:
- Open issues for bugs or feature ideas
- Submit PRs for game version configs
- Suggest UI/UX improvements

## License

This project is proprietary software. You may view the source code for educational purposes, but commercial use is prohibited. See the [LICENSE](LICENSE) file for details.

---

**Note:** This app is a scoring utility and is not affiliated with Days of Wonder or the Ticket to Ride trademark.
