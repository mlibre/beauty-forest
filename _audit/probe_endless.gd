extends SceneTree

## Endless-composition probe: every floor from the campaign's end to the deep
## walk must compose a complete, coherent answer from the endless tables --
## region with all nine color fields plus name/entry/ambient, a story vignette
## with title and body, feelings only on the learned rhythm (story 4 and 8),
## dragons and the cart on the campaign-cycling positions, and chapter names
## that stay unique far past the first 196. Run headless:
##   godot --headless --path . --script res://_audit/probe_endless.gd

const BeautyContent := preload("res://scripts/beauty_content.gd")
const BeautyEndless := preload("res://scripts/beauty_endless.gd")

const COLOR_FIELDS := ["sky", "horizon", "fog", "sun", "foliage", "tip", "flower", "ground", "accent"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	var names := {}
	var deep_floor := 300
	for floor_number in range(14, deep_floor + 1):
		var region: Dictionary = BeautyContent.region_for_floor(floor_number)
		if region.is_empty():
			print("FAIL floor %d: region_for_floor empty" % floor_number)
			failures += 1
			continue
		for field in COLOR_FIELDS:
			if not region.has(field) or String(region[field]).is_empty():
				print("FAIL floor %d: region missing color field %s" % [floor_number, field])
				failures += 1
		for text_field in ["name", "entry", "key", "ambient"]:
			if not region.has(text_field) or String(region[text_field]).is_empty():
				print("FAIL floor %d: region missing %s" % [floor_number, text_field])
				failures += 1
		var chapter := BeautyEndless.chapter_for_floor(floor_number)
		var region_name := String(region["name"])
		if names.has(region_name) and int(names[region_name]) != chapter:
			print("FAIL chapters %d and %d are both %s" % [names[region_name], chapter, region_name])
			failures += 1
		names[region_name] = chapter
		# The entry line interpolates the name: a compose bug would leave a %s behind.
		if String(region["entry"]).find("%s") >= 0:
			print("FAIL floor %d: entry kept a raw format placeholder" % floor_number)
			failures += 1
		var story: Array = BeautyContent.story_for_floor(floor_number)
		if story.size() != 2 or String(story[0]).is_empty() or String(story[1]).is_empty():
			print("FAIL floor %d: story vignette incomplete (%s)" % [floor_number, str(story)])
			failures += 1
		elif String(story[0]).find("%s") >= 0 or String(story[1]).find("%s") >= 0:
			print("FAIL floor %d: story kept a raw format placeholder" % floor_number)
			failures += 1
		var feeling: Dictionary = BeautyContent.feeling_for_floor(floor_number)
		var story_pos := BeautyContent.story_floor(floor_number)
		var should_feel := story_pos == 4 or story_pos == 8
		if should_feel and feeling.is_empty():
			print("FAIL floor %d: story %d should carry a Big Feeling" % [floor_number, story_pos])
			failures += 1
		if not should_feel and not feeling.is_empty():
			print("FAIL floor %d: unexpected Big Feeling on story %d" % [floor_number, story_pos])
			failures += 1
		if not feeling.is_empty() and (String(feeling.get("name", "")).is_empty() or String(feeling.get("farewell", "")).is_empty()):
			print("FAIL floor %d: feeling missing name or farewell" % floor_number)
			failures += 1
	# Dragon/cart rhythm at the positions the Mote line and waypoints promise.
	for floor_number in range(14, deep_floor + 1):
		var story_pos := BeautyContent.story_floor(floor_number)
		var dragon := BeautyContent.is_dragon_floor(floor_number)
		if dragon != (story_pos == 5 or story_pos == 13):
			print("FAIL floor %d: dragon flag disagrees with the story rhythm" % floor_number)
			failures += 1
	print("\n%d composition failure(s) over floors 14-%d; %d distinct region names" % [
		failures, deep_floor, names.size()])
	quit(1 if failures > 0 else 0)
