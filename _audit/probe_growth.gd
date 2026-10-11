extends SceneTree

# Dev probe — Not shipped.
#
# Drives the REAL run_state level curve through a long walk and reports whether
# the hero keeps pace with the creatures. The Python model in
# ~/.hermes/cache/scratch/growth_probe3.py predicts a stable ratio near 1.3; this
# checks that the shipped GDScript agrees, because a model can be right about a
# curve the code does not actually implement.

# Pinned by path: a cold boot has no class cache, and a bare RunBoons would
# not parse -- the same rule regression_architecture holds every file to.
const RunBoons := preload("res://scripts/run_boons.gd")

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var marks := [1, 5, 13, 30, 60, 120, 200, 300, 400]
	var ratios: Array = []
	var at: Dictionary = {}
	for floor in range(1, 401):
		game.floor_number = floor
		# Soul actually collected on this floor, from the same wisp math the run
		# uses -- not a guess.
		var count: int = mini(6 + 2 * floor, 40)
		var souls := 0
		for i in count:
			souls += int(round(float(1 + 0.25 * (floor - 1)) * randf_range(4.0, 12.0)))
		game._gain_xp(souls)
		# Growth is CHOSEN now: every level deals three glyph cards and
		# the walker picks one. This probe walks a balanced policy --
		# song 40%, warmth 40%, both 20% -- the same average song
		# growth the old random perk handed out, so the ratio answers
		# "does a reasonable picker keep pace", not "does one specific
		# build". A walker who never picks song falls behind on
		# purpose; Peddle's cart (echo, ember, chorus) and the draft's
		# own song cards are the levers that choice is about.
		while game.pending_boons > 0:
			var roll := randf()
			var key := "song"
			if roll >= 0.80:
				key = "both"
			elif roll >= 0.40:
				key = "warmth"
			for boon: Dictionary in RunBoons.BOON_POOL:
				if String(boon["key"]) == key:
					game._apply_boon(boon)
					break
			game.pending_boons -= 1
		if floor in marks:
			var creature := 10.0 * (1.0 + 0.18 * float(floor - 1))
			var ratio: float = game.attack / creature
			ratios.append(ratio)
			at[floor] = {"level": game.level, "song": game.attack,
				"creature": creature, "ratio": ratio,
				"cost_next": game._next_level_cost()}

	print("REAL CURVE floor | level | song | creature hp | ratio | next level costs")
	for floor: int in marks:
		var row: Dictionary = at[floor]
		print("REAL %6d | %5d | %4d | %11.0f | %5.2f | %5d" % [
			floor, int(row["level"]), int(row["song"]), float(row["creature"]),
			float(row["ratio"]), int(row["cost_next"])])

	var tail: Array = ratios.slice(maxi(0, ratios.size() - 4))
	print("REAL ratio over the last four marks: %s" % str(tail))
	print("REAL level at floor 400: %d (a ceilingless curve keeps climbing)" % game.level)
	# The invariant: the hero never falls behind the thing it is fighting. If this
	# drops below 1.0 the player is fighting a war of attrition with no lever.
	var worst: float = 999.0
	for floor in range(1, 401):
		var creature_now := 10.0 * (1.0 + 0.18 * float(floor - 1))
		worst = minf(worst, game.attack / creature_now)
	print("REAL worst song-to-creature ratio over the walk: %.2f %s" % [
		worst, "OK" if worst > 0.8 else "FAIL -- the hero falls behind"])
	quit()
