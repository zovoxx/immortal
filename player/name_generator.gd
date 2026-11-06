class_name NameGenerator
extends RefCounted
## Generates courier names: first name + epithet ("Mira the Third", "Old Tomas", "Kesh Twice-Fallen").

const FIRST_NAMES: Array[String] = [
	"Mira", "Tomas", "Kesh", "Anya", "Bram", "Ilse", "Joren", "Wren", "Sabe", "Dov",
	"Orla", "Pell", "Rook", "Tamsin", "Ezra", "Hale", "Nim", "Corra", "Vash", "Liesel",
	"Aldo", "Brisk", "Fen", "Greta", "Haskel", "Ivo", "Juna", "Lark", "Marek", "Nessa",
	"Oskar", "Petra", "Quill", "Runa", "Soren", "Teo", "Ulla", "Vida", "Yara", "Zev",
]
const EPITHETS: Array[String] = [
	"Twice-Fallen", "Quickfoot", "the Quiet", "Ninefingers", "of the Ash Road",
	"the Patient", "Ironheel", "Saltborn", "Stormchild", "the Late", "Half-Named",
	"Lantern-Eye", "the Unsent", "Dustwalker", "Long-Shadow", "the Stubborn",
]
const ORDINALS: Array[String] = [
	"", "", "the Second", "the Third", "the Fourth", "the Fifth", "the Sixth",
	"the Seventh", "the Eighth", "the Ninth", "the Tenth",
]


## used_first_names: how many times each first name already appeared in the lineage.
static func generate(rng: RandomNumberGenerator, traits: Array[String], used_first_names: Dictionary) -> Dictionary:
	var first: String = FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)]
	var times: int = int(used_first_names.get(first, 0)) + 1
	var full := first
	if traits.has("old"):
		full = "Old " + first
	elif times >= 2 and times < ORDINALS.size() and rng.randf() < 0.75:
		full = "%s %s" % [first, ORDINALS[times]]
	elif traits.has("swift") and rng.randf() < 0.5:
		full = first + " the Swift"
	elif traits.has("scarred") and rng.randf() < 0.5:
		full = first + " the Scarred"
	elif rng.randf() < 0.7:
		full = "%s %s" % [first, EPITHETS[rng.randi_range(0, EPITHETS.size() - 1)]]
	return {"first": first, "full": full}
