extends SceneTree

## Endless-composition probe: every floor from the campaign's end to the deep
## walk must compose a complete, coherent answer from the endless tables --
## region with all nine color fields plus name/entry/ambient, a story vignette
## with title and body, feelings and dragons and the cart on the rhythm each
## depth owns (the campaign's wrap below the Roost, the chapter's thirteen
## above it), and chapter names that stay unique far past the first 196. Run
## headless:
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
                for text_field in ["name", "entry", "key"]:
                        if not region.has(text_field) or String(region[text_field]).is_empty():
                                print("FAIL floor %d: region missing %s" % [floor_number, text_field])
                                failures += 1
                # The ambient mood is the composed chapters' own contract: the campaign
                # regions name their song with the key itself.
                if BeautyEndless.is_endless(floor_number):
                        if not region.has("ambient") or String(region["ambient"]).is_empty():
                                print("FAIL floor %d: composed region missing ambient" % floor_number)
                                failures += 1
                var region_name := String(region["name"])
                # The uniqueness promise is CHAPTER-scoped: a chapter's name
                # must never repeat within the bloom. Campaign floors sit
                # outside that math entirely -- chapter_for_floor is only
                # meaningful past the Roost, and feeding it campaign floors
                # invents "chapter 0" from negative integer division.
                if BeautyEndless.is_endless(floor_number):
                        var chapter := BeautyEndless.chapter_for_floor(floor_number)
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
                var should_feel: bool
                if BeautyEndless.is_endless(floor_number):
                        should_feel = BeautyEndless.story_in_chapter(floor_number) in [4, 8]
                else:
                        should_feel = BeautyContent.FEELINGS.has(BeautyContent.story_floor(floor_number))
                if should_feel and feeling.is_empty():
                        print("FAIL floor %d: its rhythm promises a Big Feeling" % floor_number)
                        failures += 1
                if not should_feel and not feeling.is_empty():
                        print("FAIL floor %d: unexpected Big Feeling off the rhythm" % floor_number)
                        failures += 1
                if not feeling.is_empty() and (String(feeling.get("name", "")).is_empty() or String(feeling.get("farewell", "")).is_empty()):
                        print("FAIL floor %d: feeling missing name or farewell" % floor_number)
                        failures += 1
        # Dragon and cart rhythm at the positions each depth's own plan promises:
        # the campaign's wrap below the Roost, the chapter's thirteen above it —
        # and never a cart parked on a sleeping dragon's floor at any depth.
        for floor_number in range(14, deep_floor + 1):
                var dragon := BeautyContent.is_dragon_floor(floor_number)
                var cart := BeautyContent.is_merchant_floor(floor_number)
                var expected_dragon: bool
                var expected_cart: bool
                if BeautyEndless.is_endless(floor_number):
                        var chapter_story := BeautyEndless.story_in_chapter(floor_number)
                        expected_dragon = chapter_story == 5 or BeautyContent.is_chapter_final_floor(floor_number)
                        expected_cart = chapter_story in [2, 4, 7, 10]
                else:
                        var wrap_story := BeautyContent.story_floor(floor_number)
                        expected_dragon = wrap_story in [5, 13, 21, 29] or BeautyContent.is_chapter_final_floor(floor_number)
                        expected_cart = wrap_story in [2, 4, 7, 10, 14, 16, 19, 22, 25, 27]
                if dragon != expected_dragon:
                        print("FAIL floor %d: dragon flag disagrees with the story rhythm" % floor_number)
                        failures += 1
                if cart != expected_cart:
                        print("FAIL floor %d: cart flag disagrees with the story rhythm" % floor_number)
                        failures += 1
                if dragon and cart:
                        print("FAIL floor %d: the cart parked on a sleeping dragon's floor" % floor_number)
                        failures += 1
                if dragon:
                        # The endless chapters must place a dragon only where a
                        # beat promises a sleeper (the fifth beat, or the
                        # chapter's own roost). The campaign's hand-placed
                        # list is its own authority.
                        if BeautyEndless.is_endless(floor_number):
                                var finale := BeautyContent.is_chapter_final_floor(floor_number)
                                var sleeper := BeautyEndless.story_in_chapter(floor_number) == 5
                                if not finale and not sleeper:
                                        print("FAIL floor %d: a dragon on a beat that promises no sleeper" % floor_number)
                                        failures += 1
        print("\n%d composition failure(s) over floors 14-%d; %d distinct region names" % [
                failures, deep_floor, names.size()])
        quit(1 if failures > 0 else 0)
