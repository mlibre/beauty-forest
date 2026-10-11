extends "res://tests/support/test_case.gd"
## When saving goes wrong: damaged satchels quarantined instead of
## overwritten, failed saves visible to the player, and an unreadable file
## never costing the player their data. The happy-path persistence suite
## lives in regression_data.gd.

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.
const BeautyData := preload("res://scripts/beauty_data.gd")

func _initialize() -> void:
    suite_name = "BEAUTY_FOREST_DATA_GUARD"
    TestProfile.begin("data_guard")
    call_deferred("_run")

func _run() -> void:
    await _test_the_save_guard_refuses_a_damaged_satchel()
    await _test_a_failed_save_is_visible_to_the_player()
    await _test_unreadable_satchel_is_never_overwritten()
    await _test_unreadable_settings_are_never_overwritten()
    await _sweep_removes_even_pre_reboot_leftovers()
func _sweep_removes_even_pre_reboot_leftovers() -> void:
    ## The stale-profile sweep keyed staleness on `now - stamp > max_age` with
    ## Time.get_ticks_usec(), which resets every boot: a directory created late
    ## in a long session looks, after a reboot, like a stamp in the FUTURE, so
    ## its age went negative and the sweep kept it forever. Age must be read
    ## as a distance, not a direction.
    var root := "user://test_profiles"
    DirAccess.make_dir_recursive_absolute(root)
    # A fresh headless process is well under a second old, so no real stamp
    # can be genuinely old yet: the past case uses the smallest honest stamp
    # (1 microsecond) against a one-MILLISECOND budget, and the future case
    # stamps two hours ahead -- exactly what a leftover from a previous
    # session looks like after Time.get_ticks_usec() resets at boot.
    var now := Time.get_ticks_usec()
    var past := "%s/guardpast_1" % root
    var future := "%s/guardfuture_%d" % [root, now + 2 * 3600 * 1000000]
    for path in [past, future]:
        DirAccess.make_dir_recursive_absolute(path)
        var marker := FileAccess.open(path + "/keep.json", FileAccess.WRITE)
        if marker:
            marker.store_string("{}")
            marker.close()
    TestProfile._sweep_stale(1000)
    # The one-millisecond budget sweeps THIS suite's own throwaway profile
    # too (it is seconds old); re-establish it so finish() below still pairs
    # its teardown with a live directory.
    TestProfile.begin("data_guard")
    for pair in [["a pre-reboot leftover", future], ["an old-stamp leftover", past]]:
        if not ok(not FileAccess.file_exists("%s/keep.json" % pair[1]) and not DirAccess.dir_exists_absolute(pair[1]),
                "the sweep kept %s alive (%s)" % [pair[0], pair[1]]):
            TestProfile._remove_recursive(future)
            TestProfile._remove_recursive(past)
            return
    finish(null, "BEAUTY_FOREST_DATA_GUARD")

