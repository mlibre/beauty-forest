class_name MusicScores
extends RefCounted

# Deps are pinned by path on purpose: a fresh clone ships no
# editor-built global-class cache, and bare names would not parse
# on first boot. regression_architecture holds this file to it.

## The forest's songbook: the note tables every song is grown from, the songs
## themselves, and which song a floor hums. Split out of MusicDirector so the
## music box stays about voices, fades and frame budgets while the scores
## live in one file a composer can read top to bottom.

## Semitone tables for the two moods the forest sings in.
const MAJOR_PENTATONIC := [0, 2, 4, 7, 9]
const MINOR_PENTATONIC := [0, 3, 5, 7, 10]

## One song per region mood, all in the family of the old ambient roots
## (sunlit-roots 110Hz, pollen-halls 123.47, mushroom-lull 98, roost 130.81)
## so the walk's regions keep their own colors — plus one VARIATION per mood
## (dewlight-spark, pollen-waltz, mossy-nocturne, lullaby-coda), so a long
## walk through one region hears two songs instead of one loop forever. Each
## song: a key root, a tempo, four triads as semitones over the root (two
## bars each), the pentatonic scale the bells play, a hand-written melody —
## scale degrees 0-4, +10 for an octave lift, -1 for a rest, two slots per
## bar — and the octave the bells ring in.
const SONGS := {
    "sunlit-roots": {
        "root": 220.0, "tempo": 72.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [2, 4, 3, 2, 1, 3, 2, -1, 1, 2, 3, 4, 12, 11, 0, -1],
    },
    "dewlight-spark": {
        "root": 246.94, "tempo": 76.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [4, -1, 12, -1, 3, 2, 4, -1, 2, 3, 1, 2, 0, -1, 0, -1],
    },
    "pollen-halls": {
        "root": 146.83, "tempo": 78.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [4, 1, 2, 3, 4, 2, 1, -1, 0, 2, 3, 4, 2, 0, 2, -1],
    },
    "pollen-waltz": {
        "root": 174.61, "tempo": 84.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],
        "melody": [2, 2, 3, 4, 4, -1, 3, 2, 1, 1, 2, 3, 2, -1, 0, -1],
    },
    "mushroom-lull": {
        "root": 164.81, "tempo": 63.0, "melody_octave": 2,
        "scale": MINOR_PENTATONIC,
        "chords": [[0, 3, 7], [8, 12, 15], [3, 7, 10], [10, 14, 17]],
        "melody": [2, 3, 2, 1, 0, 2, 1, -1, 3, 4, 3, 2, 1, 0, 2, -1],
    },
    "mossy-nocturne": {
        "root": 146.83, "tempo": 58.0, "melody_octave": 2,
        "scale": MINOR_PENTATONIC,
        "chords": [[0, 3, 7], [8, 12, 15], [3, 7, 10], [10, 14, 17]],
        "melody": [0, -1, -1, 2, -1, 1, 0, -1, 3, -1, 2, -1, 1, -1, -1, -1],
    },
    "roost": {
        "root": 130.81, "tempo": 66.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        "melody": [4, -1, 3, -1, 2, -1, 1, 0, 3, -1, 2, -1, 1, -1, 0, -1],
    },
    "lullaby-coda": {
        "root": 155.56, "tempo": 60.0, "melody_octave": 2,
        "scale": MAJOR_PENTATONIC,
        "chords": [[0, 4, 7], [5, 9, 12], [9, 12, 16], [7, 11, 14]],
        "melody": [2, -1, 3, -1, 4, -1, 12, -1, 3, -1, 2, -1, 1, -1, 0, -1],
    },
}

## Which song a floor hums: odd floors trade each region's own lullaby for
## its variation, so walking one region for several floors still hears two
## songs. Unknown regions (and even floors) land on the region's own song,
## which falls back to the sunlit one inside play_region.
static func floor_song(region_key: String, floor_number: int) -> String:
    var variations := {
        "sunlit-roots": "dewlight-spark",
        "pollen-halls": "pollen-waltz",
        "mushroom-lull": "mossy-nocturne",
        "roost": "lullaby-coda",
    }
    if posmod(floor_number, 2) == 1 and SONGS.has(String(variations.get(region_key, ""))):
        return String(variations[region_key])
    return region_key
