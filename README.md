# Fix Your Monster 2 - Developer Documentation

## 📋 Project Overview

**Fix Your Monster 2** is a Roblox monster-taming game inspired by Digimon and Pokémon, where players summon, train, evolve, and battle with unique monsters. The game features a progressive evolution system, tactical combat, training mechanics, and a player base system.

### Technology Stack
- **Platform**: Roblox
- **Language**: Luau (Lua 5.1 variant)
- **Architecture**: Client-Server with ReplicatedStorage for shared modules

---

## 🏗️ Architecture Overview

The project is organized into three main directories:

### Directory Structure

```
fix-your-monster-2/
├── LocalScripts/          # Client-side scripts
├── Main/                  # Server-side core systems
│   ├── CombatManager/     # Combat system components
│   ├── Data/              # Player data management
│   ├── TrainingSystem/    # Training mechanics
│   └── Dev/               # Development utilities
└── ReplicatedStorageModules/  # Shared modules (Client & Server)
    ├── MovesModules/      # Individual move implementations
    ├── MoveVFXModules/    # Move visual effects
    ├── Movement/          # Pathfinding and movement
    └── Effects&SFX/       # Visual effects and sound
```

### Architecture Principles

1. **Client-Server Separation**: Server handles game logic, client handles UI and VFX
2. **RemoteEvents**: Communication via `ReplicatedStorage.Remotes` folder
3. **Global Systems**: Key systems exposed via `_G` namespace for cross-module access
4. **Module-based**: Everything is organized as ModuleScripts for reusability

---

## 🎮 Core Systems

### 1. Monster System (`MonsterGenerator.luau`)

**Purpose**: Creates, manages, and tracks monster instances for players and NPCs.

**Key Features**:
- Monster generation with randomized stats based on races and stages
- Level-based stat scaling (5% increase per level)
- Archetype-based stat distribution (Tank, Mage, Striker, etc.)
- Personality system affecting behavior and training multipliers

**Stage System**:
- **Fledgeling** (Lv 1-10): 300 total stat cap
- **Rookie** (Lv 11-20): 800 total stat cap
- **Champion** (Lv 21-30): 1200 total stat cap
- **Elder** (Lv 31-40): 1800 total stat cap
- **Unique** (Lv 41-50): 2000 total stat cap

**Global Access**: `_G.MONSTERGENERATOR`
- `BuildMonster(data, ownerId)`: Creates a monster model
- `RollMonster(playerId, isNPC)`: Generates random monster data
- `GetPlayerMonster(playerId)`: Returns player's active monster
- `PlayerMonsters`: Table tracking all player monsters

### 2. Combat System (`Main/CombatManager/`)

**Purpose**: Manages tactical turn-based combat between monsters.

**Architecture**:
```
CombatManager/
├── init.luau              # Main combat loop and state management
├── Bridge.luau            # Communication between combat and external systems
├── CombatMath.luau        # Damage calculations, accuracy, criticals
├── StatusEffects.luau     # Buffs, debuffs, DoT, shields
├── EnhancedMovement.luau  # Tactical positioning and movement AI
└── DecisionClock.luau     # AI decision-making timing
```

**Combat Flow**:
1. **Initialization**: `StartCombat(monsterA, monsterB, opts)` creates combat instance
2. **State Loop**: Monsters cycle through tactical states
   - `deciding`: Choose action based on personality
   - `positioning`: Move to optimal range for chosen action
   - `executing`: Perform the action (attack/skill/defend)
   - `resting`: Cool down between actions
3. **AI Decisions**: Based on personality weights (Aggressive, Defensive, Unpredictable, etc.)
4. **Outcome**: Winner determined, callbacks fired, rewards distributed

**Combat States**: Managed by `_G.STATES` system
- `InCombat`: Monster is in active combat
- `CASTING`: Performing a move with cast time
- `DEFENDING`: Blocking/dodging stance
- `REPOSITIONING`: Moving tactically

**Global Access**: `_G.COMBAT`

### 3. Evolution System (`EvolutionManager.luau`)

**Purpose**: Handles monster evolution with branching paths and stat boosts.

**Evolution Mechanics**:
- **Trigger-based**: Evolution available when meeting requirements
- **Multi-path**: Multiple evolution options based on stats and conditions
- **Stat Boost**: Percentage + flat bonuses per stage
- **Move Unlocks**: New moves granted on evolution

