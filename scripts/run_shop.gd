class_name RunShop
extends RunState

## Peddle's cart and the loadout: what the hero owns, what each thing is worth,
## what a full set of slots evicts, and which settings the run obeys.
##
## Split out of RunState. Every function here answers "what may I buy, wear and
## hum", which is a single question about the run's inventory -- kept apart from
## the progression arithmetic above it so neither file has to know the other's
## vocabulary.

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
    }

func _on_buy_requested(key: String) -> void:
    var record: Dictionary = {}
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == key:
            record = charm
            break
    if record.is_empty():
        return
    var price := int(record.get("price", 0))
    if sparkles < price:
        ui.show_toast("Not quite enough sparkles. The wares will keep.")
        return
    if key == "tea":
        if hp >= hp_max:
            # Belt and braces: never charge for a heal that cannot happen.
            ui.add_log("Peddle: “No tea for you — you are warm as a toast. Save those sparkles!”")
            return
        sparkles -= price
        hp = hp_max
        audio.play_chord([523.25, 659.25, 783.99], 0.55, 0.08)
        ui.add_log("Peddle: “Sip slowly. Forest time is wonderfully flexible.”")
    else:
        if bool(charms_owned.get(key, false)):
            return
        sparkles -= price
        charms_owned[key] = true
        var equipped_count := charms_equipped.size()
        if equipped_count < BeautyContent.MAX_CHARMS:
            charms_equipped[key] = true
        if key == "scarf":
            # Max warmth is owned by _recalculate_loadout below, which rebuilds
            # it from the equipped loadout. Bumping it here did nothing (the
            # recompute overwrote it four lines later) and read as a second
            # source of truth, so only the scarf's warming heal stays.
            hp = minf(hp_max, hp + 30.0)
        audio.play_chord([392.0, 523.25, 659.25], 0.62, 0.09)
        if charms_equipped.has(key):
            ui.add_log("Peddle: “One %s, wrapped in a leaf. It suits you.”" % String(record["name"]))
        else:
            # All three slots are taken, so this one waits in the pocket. Say so:
            # taking the sparkles and saying "it suits you" while the charm does
            # nothing is how a player ends up hunting for a power they never got.
            ui.add_log("Peddle: “One %s, tucked safely in your pocket. Swap a charm on to wear it.”" % String(record["name"]))
    _award_sticker("shopper")
    _recalculate_loadout(false)
    ui.show_shop(_shop_state())
    _refresh_ui()

func _on_charm_equip_requested(key: String) -> void:
    if not bool(charms_owned.get(key, false)):
        return
    if bool(charms_equipped.get(key, false)):
        charms_equipped.erase(key)
    else:
        if charms_equipped.size() >= BeautyContent.MAX_CHARMS:
            charms_equipped = _loadout_replacing(key)
            var rested := _evicted_charm_name()
            ui.add_log("Peddle: “%s on. %s rests in your pocket — tap it any time to swap back.”" % [
                _charm_name(key), rested])
        else:
            charms_equipped[key] = true
    _recalculate_loadout(false)
    audio.play_tone(587.33, 0.24, 0.055, 1)
    ui.show_shop(_shop_state())

## The loadout after swapping `key` in with every slot already full. Which worn
## charm came off used to fall out of charms_owned.keys() order: the LAST owned
## key that was wearing, which is neither the weakest nor the one a player would
## pick, and the UI never said so. Iterating the WORN set instead and keeping the
## first MAX_CHARMS-1 means the evicted charm is a stable, explainable choice,
## and Peddle now names it out loud.
func _loadout_replacing(key: String) -> Dictionary:
    var next_loadout: Dictionary = {key: true}
    var equipped_count := 1
    for worn_key: String in charms_equipped.keys():
        if worn_key == key:
            continue
        if equipped_count >= BeautyContent.MAX_CHARMS:
            break
        next_loadout[worn_key] = true
        equipped_count += 1
    _evicted = ""
    for worn_key: String in charms_equipped.keys():
        if not next_loadout.has(worn_key):
            _evicted = worn_key
            break
    return next_loadout

func _charm_name(key: String) -> String:
    for charm: Dictionary in BeautyContent.CHARMS:
        if String(charm["key"]) == key:
            return String(charm["name"])
    return key

func _evicted_charm_name() -> String:
    if _evicted == "":
        return "The one underneath"
    return _charm_name(_evicted)

func _on_stanza_equip_requested(key: String) -> void:
    if bool(stanzas_equipped.get(key, false)):
        stanzas_equipped.erase(key)
    else:
        if stanzas_equipped.size() >= BeautyContent.MAX_STANZAS:
            stanzas_equipped = _stanzas_replacing(key)
            ui.add_log("Mote: “%s it is. %s steps back for now — tap it again any time.”" % [
                _stanza_name(key), _evicted_stanza_name()])
        else:
            stanzas_equipped[key] = true
    _recalculate_loadout(false)
    audio.play_tone(659.25, 0.24, 0.055, 1)
    ui.show_shop(_shop_state())

## The stanza loadout after a swap. Same shape as _loadout_replacing: name what
## steps aside, because the shop offers "try it on" for every verse and the
## player has no other way to tell that one of the two they were humming just
## stopped being sung.
func _stanzas_replacing(key: String) -> Dictionary:
    var next_stanzas: Dictionary = {key: true}
    var stanza_count := 1
    for existing: String in stanzas_equipped.keys():
        if existing == key:
            continue
        if stanza_count >= BeautyContent.MAX_STANZAS:
            break
        next_stanzas[existing] = true
        stanza_count += 1
    _evicted_stanza = ""
    for existing: String in stanzas_equipped.keys():
        if not next_stanzas.has(existing):
            _evicted_stanza = existing
            break
    return next_stanzas

func _stanza_name(key: String) -> String:
    for stanza: Dictionary in BeautyContent.STANZAS:
        if String(stanza["key"]) == key:
            return String(stanza["name"])
    return key

func _evicted_stanza_name() -> String:
    if _evicted_stanza == "":
        return "The other verse"
    return _stanza_name(_evicted_stanza)

func _on_mote_verse_requested(key: String) -> void:
    mote_verse_key = key
    _recalculate_loadout(false)
    audio.play_tone(783.99, 0.30, 0.055, 1)
    ui.add_log("Mote: “%s — I’ll hum that beside you.”" % (String(BeautyContent.random_choice(BeautyContent.MOTE_LINES)) if not key.is_empty() else "I’ll hum softly beside you."))
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
    if world and is_instance_valid(world):
        world.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    for wisp: Wisp in wisps:
        if is_instance_valid(wisp):
            wisp.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if player and is_instance_valid(player) and player.hero:
        player.hero.set_reduced_motion(bool(settings.get("reduced_motion", false)))
    if persist:
        BeautyData.save_settings(settings)
