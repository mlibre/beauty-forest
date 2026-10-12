class_name RunShop
extends "res://scripts/run_state.gd"
## Peddle's cart and the loadout: what the hero owns, what each thing is worth,
## and which settings the run obeys.
##
## Split out of RunState. Every function here answers "what may I buy and wear",
## which is a single question about the run's inventory -- kept apart from the
## progression arithmetic above it so neither file has to know the other's
## vocabulary.
##
## There is no slot cap here any more, and no eviction. Capacity grows with
## depth (BeautyContent.loadout_capacity) and a charm can be owned twice, so
## the shelf never runs out of things worth buying. What used to be a swap --
## "which of your three charms should I throw away for this one?" -- is gone,
## because on a deep walk the honest answer is "wear them all".

## The next tier of `key` the hero could own, or 0 when it owns every copy.
func _next_tier(key: String) -> int:
    return BeautyData.next_tier(charms_owned, key)

func _owns(key: String, tier: int) -> bool:
    return BeautyData.owns(charms_owned, key, tier)

func _wearing(key: String, tier: int) -> bool:
    return BeautyData.wearing(charms_equipped, key, tier)

func _shop_state() -> Dictionary:
    var current_mote: Dictionary = {}
    for verse: Dictionary in BeautyContent.MOTE_VERSES:
        if String(verse["key"]) == mote_verse_key:
            current_mote = verse
            break
    return {
        "sparkles": sparkles,
        "charms": charms_equipped,
        "owned": charms_owned,
        "stanzas": stanzas_equipped,
        "mote_verse": current_mote,
        "hp": hp,
        "hp_max": hp_max,
        "capacity": loadout_capacity(),
    }

func _on_buy_requested(key: String) -> void:
    var record := BeautyContent.charm(key)
    if record.is_empty():
        return
    if key == "tea":
        _buy_tea(record)
        return
    var tier := _next_tier(key)
    if tier == 0:
        # Already owned at its deepest tier. The card is dimmed for this, but a
        # press can still arrive from a stale panel, so answer rather than
        # silently charging for nothing.
        ui.add_log("Peddle: “You already have the deepest %s I make. Wear it well!”" % String(record["name"]))
        return
    var price := BeautyContent.charm_price(key, tier)
    if sparkles < price:
        ui.show_toast("Not quite enough sparkles. The wares will keep.")
        return
    sparkles -= price
    charms_owned.append({"key": key, "tier": tier})
    if key == "scarf":
        # Max warmth is owned by _recalculate_loadout below, which rebuilds it
        # from the worn loadout. Bumping it here did nothing (the recompute
        # overwrote it four lines later) and read as a second source of truth,
        # so only the scarf's warming heal stays.
        hp = minf(hp_max, hp + 30.0)
    audio.play_chord([392.0, 523.25, 659.25], 0.62, 0.09)
    var label := BeautyContent.charm_label(key, tier)
    if charms_equipped.size() >= loadout_capacity():
        # The lantern is full at this depth, and the equip shelf refuses the
        # same overfill. Appending anyway used to end in a resize that dropped
        # the very ware this purchase paid for while the log claimed it was
        # on, so sell it owned-but-unworn and say so: a deeper floor opens
        # the room, and the shelf keeps the sale.
        ui.add_log("Peddle: “%s is wrapped for later — this lantern is full right now. Wander deeper and there will be room.”" % label)
    else:
        charms_equipped.append({"key": key, "tier": tier})
        ui.add_log("Peddle: “One %s, wrapped in a leaf. It suits you.”" % label)
    _award_sticker("shopper")
    _recalculate_loadout(false)
    ui.show_shop(_shop_state())
    _refresh_ui()

func _buy_tea(record: Dictionary) -> void:
    var price := int(record.get("price", 0))
    if hp >= hp_max:
        # Belt and braces: never charge for a heal that cannot happen.
        ui.add_log("Peddle: “No tea for you — you are warm as a toast. Save those sparkles!”")
        return
    if sparkles < price:
        ui.show_toast("Not quite enough sparkles. The wares will keep.")
        return
    sparkles -= price
    hp = hp_max
    audio.play_chord([523.25, 659.25, 783.99], 0.55, 0.08)
    ui.add_log("Peddle: “Sip slowly. Forest time is wonderfully flexible.”")

