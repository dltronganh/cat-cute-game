class_name FishCase
extends RefCounted
## Day 1 (Monday) case: Mèo Xinh eats the fish on the high table.
## Turns the kitchen's state into clues for OwnerReasoner.
##
## Pure logic, unit tested in tests/core/cases/test_fish_case.gd.
##
## The winning chain (2 steps): drop the thread end from the table, then roll
## Lộc's ball so he runs through the thread and pulls the plate down.
## Plus: wash the fish off your face, and don't nap next to the scene.

## Keys of the state Dictionary passed to [method build_clues]. All are bools.
const FISH_EATEN := "fish_eaten"          ## The mischief happened.
const PLATE_ON_FLOOR := "plate_on_floor"  ## The plate fell off the table.
const THREAD_DOWN := "thread_down"        ## Thread end hangs from the table.
const DOG_NEAR_PLATE := "dog_near_plate"  ## Lộc is sitting next to the plate.
const CAT_MOUTH_DIRTY := "cat_mouth_dirty" ## Fish still on the cat's lips.
const CAT_NEAR_SCENE := "cat_near_scene"  ## The cat is close to the table.

const Suspect := OwnerReasoner.Suspect
const Clue := OwnerReasoner.Clue


## Builds the clues bà Hằng finds, in the order she finds them.
## Missing keys count as false.
static func build_clues(state: Dictionary) -> Array[Clue]:
	var clues: Array[Clue] = []
	if not state.get(FISH_EATEN, false):
		return clues  # nothing to investigate
	# Rule 5: is the cat clean? Fish on the lips ends it at once.
	if state.get(CAT_MOUTH_DIRTY, false):
		clues.append(Clue.new(Suspect.CAT, 5, "Mép Mèo Xinh còn dính cá kìa!", true))
		return clues
	# Rule 1: could Lộc reach it?
	if not state.get(PLATE_ON_FLOOR, false):
		clues.append(Clue.new(Suspect.CAT, 5, "Đĩa vẫn trên bàn cao mà cá mất... Lộc đâu có với tới."))
	else:
		clues.append(Clue.new(Suspect.DOG, 2, "Đĩa cá rơi xuống đất rồi!"))
		# Rule 2: is there something linking the steps?
		if state.get(THREAD_DOWN, false):
			clues.append(Clue.new(Suspect.DOG, 2, "Sợi chỉ vướng vào khăn bàn... có đứa chạy qua kéo đổ."))
		else:
			clues.append(Clue.new(Suspect.CAT, 2, "Tự nhiên đĩa rơi? Lạ thật..."))
	# Rule 4: who is where?
	if state.get(DOG_NEAR_PLATE, false):
		clues.append(Clue.new(Suspect.DOG, 2, "Lộc ngồi ngay cạnh đĩa cá!"))
	if state.get(CAT_NEAR_SCENE, false):
		clues.append(Clue.new(Suspect.CAT, 2, "Sao Mèo Xinh lảng vảng ở đây?"))
	return clues
