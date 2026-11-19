class_name OwnerReasoner
extends RefCounted
## Decides who bà Hằng blames, from a list of clues found at the scene.
##
## Pure logic: no nodes, no scene tree, unit tested in
## tests/core/owner/test_owner_reasoner.gd.
## The rules are five common-sense rules a real owner would use.
##
## Each level turns its world state into clues (see game/core/cases/), then:
## [codeblock]
## var verdict := OwnerReasoner.judge(clues)
## if verdict.suspect == OwnerReasoner.Suspect.DOG: ...  # "LỘC!!!"
## [/codeblock]

## Who bà Hằng can blame.
enum Suspect {
	NOBODY, ## Nothing happened (the cat did no mischief yet).
	CAT,    ## Mèo Xinh gets caught: the player fails the day.
	DOG,    ## Lộc gets the blame: the player wins the day.
}


## One thing bà Hằng notices. [member thought] is what she says out loud.
class Clue:
	extends RefCounted
	## Who this clue points at.
	var suspect: Suspect
	## How strongly it points (1 = a hint, 5 = very convincing).
	var weight: int
	## A clue that ends the investigation at once (e.g. fish on the cat's lips).
	var decisive: bool
	## What she thinks out loud, shown in a speech bubble.
	var thought: String

	func _init(p_suspect: Suspect, p_weight: int, p_thought: String, p_decisive := false) -> void:
		suspect = p_suspect
		weight = p_weight
		thought = p_thought
		decisive = p_decisive


## The result: who is blamed and the thoughts that led there, in order.
class Verdict:
	extends RefCounted
	var suspect: Suspect
	var thoughts: PackedStringArray

	func _init(p_suspect: Suspect, p_thoughts: PackedStringArray) -> void:
		suspect = p_suspect
		thoughts = p_thoughts


## Judges [param clues] in the order she finds them.
## - A decisive clue stops the investigation immediately.
## - Otherwise the dog is blamed only if the dog's total weight is strictly
##   greater than the cat's. Ties go to the cat, because the mischief itself
##   always points at the cat first (only a cat could have done it).
## - With no clue for anyone, nobody is blamed.
static func judge(clues: Array[Clue]) -> Verdict:
	var thoughts: PackedStringArray = []
	var cat_score := 0
	var dog_score := 0
	for clue in clues:
		thoughts.append(clue.thought)
		if clue.decisive:
			return Verdict.new(clue.suspect, thoughts)
		match clue.suspect:
			Suspect.CAT:
				cat_score += clue.weight
			Suspect.DOG:
				dog_score += clue.weight
	if cat_score == 0 and dog_score == 0:
		return Verdict.new(Suspect.NOBODY, thoughts)
	return Verdict.new(Suspect.DOG if dog_score > cat_score else Suspect.CAT, thoughts)