**Evolution Requirements** (Gates):
- Minimum stats (e.g., Intelligence ≥ 70)
- Required stage reached
- Base race family matching
- Optional bond/experience thresholds

**Evolution Families**:
- **Progenitor**: RealitySeed → CosmicWeaver → VoidWalker/Architect → PrimeConcept
- **Construct**: Core → Golem → Titan → Colossus → PrimordialConstruct
- **Demonic**: Imp → Devil → Archdemon → AbyssLord
- **Lagomorph**: Hopling → LightFoot → Strikeron → Monarchare

**Convergent Evolutions**: Monsters from different families can converge (e.g., SteelBoxer, IronColoss)

**Process**:
1. Client sends `EvolutionRequest` RemoteEvent
2. Server checks eligibility via `Races.GetEvolutions()`
3. VFX played via `EvolutionEffect` RemoteEvent
4. Stats boosted, model replaced, moves updated
5. Completion notification via `EvolutionComplete`

**Global Access**: `_G.EVOLUTION`
- `StartEvolution(player, playerData)`
- `CheckEvolutionTrigger(player, triggerType, context)`

### 4. Move System (`ReplicatedStorageModules/Moves.luau`)

**Purpose**: Defines and manages combat abilities with stats, effects, and VFX.

**Move Properties**:
```lua
{
    id = "MoveIdentifier",
    name = "Display Name",
    rarity = "Amateur"|"Advanced"|"Specialist"|"Ascended"|"Primordial",
    power = 50,              -- Base damage
    accuracy = 0.88,         -- Hit chance (0-1)
    critChance = 0.05,       -- Critical hit chance
    mpCost = 15,             -- MP consumption
    cooldown = 3.0,          -- Seconds between uses
    castTime = 1.2,          -- Seconds to cast
    minRange = 0,            -- Minimum effective range
    maxRange = 25,           -- Maximum effective range
    tags = {"Magic", "Ranged", "AoE"},
    effects = {              -- StatusEffects applied
        {type = "burn", duration = 5, tickDamage = 10}
    }
}
```

**Move Tags** (affect stats):
- **Melee**: Higher accuracy (+4%), lower MP cost
- **Ranged**: Lower accuracy (-3%), moderate MP cost
- **Magic**: Higher MP cost (+15%), spell-based
- **AoE**: Reduced accuracy (-4%), hits multiple targets
- **GapClose**: Movement + damage
- **Defensive**: Shields, blocks, heals
- **Mobility**: Movement without damage

**MP Cost Formula**:
```
baseCost = power * 0.30
rarityMult = {Amateur: 1.0, Advanced: 1.1, ..., Primordial: 1.5}
tagMult = {Magic: 1.15, Ranged: 1.05, Melee: 0.95, ...}
mpCost = baseCost * rarityMult * tagMult
```

**Module Structure**:
- `Moves.luau`: Core move data and calculations
- `MovesModules/`: Individual move implementations (BasicAttack.luau, VoidRay.luau)
- `MoveVFX.luau`: Visual effect dispatcher
- `MoveVFXModules/`: VFX implementations per move
- `MoveUnlocks.luau`: Move progression by level/evolution

### 5. Training System (`Main/TrainingSystem/`)

**Purpose**: Stat-building mini-games that improve monster attributes.

**Components**:
```
TrainingSystem/
├── Main.luau              # Training orchestrator
├── TrainerHandler.luau    # NPC trainer interactions
├── Utils.luau             # Shared training utilities
└── Trainings/             # Individual training modules
    ├── Strength.luau
    ├── Speed.luau
    ├── Intelligence.luau
    └── ... (one per stat)
```

**Training Flow**:
1. Player interacts with training station/NPC
2. `TrainingSystem:Start(player, monster, trainingName, ctx)`
3. Training module executes (typically path-following or obstacle course)
4. Performance graded (Perfect/Good/OK/Miss)
5. Stats awarded based on grade and personality multipliers
6. Optional evolution trigger check

**Training Context**:
```lua
ctx = {
    Start = BasePart,        -- Starting position
    Finish = BasePart,       -- End position
    Nodes = Folder,          -- Waypoints/checkpoints
    Interactables = Folder,  -- Objects to interact with
    Base = Model             -- Player's training base
}
```

