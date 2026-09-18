class_name GameConfig
extends RefCounted
## All tuning knobs in one place. Change values here; nothing else needs editing.

const GAME_TITLE := "Merge Them All"

# --- Scoring -----------------------------------------------------------------
const SCORE_LEVEL_COMPLETE := 1000
const SCORE_PER_REMAINING_MOVE := 300
const SCORE_PER_REMAINING_SECOND := 25

# --- Limits ------------------------------------------------------------------
## When true, running out of moves / time fails the level.
## When false (default), the limits are only targets: going over just means no bonus.
const FAIL_ON_MOVE_LIMIT := false
const FAIL_ON_TIME_LIMIT := false
## The clock starts with the first move (gives players time to study the board).
const TIMER_STARTS_ON_FIRST_MOVE := true

# --- Rules -------------------------------------------------------------------
## Minimum number of orthogonally-connected same-type items that explode.
const MIN_MATCH_GROUP := 2
## Item A surrounded on all 4 sides by items of one other type B -> all 5 explode.
const SURROUND_RULE_ENABLED := true
## Bomb blast radius (1 = the 3x3 square around the bomb).
const BOMB_RADIUS := 1
## Tapping a bomb detonates it (counts as one move).
const TAP_TO_DETONATE_BOMB := true
## A match explosion breaks breakable walls next to it.
const MATCH_BREAKS_ADJACENT_WALLS := true
## A match explosion sets off bombs next to it.
const MATCH_TRIGGERS_ADJACENT_BOMBS := true
## Safety cap for gravity loops (e.g. an item endlessly falling through teleports).
const MAX_GRAVITY_STEPS := 60

# --- Levels ------------------------------------------------------------------
const LEVELS_PER_WORLD := 10
const WORLD_NAMES := [
	"Jungle Meadow", "Waterfall Cliffs", "Desert Temple", "Frozen Portals", "Old Pipeworks",
	"Deep Quarry", "Volcano", "Acid Swamp", "Sky Isles", "Crystal Caves", "Nexus",
]
## Visual theme per world (see WorldTheme). Cycled when there are more worlds.
const WORLD_THEMES := [
	"jungle", "waterfall", "desert", "ice", "ruins",
	"cave", "volcano", "swamp", "sky", "crystal", "nexus",
]

# --- Animation (seconds) -----------------------------------------------------
const ANIM_SLIDE := 0.11
const ANIM_FALL := 0.065
const ANIM_TELEPORT := 0.13
const ANIM_PIPE := 0.12
const ANIM_DESTROY := 0.28
const ANIM_UNLOCK := 0.25

# --- Input -------------------------------------------------------------------
## While the button is held, the dragged item keeps stepping (one cell at a time)
## towards the cell under the pointer, and stops when it gets there.
## false: every cell an item travels counts as a move (matches the solver and the built-in move limits).
## true: one continuous drag counts as a single move, however far the item travels.
const DRAG_COUNTS_AS_ONE_MOVE := false


## Score breakdown for a completed level.
static func score(move_limit: int, moves_used: int, time_limit: int, seconds_used: float) -> Dictionary:
	var moves_left := maxi(move_limit - moves_used, 0)
	var secs_left := maxi(int(floor(time_limit - seconds_used)), 0)
	var d := {
		"base": SCORE_LEVEL_COMPLETE,
		"moves_left": moves_left,
		"move_bonus": moves_left * SCORE_PER_REMAINING_MOVE,
		"secs_left": secs_left,
		"time_bonus": secs_left * SCORE_PER_REMAINING_SECOND,
	}
	d["total"] = d.base + d.move_bonus + d.time_bonus
	return d