func _test_the_save_guard_refuses_a_damaged_satchel() -> void:
    var rich := BeautyData.default_meta()
    rich["runs"] = 412
    rich["wisps_soothed"] = 2337
    rich["dragons_sung"] = 27

    # The backup name is stamped to the second by BeautyData, so wait for a fresh
    # second; otherwise this collides with the quarantine above, the rename
    # succeeds, and the guard is never exercised.
    #
    # The blocking path is asked of BeautyData rather than rebuilt here, so it
    # cannot drift from the format the quarantine actually uses.
    #
    # It is planted for the NEXT second as well as this one, and the load is
    # retried if the second turns over mid-fixture. The stamp has one-second
    # resolution, so a second boundary falling between planting the blocker and
    # asking for the quarantine aimed the rename at a path nothing was blocking;
    # the rename then succeeded, the file moved aside, and the two checks below
    # failed on a coin flip. That is the whole flake: measured at roughly 1 run
    # in 12 here, and it is a fixture bug, not a product bug -- the guard itself
    # behaves correctly in every run where the fixture manages to block it.
    _clear_quarantined(BeautyData.save_path())
    _clear_quarantined(BeautyData.settings_path())
    await _wait_for_a_fresh_stamp()
    _obstruct_quarantine(BeautyData.save_path())
    var stuck := FileAccess.open(BeautyData.save_path(), FileAccess.WRITE)
    ok(stuck != null, "the second truncation fixture must be creatable")
    if stuck != null:
        stuck.store_string('{"version": 2, "runs": 412, "wisps_so')
        stuck.close()
    var stuck_loaded: Dictionary = BeautyData.load_meta()
    # The obstruction is planted for this second AND the next, so the guard is
    # meant to be exercised on every run. It is not, though, if the boundary falls
    # the other way: the quarantine then targets a stamp nothing was blocking, the
    # rename succeeds, and the damaged file moves aside. That is the guard working
    # CORRECTLY on an unobstructed path -- so it is a reason to redo the fixture,
    # not a failure. It used to be asserted, which meant a correct quarantine
    # failed the suite about 1 run in 4 and hid the real question (does the guard
    # behave when it IS obstructed?). So: put the file back, re-block, load again.
    var retried := false
    while not FileAccess.file_exists(BeautyData.save_path()) and not retried:
        retried = true
        _clear_quarantined(BeautyData.save_path())
        _obstruct_quarantine(BeautyData.save_path())
        var retry := FileAccess.open(BeautyData.save_path(), FileAccess.WRITE)
        if retry != null:
            retry.store_string('{"version": 2, "runs": 412, "wisps_so')
            retry.close()
        stuck_loaded = BeautyData.load_meta()
    ok(FileAccess.file_exists(BeautyData.save_path()),
        "the guard must refuse to overwrite a damaged satchel it cannot move aside")
    ok(not BeautyData.save_meta(stuck_loaded),
        "a save must be refused while the only copy of the satchel still sits at the live path")
    # Existence is not enough -- an overwrite leaves a file standing. The bytes
    # themselves must still be the ones we failed to read.
    var survivor := FileAccess.open(BeautyData.save_path(), FileAccess.READ)
    var preserved_bytes := survivor != null and survivor.get_as_text().contains("wisps_so")
    if survivor != null:
        survivor.close()
    ok(preserved_bytes,
        "the refused save must not have overwritten the only copy of the damaged file")

    # Once the obstruction is gone the same path recovers, so a player who hits
    # this is not locked out of progress for the rest of the session. The suite's
    # own sweeper takes out every planted stamp, files and directories alike.
    _clear_quarantined(BeautyData.save_path())
    await _wait_for_a_fresh_stamp()
    var retry := FileAccess.open(BeautyData.save_path(), FileAccess.WRITE)
    if retry != null:
        retry.store_string('{"version": 2, "runs": 412, "wisps_so')
        retry.close()
    BeautyData.load_meta()
    ok(BeautyData.save_meta(rich), "saving must resume once the damaged file can be moved aside")

## BeautyData stamps quarantine names to the second, so a fixture that plants an
## obstruction at that name must own the whole second it lands in.
func _wait_for_a_fresh_stamp() -> void:
    while Time.get_unix_time_from_system() - floor(Time.get_unix_time_from_system()) > 0.05:
        await process_frame

## Plant a DIRECTORY on every quarantine stamp the loader could pick for the
## next few seconds, so the rename fails and the damaged file stays put. The
## fixture used to plant exactly two stamps -- now and now+1 -- which made it
## immune to a second boundary but not to the two or three a cold parse can
## take: the load landed in an unplanted second, quarantined the fixture's own
## damaged file, and the setup failed on its own assertion roughly one run in
## three cache-free. A planted RANGE converts that wall-clock race into a
## bounded quantity the suite controls.
##
## The arithmetic is on the UNIX TIME, not on the formatted string: a datetime
## string is not a number, so adding a second to it in place is not possible.
func _obstruct_quarantine(base_path: String, seconds: int = 6) -> void:
    var directory := ProjectSettings.globalize_path(base_path.get_base_dir())
    var name := base_path.get_file()
    for ahead in range(0, seconds + 1):
        var stamp := "%s.corrupt-%s" % [name,
            Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + ahead)
                .replace(":", "-").replace("T", "_")]
        DirAccess.make_dir_recursive_absolute(directory.path_join(stamp))

