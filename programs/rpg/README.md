# The Quest of UCVM Realm - ASCII RPG

## Overview
A conversational ASCII role-playing game running on the UCVM distributed system. Navigate through villages, forests, and dungeons while battling monsters and collecting treasure.

## System Requirements
- UCVM system with at least 1 active node
- 16KB free memory
- USER ring execution privileges
- Terminal with ASCII character support

## Installation
```bash
# Copy the game to your UCVM system
$ cp rpg.sh /usr/local/games/
$ chmod +x /usr/local/games/rpg.sh
```

## How to Play

### Starting the Game
```bash
$ ./rpg.sh
```

### Controls
- **w/a/s/d** - Move up/left/down/right
- **i** - Open inventory
- **t** - Talk to NPCs (when adjacent)
- **q** - Quit game
- **space** - Interact/confirm

### Game World

#### Village (Starting Area)
```
#########
#..INN..#  - Rest and save
#..SHOP.#  - Buy equipment
#...T...#  - Talk to villagers (T)
```

#### Forest
```
T T T T T  - Trees (T)
  ^^^      - Mountains (^)
       >   - Exit to next area
```

#### Dungeon
```
#########
#.......#  - Walls (#)
#...X...#  - Boss location (X)
#<......#  - Exit (<)
```

### Combat System
- Random encounters occur while exploring
- Turn-based battle system
- Attack, defend, use items, or flee
- Defeat enemies to gain gold and experience

### Character Stats
- **HP**: Health Points (start with 20)
- **Gold**: Currency for shops
- **Location**: Current map area

## Technical Details

### Memory Layout
- Stack: 0xE000-0xF000 (4KB)
- Code: 0x1000-0x3000 (8KB)
- Data: 0x3000-0x4000 (4KB)
- Total: 16KB footprint

### Process Information
- Runs in USER ring
- Non-privileged execution
- Can be suspended/resumed
- Saves game state to ~/.ucvm/rpg.save

### Network Features
When running on multiple UCVM nodes:
- Multiplayer support via message passing
- Shared world state through consensus
- Player trading system
- Distributed dungeon generation

## Troubleshooting

### Game Won't Start
```bash
$ ps  # Check if another instance is running
$ free  # Verify available memory
```

### Graphics Corruption
Ensure terminal supports UTF-8 and box-drawing characters.

### Save Game Issues
Check write permissions:
```bash
$ ls -la ~/.ucvm/
$ touch ~/.ucvm/test
```

## Development

### Building from Source
```bash
$ ucvm-asm rpg.asm -o rpg.sh
$ ucvm-link rpg.o -lncurses -o rpg
```

### Adding New Maps
Edit the map data section in rpg.sh:
```asm
custom_map:
    .db "#####################"
    ; 21x10 grid of ASCII chars
```

### Extending Combat
Modify `start_battle` and `battle_loop` routines to add:
- New enemy types
- Special abilities
- Item effects

## Credits
Created for the UCVM distributed computing platform.
ASCII art inspired by classic roguelike games.

## License
MIT License - See LICENSE file for details.

## Version History
- v1.0 - Initial release
  - Basic movement and combat
  - Three map areas
  - Save/load functionality
- v1.1 - (Planned)
  - Multiplayer support
  - Extended storyline
  - Boss battles