**Base System** (`BaseManager.luau`):
- Each player gets a personal training base instance
- Bases cloned from templates in ServerStorage/Workspace
- Training areas contain Start, Finish, Nodes, and Interactables
- Managed by `BaseManager` singleton

### 6. Data System (`Main/Data/`)

**Purpose**: Player data persistence using DataStore2-like pattern.

**Structure**:
```
Data/
├── init.luau           # Data manager initialization
├── Shared/             # Shared data schemas and defaults
├── OnJoining/          # Player join handlers
└── OnLeaving.luau      # Player leave handlers
```

**Global Access**: `_G.DATA`
- `Get(userId)`: Returns player data proxy
- Data proxy allows direct reads: `data.Monster`, `data.Stats`
- Modifications auto-save via proxy pattern

**Data Schema** (typical):
```lua
{
    Monster = {
        Race = "RealitySeed",
        Stage = "Fledgeling",
        Level = 1,
        Stats = {Hp, Mp, Strength, Defense, Skill, Speed, Intelligence, Luck},
        Moves = {"BasicAttack", "VoidRay"},
        Personality = "Aggressive",
        Bond = 50
    },
    Inventory = {},
    Currency = 0,
    Progress = {}
}
```

### 7. Encounter System (`EncounterManager.luau`)

**Purpose**: Manages wild monster encounters and NPC battles.

**Features**:
- Register interactive NPCs with ProximityPrompts
- Start combat when player interacts
- Handle win/loss outcomes
- Auto-respawn defeated NPCs after delay
- Support for scripted encounters (e.g., boss battles)

**API**:
```lua
EncounterManager.RegisterEncounter(encounterId, npcModel, prompt, {
    onWin = function(player, encounter) ... end,
    onLose = function(player, encounter) ... end,
    destroyOnWin = true,
    autoRespawnDelaySeconds = 60
})
```

### 8. State System (`States.luau`)

**Purpose**: Tracks and manages monster behavioral states.

**State Types**:
- **Movement**: `Following`, `Idle`, `Patrolling`
- **Combat**: `InCombat`, `Attacking`, `CASTING`, `DEFENDING`
- **Training**: `InTraining`
- **Misc**: `Stunned`, `Frozen`, `Asleep`

**Global Access**: `_G.STATES`
- `AddState(monster, stateName, key, data)`
- `RemoveState(monster, stateName, key)`
- `IsInState(monster, stateName)`: Returns true if state active
- `GetStorage(monster)`: Returns all states table

### 9. Personality System (`Personalities.luau`)

**Purpose**: Defines monster behavior patterns and training affinities.

**Personalities**:
- **Aggressive**: High attack weights, close-range preference, Strength/Defense bonuses
- **Defensive**: High defend/retreat, prefers safe distance, Defense/HP bonuses
- **Tactical**: Balanced weights, uses buffs/debuffs, Skill/Intelligence bonuses
- **Unpredictable**: Equal weights for all actions, no stat preference
- **Timid**: High retreat, prefers long range, Speed bonuses
- **Supportive**: Buff-focused, moderate range, Intelligence/MP bonuses

**Personality Structure**:
```lua
{
    weights = {               -- Combat decision weights
        engage = 15,
        retreat = 10,
        attack = 25,
        reposition = 10,
        defend = 15,
        buffSelf = 10,
        debuff = 5,
        taunt = 5,
        kite = 5,
        orbit = 0
    },
    movementStyle = {
        jitterRange = {0.5, 1.0},      -- Decision timing variance
        intentionDuration = 1.5,        -- How long AI commits to action
        personalSpace = 8,              -- Preferred distance from target
        preferCloseRange = false,
        aggressionMultiplier = 1.0,
        retreatThreshold = 0.25         -- HP% to trigger retreat
    },
    trainingMultipliers = {   -- Stat gain bonuses
        Strength = 1.0,
        Defense = 1.2,
        Speed = 0.9,
        Intelligence = 1.1,
        Luck = 1.0,
        Skill = 1.0
    }
}
```

### 10. Animation System

**Server**: `AnimationHandler.luau` - Triggers animations
**Client**: `AnimationHandler.local.luau` - Plays animations with VFX
**Shared**: `AnimationManager.luau` - Animation registry

