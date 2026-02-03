# Testing

## Run the tests

The project is an Xcode project (not a workspace). The expected command is:

```
xcodebuild test -project SportBoardApp.xcodeproj -scheme SportBoardApp -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

If your scheme or simulator name differs, update `-scheme` and `-destination` accordingly.

## Fixtures

Fixtures live in `SportBoardAppTests/Fixtures` as individual JSON files. The loader is centralized in `SportBoardAppTests/TestSupport/FixtureLoader.swift`.

Fixture format:

```json
{
  "activity": {
    "id": 123,
    "name": "Example",
    "sportType": "Run",
    "startDate": "2024-02-12T07:00:00Z",
    "distance": 8000,
    "movingTime": 2700,
    "elapsedTime": 2750,
    "totalElevationGain": 60,
    "averageSpeed": 2.96,
    "maxSpeed": 3.5,
    "averageHeartrate": 145,
    "maxHeartrate": 165,
    "hasHeartrate": true,
    "hasSplitsMetric": true,
    "hasLaps": false
  },
  "splits": [
    {
      "splitIndex": 0,
      "distance": 1000,
      "movingTime": 340,
      "elapsedTime": 340,
      "averageSpeed": 2.94,
      "averageHeartrate": 142,
      "elevationDifference": 3,
      "paceZone": 2
    }
  ],
  "laps": [
    {
      "lapIndex": 0,
      "name": "Warmup",
      "distance": 2000,
      "movingTime": 720,
      "elapsedTime": 720,
      "startIndex": 0,
      "endIndex": 2000,
      "averageSpeed": 2.78,
      "maxSpeed": 3.2,
      "averageHeartrate": 150,
      "totalElevationGain": 10
    }
  ]
}
```

Notes:
- `splits` and `laps` can be `null` if not applicable.
- `startDate` must be ISO-8601 (`YYYY-MM-DDThh:mm:ssZ`).

## Adding new tests

1. Add a new fixture JSON under `SportBoardAppTests/Fixtures` if needed.
2. Load it via `FixtureLoader.load(named:)` and build a model with `FixtureLoader.makeActivity(from:)`.
3. Use the in-memory SwiftData container helper (`InMemoryModelContainer.make()`) for tests that need persistence.
4. For date-sensitive tests, use `FixedDateProvider` and a Madrid calendar from `FixtureLoader.makeMadridCalendar()` to keep deterministic behavior across timezones and DST.
