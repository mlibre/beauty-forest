extends "res://tests/support/test_case.gd"
## Regression for thank-you heart pickups:
##  - a single pickup must never heal the hero twice (queue_free is deferred,
##    so overlapping Area3D reports used to emit a second heart_collected)
##  - a heart that times out must say so instead of vanishing silently

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const HeartPickup := preload("res://scripts/heart_pickup.gd")
const Player := preload("res://scripts/player.gd")

func _initialize() -> void:
	suite_name = "BEAUTY_FOREST_HEART"
	call_deferred("_run")

func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)

	var player := Player.new()
	holder.add_child(player)

	var heart := HeartPickup.new()
	holder.add_child(heart)
	heart.setup(Vector3(2.0, 0.0, 0.0), 15.0, 1.0, false)
	# GDScript lambdas capture locals by value, so count through arrays.
	var collected := [0]
	var expired := [0]
	heart.heart_collected.connect(func(_pickup: HeartPickup) -> void: collected[0] += 1)
	heart.heart_expired.connect(func(_pickup: HeartPickup) -> void: expired[0] += 1)

	# The same overlap can be reported more than once in a frame.
	heart._on_body_entered(player)
	heart._on_body_entered(player)
	ok(collected[0] == 1, "one heart granted warmth %d times instead of once" % collected[0])
	ok(expired[0] == 0, "a collected heart also reported an expiry")

	# An uncollected heart must announce its drift-off exactly once.
	var lonely := HeartPickup.new()
	holder.add_child(lonely)
	lonely.setup(Vector3(4.0, 0.0, 0.0), 15.0, 1.0, false)
	var lonely_expired := [0]
	lonely.heart_expired.connect(func(_pickup: HeartPickup) -> void: lonely_expired[0] += 1)
	lonely.lifetime = 0.5
	lonely._process(0.6)
	lonely._process(0.6)
	ok(lonely_expired[0] == 1, "a drifted-off heart reported its expiry %d times instead of once" % lonely_expired[0])
	ok(collected[0] == 1, "a drifting-off heart still granted warmth")

	# A collected heart must not keep ticking (and re-report) while freeing.
	heart._process(1.0)
	ok(expired[0] == 0, "a collected heart reported an expiry while freeing")

	# Pickup upgrades promise a wider attraction, not just a larger direct
	# collision shape. A Dandelion/Lodestar heart at 4.5 m should be acquired
	# by its 5.25 m magnet and begin drifting toward the waiting player.
	var wide_player := Player.new()
	wide_player.position = Vector3(4.5, 0.05, 0.0)
	holder.add_child(wide_player)
	var wide_heart := HeartPickup.new()
	holder.add_child(wide_heart)
	wide_heart.setup(Vector3.ZERO, 15.0, 1.5, true)
	var magnet_area := wide_heart.get_node("MagnetRange") as Area3D
	var magnet_shape: CollisionShape3D
	for child: Node in magnet_area.get_children():
		if child is CollisionShape3D:
			magnet_shape = child
			break
	ok(magnet_shape != null, "a magnet heart did not build its attraction sensor")
	if magnet_shape != null:
		var magnet_sphere := magnet_shape.shape as SphereShape3D
		ok(magnet_sphere != null and is_equal_approx(magnet_sphere.radius, 5.25), "the pickup upgrade did not widen the heart magnet to 5.25 m")
	wide_heart._on_magnet_body_entered(wide_player)
	var magnet_before := wide_heart.global_position
	wide_heart._process(1.0 / 60.0)
	ok(wide_heart.global_position.distance_to(magnet_before) > 0.01, "a widened heart magnet did not drift toward a player inside its range")

	finish(holder, "BEAUTY_FOREST_HEART")
