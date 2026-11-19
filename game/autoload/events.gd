extends Node
## Global event bus (autoload "Events").
##
## Declares every game-wide signal in one place so they are easy to find.
## Rules:
## - Only for events that several unrelated parts of the game care about.
##   Parent/child communication uses normal signals instead.
## - No logic and no state here: just signal declarations.
##
## Emit:    Events.puzzle_solved.emit(&"P1-1")
## Listen:  Events.puzzle_solved.connect(_on_puzzle_solved)

# The signals are emitted from other scripts, so silence "unused signal".
@warning_ignore_start("unused_signal")

## A puzzle was solved. [param puzzle_id] is the id the level gives that puzzle.
signal puzzle_solved(puzzle_id: StringName)

@warning_ignore_restore("unused_signal")