**Animation Types**:
- Combat: Attack, Cast, Defend, Hurt, Death
- Movement: Walk, Run, Idle
- Emotes: Victory, Taunt

**Animations stored**: `ReplicatedStorage.Assets.Animations[RaceName]/`

### 11. Effects System

**Purpose**: Manages visual effects, sounds, and particles.

**Global Access**: `_G.EFFECTS`
- `ShowDamage(target, amount, isCrit)`: Floating damage numbers
- `PlaySound(soundName, {Where = part})`: Audio effects
- `EmitterEffect(effectName, {Where = part, Duration = 2})`: Particle effects
- `AuraEffect({Target = model, Color = Color3, Duration = 5})`: Persistent auras
- `Billboard({Target = part, Text = "Level Up!"})`: UI billboards
- `FovEffect({Target = player, Fov = 120, Duration = 1})`: Camera FOV changes

**VFX Modules**: `ReplicatedStorageModules/Effects&SFX/`
- `init.luau`: Effect registry and dispatcher
- `CraterModule/`: Ground impact effects
- `LightningBolt/`: Electric effects
- `Voidray.luau`: Beam effects
- `BubbleModule.luau`: Bubble shields

### 12. Movement System (`Movement/`)

**Purpose**: Pathfinding and following behavior for monsters.

**Global Access**: `_G.MOVEMENT`
- `StartFollowing(monster, target)`: Follow player or target
- `StopFollowing(monster)`: Cancel following
- `GoToPosition(monster, position)`: Navigate to point
- `StopFacing(monster)`: Cancel facing behavior

**Implementation**: Uses `SimplePath` module (Roblox pathfinding wrapper)

---

## 🔌 Global Systems (`_G` Namespace)

The project uses Lua globals (`_G`) to expose core systems for cross-module access:

| Global | Module | Purpose |
|--------|--------|---------|
| `_G.MONSTERGENERATOR` | MonsterGenerator.luau | Monster creation and registry |
| `_G.COMBAT` | CombatManager/init.luau | Combat system access |
| `_G.EVOLUTION` | EvolutionManager.luau | Evolution triggers |
| `_G.DATA` | Data/init.luau | Player data persistence |
| `_G.STATES` | States.luau | Monster state management |
| `_G.EFFECTS` | Effects&SFX/init.luau | VFX and sounds |
| `_G.MOVEMENT` | Movement/init.luau | Pathfinding and following |
| `_G.MOVE_LEARNING` | MoveLearning.luau | Move unlocking on level/evolution |
| `_G.DAMAGE` | CombatMath.luau | Damage calculations |

**Usage Pattern**:
```lua
-- Check if system is available before using
if _G.MONSTERGENERATOR then
    local monster = _G.MONSTERGENERATOR.GetPlayerMonster(userId)
end
```

---

## 🔄 Data Flow & Connections

### Player Join Flow
```
Player Joins
    ↓
Data/OnJoining/ loads player data
    ↓
_G.DATA:Get(userId) returns data proxy
    ↓
Shared.BuildMonster(playerData.Monster, userId)
    ↓
_G.MONSTERGENERATOR.BuildMonster creates monster model
    ↓
Monster spawned in Workspace near player
    ↓
_G.MOVEMENT.StartFollowing(monster, player.Character)
```

### Combat Flow
```
Player interacts with NPC (ProximityPrompt)
    ↓
EncounterManager triggers combat
    ↓
CombatManager.StartCombat(playerMonster, npcMonster)
    ↓
Combat loop: deciding → positioning → executing → resting
    ↓
Moves executed via MoveVFX + StatusEffects
    ↓
Winner determined
    ↓
_G.MOVE_LEARNING.OnCombatEnd(player, result)
    ↓
Check evolution trigger: _G.EVOLUTION.CheckEvolutionTrigger()
    ↓
Rewards given, monsters restored
```

