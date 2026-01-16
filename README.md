# JournalingAddon

A World of Warcraft addon for creating a personal journal of your adventures. Automatically tracks quests, kills, loot, XP gains, travel, and more, while also allowing manual entries for screenshots, target captures, and notes.

## Features

### Automatic Tracking
- **Quest Logging**: Automatically logs quest acceptance and completion
- **Combat Activity**: Tracks kills and XP gains, combining them into activity entries per combat session
- **Loot Tracking**: Logs items looted from mobs (with smart aggregation)
- **Travel Logging**: Tracks zone changes, flight paths, hearthstone usage, and boat/zeppelin travel
- **Reputation**: Monitors reputation gains and tier changes
- **Screenshots**: Automatically logs when you take screenshots with filename
- **Death Tracking**: Logs when you die
- **Crafting**: Tracks when items are crafted
- **Mail**: Logs received and sent mail with sender/recipient and items

### Manual Capture
- **Target Capture** (`/journal capture`): Document targets (NPCs, players, mobs) with screenshot and note
- **Scene Capture** (`/journal capture` without target): Take a screenshot with a note for documenting locations or moments
- **Note Entry** (`/journal note`): Add standalone multiline notes to your journal

### Session Management
- Sessions are automatically organized by character and day
- Sessions persist across reloads and relogs (same character + same day = same session)
- Character name visible in session labels
- Export sessions as plain text for easy sharing or backup

## Requirements

- World of Warcraft: The Burning Crusade Classic (2.5.5)
- Interface version: 20505

## Installation

1. Download or clone this repository
2. Copy the `JournalingAddon` folder to your WoW AddOns directory:
   - Windows: `World of Warcraft\_classic_\Interface\AddOns\`
   - macOS: `World of Warcraft/_classic_/Interface/AddOns/`
   - Linux: `World of Warcraft/_classic_/Interface/AddOns/`
3. Restart WoW or use `/reload` in-game
4. The addon should appear in your AddOns list

## Usage

### Opening the Journal
- Type `/journal` in chat to open/close the journal UI
- Use the dropdown to select different sessions
- Click "Export" to copy a session as text

### Commands
- `/journal` - Toggle the journal UI
- `/journal note` - Open dialog to add a standalone note
- `/journal capture` or `/journal capture-target` - Capture target (or scene) with screenshot and note
- `/journal debug` - Toggle debug logging

### Entry Types

The journal automatically creates entries for:
- **Accepted**: Quest acceptance with name and ID
- **Turned in**: Quest completion with name and ID
- **Killed**: Mob kills with XP gained (aggregated per combat session)
- **Gained XP**: Non-combat XP gains
- **Looted**: Items looted from mobs
- **Traveled to**: Zone changes with subzone information
- **Hearth to**: Hearthstone usage
- **Started flying to**: Flight path initiation
- **Landed in**: Flight path completion
- **Reputation**: Reputation gains and tier changes
- **Screenshot**: Automatic screenshot logging
- **Died**: Player death events
- **Crafted**: Items crafted
- **Received mail from**: Mail received with sender and items
- **Sent mail to**: Mail sent with recipient and items

Manual entries:
- **Spotted**: Target capture with level, reaction, race, class, note, and screenshot
- **Scene**: Screenshot with note (no target)
- **Note**: Standalone text note

## Data Storage

Journal data is stored in `SavedVariables/JournalDB.lua` in your WTF folder. This persists across game sessions and characters.

## Development

### Project Structure
```
JournalingAddon/
├── JournalingAddon.toc    # Addon manifest
├── Journal.lua            # Core logic and event handling
└── JournalUI.lua          # UI components and interaction
```

### Deployment
A `deploy.sh` script is included for macOS to sync the addon to the WoW AddOns directory. Modify the path in the script to match your installation.

## License

This project is licensed under a Non-Commercial License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## Author

asbjborg

## Version

Current version: 0.3.7

See [CHANGELOG.md](changes.md) for version history.