func _clear_quarantined(base_path: String) -> void:
    var directory := base_path.get_base_dir()
    var name := base_path.get_file()
    for child: String in DirAccess.get_files_at(directory):
        if child.begins_with(name + ".corrupt-"):
            DirAccess.remove_absolute(directory.path_join(child))
    # Directories too. The save-guard fixture plants a DIRECTORY where the
    # backup will go, to make the rename fail; sweeping only files left that
    # directory standing, so it kept blocking a quarantine a later check expected
    # to succeed. That is why this suite failed about 1 run in 12 on the baseline
    # and worse once the fixture started running more often -- the flake was a
    # fixture leaking state into itself.
    for child: String in DirAccess.get_directories_at(directory):
        if child.begins_with(name + ".corrupt-"):
            DirAccess.remove_absolute(directory.path_join(child))

func _find_quarantined(base_path: String) -> String:
    var directory := base_path.get_base_dir()
    var name := base_path.get_file()
    for child: String in DirAccess.get_files_at(directory):
        if child.begins_with(name + ".corrupt-"):
            return directory.path_join(child)
    return ""

func _test_a_failed_save_is_visible_to_the_player() -> void:
    # A save failure that preserves the prior save was covered; whether the
    # PLAYER finds out was not. Nine call sites discard save_meta()'s bool and
    # rely on the push_warning inside, which only the console sees. Measured:
    # with saving blocked, the game put "Sticker earned: First Nap" on screen,
    # the pause summary counted the sticker, and not one on-screen string
    # mentioned that it had not been written down -- so the game congratulated
    # the player for something the next launch would forget.
    var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    # Block every save the way a full or read-only disk would.
    remove_path(BeautyData.save_path() + ".tmp")
    ok(DirAccess.make_dir_absolute(BeautyData.save_path() + ".tmp") == OK,
        "the blocked staging fixture must be creatable")

    ok(not ((game.get("meta") as Dictionary).get("stickers", []) as Array).has("first_nap"),
        "test setup: the fixture sticker was already held")
    game.call("_award_sticker", "first_nap")
    # Toasts expire on a tween clock, so watch the screen across the window
    # rather than sampling one instant: a single sample after the toast has faded
    # would see an empty slot and pass or fail for the wrong reason.
    var texts: Array[String] = []
    for _frame in 400:
        await process_frame
        texts = _collect_label_texts(game)
        if _saw_celebration(texts) and _saw_notice(texts):
            break

    var in_memory: Array = (game.get("meta") as Dictionary).get("stickers", [])
    var on_disk: Array = BeautyData.load_meta().get("stickers", [])
    ok(in_memory.has("first_nap"), "test setup: the sticker was not announced in memory")
    ok(not on_disk.has("first_nap"), "test setup: the blocked save unexpectedly reached disk")
    # The game claimed the sticker, so it has to admit when it could not keep it.
    ok(_saw_celebration(texts), "test setup: the sticker celebration never appeared")
    ok(_saw_notice(texts),
        "a save failed while the game announced a sticker, and nothing on screen admitted it [labels=%s]" % str(texts))

    remove_path(BeautyData.save_path() + ".tmp")
    game.queue_free()
    await process_frame

## Both of these match on specific wording. A loose "does any label mention
## saving" search passes on the menu subtitle ("no hurry, no losing ♥"), and a
## loose "does any label mention the run" passes on "Visits 0 · Deepest floor 0".
func _saw_celebration(texts: Array[String]) -> bool:
    for text: String in texts:
        if text.begins_with("Sticker earned"):
            return true
    return false