### Evolution Flow
```
Player opens evolution UI (clicks button)
    ↓
Client sends EvolutionRequest RemoteEvent
    ↓
Server: _G.EVOLUTION.StartEvolution(player, playerData)
    ↓
Check eligibility: Races.GetEvolutions(currentRace, ctx)
    ↓
If eligible: calculate best evolution path
    ↓
Server fires EvolutionEffect RemoteEvent → Client plays VFX
    ↓
Wait EFFECT_DURATION (2 seconds)
    ↓
Boost stats, update race/stage
    ↓
Rebuild monster model (new appearance)
    ↓
Unlock new moves via MoveUnlocks
    ↓
Fire EvolutionComplete RemoteEvent → Client shows result
```

### Training Flow
```
Player activates training station
    ↓
BaseManager gets player's training area context
    ↓
TrainingSystem:Start(player, monster, "Strength", ctx)
    ↓
Set monster.InTraining = true
    ↓
Load training module: Trainings/Strength.luau
    ↓
Execute training (path following, obstacle course, etc.)
    ↓
Grade performance: Perfect (2x), Good (1.5x), OK (1x), Miss (0.1x)
    ↓
Apply stat gains with personality multipliers
    ↓
Update _G.DATA player stats
    ↓
Check evolution trigger
    ↓
Set monster.InTraining = false
```

---

## 📡 RemoteEvents Reference

All RemoteEvents located in `ReplicatedStorage.Remotes`:

### Server → Client
| Remote | Purpose | Arguments |
|--------|---------|-----------|
| `EvolutionEffect` | Play evolution VFX | `{event = "start"}` |
| `EvolutionComplete` | Show evolution result | `{success, newRace, reason}` |
| `TrainingCameraFocus` | Focus camera on training area | `{target = Part}` |
| `TrainingCameraRestore` | Restore camera to player | `{}` |
| `StatUpdate` | Update client UI with new stats | `{stats}` |

### Client → Server
| Remote | Purpose | Arguments |
|--------|---------|-----------|
| `MonsterSummon` | Spawn player's monster | `()` |
| `GenerateMonster` | Create new random monster (debug) | `()` |
| `EvolutionRequest` | Request evolution check | `()` |
| `TrainingSpinResult` | Training performance result | `{name, multiplier}` |
| `UIRemote` | Toggle monster sheet UI | `()` |
| `TestEvolutionTemplate` | Debug evolution testing | `{raceTarget}` |

---

## 🛠️ Development Guidelines

### Adding a New Monster Race

1. **Define in `Races.luau`**:
```lua
NewRaceName = {
    displayName = "Display Name",
    stage = "Fledgeling",  -- or Rookie, Champion, Elder, Unique
    baseRaceFamily = "FamilyName",
    isSummonable = true,   -- Can be starter monster?
    evolutions = {
        {
            target = "NextEvolution",
            requiredStage = "Rookie",
            gates = {
                minStats = {Strength = 30, Speed = 20},
                baseRaceFamily = "FamilyName"
            },
            weights = function(ctx)
                -- Return 0-1 score for this evolution
                return 0.5
            end
        }
    }
}
```

2. **Add to `EvolutionDefs.RaceStage` mapping**
3. **Create 3D model** in `ReplicatedStorage.Assets.Templates/`
4. **Add animations** in `ReplicatedStorage.Assets.Animations/[RaceName]/`
5. **Test via debug UI** (`GenerateMonster` RemoteEvent)

### Adding a New Move

1. **Define in `MovesModules/`**:
```lua
-- MovesModules/NewMove.luau
return {
    id = "NewMove",
    name = "New Move",
    rarity = "Advanced",
    power = 40,
    accuracy = 0.85,
    critChance = 0.08,
    mpCost = 20,
    cooldown = 4.0,
    castTime = 0.8,
    minRange = 5,
    maxRange = 20,
    tags = {"Ranged", "Magic"},
    effects = {
        {type = "burn", duration = 3, tickDamage = 5}
    }
}
```

2. **Create VFX in `MoveVFXModules/`**:
```lua
-- MoveVFXModules/NewMoveVFX.luau
local module = {}

function module.Play(caster, target, moveData)
    -- Create particle emitters, beams, sounds, etc.
    -- Return cleanup function
    return function()
        -- Cleanup VFX
    end
end

return module
```

3. **Register in `MoveInitializer.luau`**
4. **Add to `MoveUnlocks.luau`** for race/level unlocking

### Adding a New Training