func _on_charm_equip_requested(key: String, tier: int) -> void:
    if not _owns(key, tier):
        return
    if _wearing(key, tier):
        charms_equipped.erase({"key": key, "tier": tier})
    else:
        if charms_equipped.size() >= loadout_capacity():
            # Should be unreachable while capacity tracks depth, but the card
            # is built from an older depth if a walk changed floors while the
            # cart was open. Answer instead of carrying an invisible ware.
            ui.add_log("Peddle: “This lantern is full for now — wander deeper and there will be room.”")
            return
        charms_equipped.append({"key": key, "tier": tier})
        # The row is ordered by the SHELF, not by when things were bought.
        # Appending at the end used to shuffle every socket: resting a charm and
        # wearing it again moved it to the back, so the player could not
        # recognise their own build. Sockets are a thing you learn to read.
        _reorder_worn_to_shelf()
    _recalculate_loadout(false)
    audio.play_tone(587.33, 0.24, 0.055, 1)
    ui.show_shop(_shop_state())

## Puts the worn list into the same order as the owned list, so a ware always
## wears into the socket its shelf position implies.
func _reorder_worn_to_shelf() -> void:
    var ordered: Array[Dictionary] = []
    for owned: Dictionary in charms_owned:
        if _wearing(String(owned.get("key", "")), int(owned.get("tier", 1))):
            ordered.append({"key": String(owned.get("key", "")),
                "tier": int(owned.get("tier", 1))})
    if ordered.size() == charms_equipped.size():
        charms_equipped = ordered

func _on_stanza_equip_requested(key: String) -> void:
    if bool(stanzas_equipped.get(key, false)):
        stanzas_equipped.erase(key)
    else:
        stanzas_equipped[key] = true
    _recalculate_loadout(false)
    audio.play_tone(659.25, 0.24, 0.055, 1)
    ui.show_shop(_shop_state())

func _on_mote_verse_requested(key: String) -> void:
    mote_verse_key = key
    _recalculate_loadout(false)
    audio.play_tone(783.99, 0.30, 0.055, 1)
    ui.add_log("Mote: “%s — I’ll hum that beside you.”" % (String(BeautyContent.random_choice(BeautyLore.MOTE_LINES)) if not key.is_empty() else "I’ll hum softly beside you."))
    ui.show_shop(_shop_state())

func _recalculate_loadout(reset_hp: bool) -> void:
    charm_effects = BeautyData.charm_effects(charms_equipped)
    stanza_effects = BeautyData.stanza_effects(stanzas_equipped)
    verse_effects = BeautyData.mote_verse_effects(mote_verse_key)
    var base_hp_max := 100.0 + (15.0 if selected_style == "gentle" else 0.0) + level_hp_bonus + float(charm_effects.get("max_hp", 0.0))
    if reset_hp:
        hp_max = base_hp_max
        hp = hp_max
    else:
        hp_max = base_hp_max
        hp = minf(hp, hp_max)
    if player and is_instance_valid(player):
        player.setup(dungeon, charm_effects, bool(settings.get("reduced_motion", false)))
        player.set_control_enabled(_gameplay_controls_enabled())

func _apply_settings(value: Dictionary, persist: bool) -> void:
    settings = value.duplicate(true)
    ui.apply_settings(settings)
    # The HUD collapses based on text_scale, but apply_settings lives in the base
    # UI class and cannot call the layout pass defined further down the mixin
    # chain. Without this, raising the text size on a short window leaves the
    # wide layout in place — the left card grows to 590x454 and overlaps the
    # hint bar — until something else happens to resize the window.
    ui._fit_layout()
    if audio:
        audio.set_volume(float(settings.get("volume", 0.8)))
        audio.set_muted(bool(settings.get("muted", false)))
    if music:
        music.set_master(float(settings.get("volume", 0.8)), bool(settings.get("muted", false)))
    if world and is_instance_valid(world):
        world.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    for wisp: Wisp in wisps:
        if is_instance_valid(wisp):
            wisp.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if player and is_instance_valid(player) and player.hero:
        player.hero.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if persist:
        BeautyData.save_settings(settings)