func _saw_notice(texts: Array[String]) -> bool:
    for text: String in texts:
        var lower := text.to_lower()
        if lower.contains("couldn't be saved") or lower.contains("could not be saved"):
            return true
    return false

func _collect_label_texts(node: Node) -> Array[String]:
    var out: Array[String] = []
    if node is Label:
        var text := String((node as Label).text).strip_edges()
        if not text.is_empty():
            out.append(text)
    for child in node.get_children():
        out.append_array(_collect_label_texts(child))
    return out

func _test_unreadable_satchel_is_never_overwritten() -> void:
    # The guard that refuses to write over a still-unreadable satchel is only
    # reachable when moving the damaged file aside FAILS -- the rare case. Drive
    # it by planting a directory where the backup will go, so the rename fails.
    # A save failure that preserves the prior save was already covered. The
    # mirror case was not: a READ failure. load_meta() answered "unreadable"
    # and "brand new player" with the same empty dict, so a satchel truncated by
    # a crash mid-write lost every run, sticker and fact -- and the very next
    # ordinary save committed that blank dict straight over the only copy.
    # Measured: 412 runs, 2337 wisps and 27 dragons reduced to a 196-byte
    # fresh profile, unrecoverable.
    var rich := BeautyData.default_meta()
    rich["runs"] = 412
    rich["wisps_soothed"] = 2337
    rich["dragons_sung"] = 27
    rich["best_floor"] = 17
    rich["stickers"] = ["century", "dragon_friend"]
    for index in 50:
        rich["facts_learned"].append("fact %d" % index)
    rich["facts"] = 50
    ok(BeautyData.save_meta(rich), "the pre-corruption satchel fixture must save")

    # The realistic damage: a crash or a full disk leaves partial JSON.
    var damaged := FileAccess.open(BeautyData.save_path(), FileAccess.WRITE)
    if not ok(damaged != null, "the truncation fixture must be creatable"):
        return
    damaged.store_string('{"version": 2, "runs": 412, "wisps_so')
    damaged.close()

    var loaded: Dictionary = BeautyData.load_meta()
    ok(BeautyData.meta_read_failed(),
            "load_meta must report that it could not read the satchel, so a blank profile is never mistaken for a new player")

    # The damaged bytes must still be on disk somewhere, not merely spared.
    var preserved := _find_quarantined(BeautyData.save_path())
    ok(not preserved.is_empty(),
            "the unreadable satchel was moved aside instead of being overwritten in place")
    if not preserved.is_empty():
            var kept := FileAccess.open(preserved, FileAccess.READ)
            ok(kept != null and kept.get_as_text().contains("wisps_so"),
                "the preserved satchel should still hold the player's bytes, got %s" % preserved)
            if kept != null:
                kept.close()

    # Because it was moved aside, the live path is free and saving must work
    # again immediately -- a player who reloads after a corrupt file should not
    # be locked out of progress for the rest of the session.
    ok(BeautyData.save_meta(rich), "saving must work again once the damaged file is out of the way")
    ok(int(BeautyData.load_meta().get("runs", -1)) == 412,
            "the player's history must be intact after the recovery")
    ok(_find_quarantined(BeautyData.save_path()) == preserved,
            "the recovery save must not disturb the preserved copy")

    # Settings have the same shape, and it is milder but still real: a damaged
    # config reverts every accessibility choice, including the ones a player
    # needs to play comfortably at all. Only the damage ConfigFile actually
    # rejects can be caught, though -- measured, it returns OK for a file
    # truncated mid-key, an empty file, binary junk and plain prose, silently
    # yielding no settings. There is no signal to tell that apart from a genuine
    # all-defaults config, so this covers the crash shape it does reject.
    var comfy := BeautyData.default_settings()
    comfy["reduced_motion"] = true
    comfy["text_scale"] = 2.0
    comfy["muted"] = true
    ok(BeautyData.save_settings(comfy), "the pre-corruption settings fixture must save")
    var broken := FileAccess.open(BeautyData.settings_path(), FileAccess.WRITE)
    ok(broken != null, "the settings truncation fixture must be creatable")
    if broken != null:
        broken.store_string("[cozy]\nreduced_motion = tr")
        broken.close()
    var reloaded: Dictionary = BeautyData.load_settings()
    ok(_find_quarantined(BeautyData.settings_path()) != "",
        "a settings file that would not parse was moved aside instead of being overwritten")
    ok(not bool(reloaded["reduced_motion"]) and float(reloaded["text_scale"]) == 1.0,
        "damaged settings must fall back to readable defaults, not to half-parsed values")