1. **Create module in `TrainingSystem/Trainings/`**:
```lua
-- Trainings/NewStat.luau
local module = {}

function module.Execute(monster, ctx)
    -- ctx.Start, ctx.Finish, ctx.Nodes, ctx.Interactables
    -- Implement training logic
    -- Return {success, grade, stats}
    return {
        success = true,
        grade = "Perfect",  -- Perfect|Good|OK|Miss
        stats = {NewStat = 5}
    }
end

return module
```

2. **Create training area in player base template**:
   - Add `Start` Part (tagged "TrainingStart")
   - Add `Finish` Part (tagged "TrainingFinish")
   - Add `Nodes` Folder with waypoint Parts
   - Add `Interactables` Folder with objects

3. **Add ProximityPrompt** or UI button to trigger training

### Adding a New Personality

1. **Add to `Personalities.luau`**:
```lua
NewPersonality = {
    weights = {
        engage = 15,
        retreat = 5,
        attack = 30,
        reposition = 10,
        defend = 10,
        retarget = 5,
        buffSelf = 5,
        debuff = 5,
        taunt = 5,
        kite = 5,
        orbit = 5
    },
    movementStyle = {
        jitterRange = {0.5, 1.0},
        intentionDuration = 1.5,
        personalSpace = 8,
        preferCloseRange = false,
        aggressionMultiplier = 1.0,
        retreatThreshold = 0.25
    },
    trainingMultipliers = {
        Strength = 1.0,
        Defense = 1.0,
        Speed = 1.0,
        Intelligence = 1.0,
        Luck = 1.0,
        Skill = 1.0
    }
}
```

2. **Test by assigning to monster**: `monster:SetAttribute("Personality", "NewPersonality")`

---

## 🤖 AI & LLM Development Context

### Key Patterns

1. **Global System Access**: Check existence before use
```lua
if _G.SYSTEM_NAME then
    -- Use system
end
```

2. **Data Proxy Pattern**: PlayerData is a proxy, reads/writes auto-sync
```lua
local data = _G.DATA:Get(userId)
data.Monster.Level = 5  -- Auto-saves
```

3. **RemoteEvent Pattern**: Server validates, client renders
```lua
-- Server
RemoteEvent:FireClient(player, data)

-- Client
RemoteEvent.OnClientEvent:Connect(function(data)
    -- Update UI
end)
```

4. **State Management**: Always add/remove with keys
```lua
_G.STATES:AddState(monster, "InCombat", "combat_instance_123")
_G.STATES:RemoveState(monster, "InCombat", "combat_instance_123")
```

5. **Attribute-based Properties**: Used for runtime monster data
```lua
monster:SetAttribute("OwnerId", player.UserId)
monster:SetAttribute("Race", "RealitySeed")
monster:SetAttribute("Level", 5)
```

### Common Debugging Approaches

1. **Find Player's Monster**:
```lua
local monster = _G.MONSTERGENERATOR.GetPlayerMonster(userId)
-- or via Shared module
local monster = require(ServerScriptService.Main.Shared).GetPlayerMonster(player)
```

2. **Check Monster State**:
```lua
local states = _G.STATES:GetStorage(monster)
print(states.InCombat, states.Following, states.InTraining)
```

3. **Force Evolution** (debug):
```lua
_G.EVOLUTION.StartEvolution(player, _G.DATA:Get(player.UserId))
```

4. **Test Move VFX**:
```lua
local MoveVFX = require(ReplicatedStorage.Modules.MoveVFX)
MoveVFX.Play(caster, target, moveData)
```

### Stat Calculation Reference

**Damage Formula**:
```lua
baseDamage = move.power * (attacker.Strength / 10)
multiplier = 1.5 if crit else 1.0
defense_reduction = target.Defense / 20
finalDamage = (baseDamage * multiplier) - defense_reduction
-- Apply StatusEffects shields, then deal to Humanoid
```

**Accuracy Check**:
```lua
baseAccuracy = move.accuracy  -- e.g., 0.88
skillBonus = attacker.Skill * 0.001
defenseReduction = target.Speed * 0.0005
finalAccuracy = clamp(baseAccuracy + skillBonus - defenseReduction, 0.55, 0.98)
hit = random() < finalAccuracy
```

**Critical Hit**:
```lua
baseCrit = move.critChance  -- e.g., 0.05
luckBonus = attacker.Luck * 0.0005
finalCrit = clamp(baseCrit + luckBonus, 0, 0.35)
isCrit = random() < finalCrit
```