func _test_unreadable_settings_are_never_overwritten() -> void:
    # The satchel refuses to save while a damaged file it could not move aside
    # still sits at the live path. Settings documented the same promise -- "the
    # same data-loss shape ... do not overwrite it" -- but load_settings
    # discarded the quarantine result and save_settings had no guard, so when
    # the move failed the next ordinary save silently destroyed the only copy
    # of the config that held a player's accessibility choices.
    _clear_quarantined(BeautyData.settings_path())
    var comfy := BeautyData.default_settings()
    comfy["reduced_motion"] = true
    comfy["text_scale"] = 2.0
    ok(BeautyData.save_settings(comfy), "the readable settings fixture must save")

    # The realistic damage shape the ConfigFile loader does reject.
    var damaged := FileAccess.open(BeautyData.settings_path(), FileAccess.WRITE)
    if not ok(damaged != null, "the damaged settings fixture must be creatable"):
        return
    damaged.store_string("[cozy]\nreduced_motion = tr")
    damaged.close()

    # Block the quarantine the same way the satchel fixture does: a directory
    # where the backup would land, planted for this second and the next.
    await _wait_for_a_fresh_stamp()
    var retried := false
    while not FileAccess.file_exists(BeautyData.settings_path()) and not retried:
        retried = true
        _clear_quarantined(BeautyData.settings_path())
        var replant := FileAccess.open(BeautyData.settings_path(), FileAccess.WRITE)
        if replant != null:
            replant.store_string("[cozy]\nreduced_motion = tr")
            replant.close()
        _obstruct_quarantine(BeautyData.settings_path())
        BeautyData.load_settings()
    _obstruct_quarantine(BeautyData.settings_path())
    BeautyData.load_settings()
    ok(FileAccess.file_exists(BeautyData.settings_path()),
        "test setup: the damaged settings file must still sit at the live path (quarantine obstructed)")

    ok(not BeautyData.save_settings(BeautyData.default_settings()),
        "a settings save must be refused while the only copy of the damaged file still sits at the live path")
    var survivor := FileAccess.open(BeautyData.settings_path(), FileAccess.READ)
    var preserved := survivor != null and survivor.get_as_text().contains("reduced_motion = tr")
    if survivor != null:
        survivor.close()
    ok(preserved,
        "the refused settings save must not have overwritten the only copy of the damaged file")

    # Recovery mirrors the satchel: once the obstruction is gone, the next
    # load moves the damaged file aside and saving works again immediately.
    # The sweeper takes out every planted stamp, not just two of them.
    _clear_quarantined(BeautyData.settings_path())
    await _wait_for_a_fresh_stamp()
    BeautyData.load_settings()
    var kept := _find_quarantined(BeautyData.settings_path())
    ok(not kept.is_empty() and FileAccess.get_file_as_string(kept).contains("reduced_motion = tr"),
        "the recovery load must still move the damaged settings aside, bytes intact")
    ok(BeautyData.save_settings(comfy), "settings saves must resume once the damaged file is out of the way")
    _clear_quarantined(BeautyData.settings_path())