### Testing & Validation

**Enable Debug Mode**:
- Use `Debug.local.luau` client script
- Access via chat commands or UI buttons
- Toggle monster stats display, collision visualizers

**Test Combat**:
```lua
local CombatManager = require(ServerScriptService.Main.CombatManager)
CombatManager.StartCombat(monsterA, monsterB, {
    onEnd = function(winner, loser)
        print("Winner:", winner.Name)
    end
})
```

**Test Training**:
```lua
local TrainingSystem = require(ServerScriptService.Main.TrainingSystem.Main)
TrainingSystem:Start(player, monster, "Strength", {
    Start = workspace.TrainingAreas.StrengthStart,
    Finish = workspace.TrainingAreas.StrengthFinish
})
```

---

## 📚 Module Dependencies Map

```
MonsterGenerator
    ├── Races (evolution paths)
    ├── Personalities (behavior)
    ├── Moves (starter moves)
    ├── AnimationManager (animations)
    └── EvolutionDefs (stage caps)

CombatManager
    ├── Moves (move data)
    ├── Personalities (AI weights)
    ├── StatusEffects (buffs/debuffs)
    ├── CombatMath (damage calc)
    ├── EnhancedMovement (positioning)
    ├── AnimationHandler (combat anims)
    └── MoveUnlocks (available moves)

EvolutionManager
    ├── Races (evolution rules)
    ├── EvolutionDefs (stat boosts)
    ├── Moves (starter moves)
    ├── MoveUnlocks (evolution moves)
    └── MonsterGenerator (rebuild monster)

TrainingSystem
    ├── BaseManager (training areas)
    ├── MoveUnlocks (move learning)
    └── Individual training modules

Data System
    ├── OnJoining (player init)
    ├── OnLeaving (save & cleanup)
    └── Shared (data schema)
```

---

## 🔐 Security Notes

- **Server Authority**: All game logic runs on server
- **Client Validation**: Client actions validated server-side
- **Data Integrity**: DataStore saves via proxy prevent direct manipulation
- **Anti-Exploit**: Combat calculations server-side only
- **Rate Limiting**: RemoteEvents should have cooldowns (TODO)

---

## 📝 Legacy Files

Files marked `.legacy.luau` are deprecated but kept for reference:
- `MonsterSheetServer.legacy.luau`: Old UI system
- `TrainingHandlers.legacy.luau`: Old training logic
- `Zone.legacy.luau`: Old zone system
- `init.legacy.luau`: Old initialization

**Do not use these files** for new features. They exist for migration reference.

---

## 🚀 Quick Start for Developers

1. **Clone repository** and open in Roblox Studio
2. **Set up game structure**:
   - Place `Main/` folder in `ServerScriptService`
   - Place `ReplicatedStorageModules/` in `ReplicatedStorage.Modules`
   - Place `LocalScripts/` in `StarterPlayer.StarterPlayerScripts`
3. **Create required services**:
   - `ReplicatedStorage.Remotes` folder
   - `ReplicatedStorage.Assets` folder (Templates, Animations)
   - `Workspace.BaseSpots` folder (for player bases)
4. **Initialize systems** via `Main/Shared.luau` on server start
5. **Test with Debug UI** to spawn monsters and test systems

---

## 🎯 Roadmap & TODOs

- [ ] Implement matchmaking system (MatchmakingUI exists but incomplete)
- [ ] Add quest system for progression
- [ ] Implement inventory and item system
- [ ] Add more monster races (currently ~15 implemented)
- [ ] Expand move pool (currently ~10 moves)
- [ ] Add PvP combat (infrastructure exists)
- [ ] Implement monster trading
- [ ] Add leaderboards and rankings
- [ ] Optimize combat VFX performance
- [ ] Add more training mini-games

---

## 📞 Support & Contribution

For questions or contributions, refer to:
- **Code Style**: Follow Roblox Lua style guide
- **Module Structure**: ModuleScripts return a table/class
- **Naming**: PascalCase for modules, camelCase for functions/variables
- **Comments**: Use `--` for single-line, `--[[ ]]` for multi-line

---

**Last Updated**: 2025-10-27
**Version**: 2.0
**Maintainer**: oVesp
