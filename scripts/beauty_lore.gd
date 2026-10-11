class_name BeautyLore
extends RefCounted

## The words the forest says: Mote's chatter, the fun-fact Atlas, signposts,
## and the little lines that mark a moment. Pure prose, no floor arithmetic --
## the tables that key off depth live in BeautyContent, and the endless-chapter
## composer lives in BeautyEndless.

const FACTS := [
    "Octopuses have three hearts — two just for the gills.",
    "Honey found in ancient Egyptian tombs is still perfectly edible.",
    "Bananas are berries; strawberries are not.",
    "A day on Venus is longer than its year.",
    "Sea otters hold hands while sleeping so they don’t drift apart.",
    "The Eiffel Tower grows about 15 cm taller in summer heat.",
    "Wombats produce cube-shaped droppings. Science remains polite about it.",
    "There are more possible chess games than atoms in the observable universe.",
    "Some turtles can breathe through their rear ends. Nature is resourceful.",
    "Sunlight takes about eight minutes to reach us. You are seeing the past!",
    "A group of flamingos is called a flamboyance.",
    "Oxford University is older than the Aztec Empire.",
    "Banana plants are giant herbs, not trees.",
    "Cows have best friends and get stressed when separated.",
    "Butterflies taste with their feet.",
    "Hot water can freeze faster than cold water under the right conditions.",
    "Fireflies talk to each other in flashes — each species has its own Morse code.",
    "A single teaspoon of honey is the life's work of about twelve bees.",
    "Otters hold hands while sleeping so they don't drift apart — twice as cozy as rumored.",
    "Mushrooms breathe out a little mist every night, like tiny forest kettles.",
    "A snail can sleep for three years when the weather is unkind. Relatable.",
    "Dandelion seeds can ride the wind for miles on their tiny parachutes.",
    "Bees can recognize human faces, and they gossip about the kind ones.",
    "Trees share sugar with their seedlings through underground fungal post.",
    "A group of pandas is called an embarrassment. A very soft embarrassment.",
    "Some moss can survive being dried out for a century, then simply resume.",
    "Squirrels plant thousands of trees by forgetting where they put things.",
    "Cats knead because it reminds them of being safe and small. So does napping here.",
    "The oldest known seed sprouted was a Judean date palm, after 2,000 years of patience.",
    "Frogs drink through their skin, which is why they always look slightly dewy.",
    "A woodpecker's tongue wraps around its skull. Safety equipment, apparently.",
    "Starlings fly in murmurations with no leader at all. Everyone just agrees.",
]

const MOTE_LINES := [
    "You’re doing wonderfully. Statistically, even.",
    "Fun fact: I am made of leftover starlight and optimism.",
    "If you get lost, we are lost together. That’s teamwork.",
    "I counted the wisps. There are… several.",
    "You smell like courage. Or bread. Hard to tell down here.",
    "Every floor is new. Like a sandwich, but spatial.",
    "Take your time. The forest has nowhere to be either.",
    "I named a rock earlier. It’s called Kevin. Very reliable.",
    "That mushroom glows because it read a lot as a spore.",
    "Wandering counts as a plan. A lovely, leaf-crunchy plan.",
    "I polished your lantern while you blinked. You blinked beautifully.",
    "The pollen says hello. I translated. It was kind.",
    "My map says we are exactly where the cozy is.",
    "Somewhere a dragon is snoring in your honor. Probably.",
    "No rush, no fuss. The stairs will wait. They are stairs.",
    "I packed snacks. They are made of light. Zero crumbs.",
    "That wisp just waved at you. With its whole body. Charming.",
    "Your lantern is humming in a major key today. Fancy.",
    "I asked a mushroom for directions. It said ‘down, but prettily’.",
    "Somewhere, a pebble is cheering for you. Quietly. Like a pebble.",
    "You walk like someone who waves at trees. The trees noticed.",
    "Deep breath in… smell that? That is Tuesday. Cozy Tuesday.",
    "I alphabetized the fireflies. They appreciated the attention.",
    "A fern unrolled a little further just now. For you, I think.",
    "The deeper we go, the warmer the moss gets. Forest logic.",
    "I told the stairs you were coming. They seemed flattered.",
    "Your shadow looks like it is having a nice walk too.",
    "Somewhere below, a dragon is dreaming of a small lantern. Hmm.",
    "I keep a list of your best steps. It is a long list.",
    "The golden light follows you like a polite little sun.",
]

const SOOTHE_LINES := [
    "Oh, that one floated home smiling. Lovely work.",
    "Gentle! That wisp is practically purring.",
    "Home they go, warm as toast. You did that.",
    "That soothe was softer than a dandelion sneeze.",
    "The lantern sang, the wisp sighed happily. Teamwork.",
    "Guided home! The forest applauds, quietly, with leaves.",
    "That wisp is telling everyone about you. In glows.",
    "Softer than soup! And twice as warming.",
    "Another lantern lit on its way home. The dark keeps losing.",
    "That one waved until it was only a warm spot in the air.",
]

const DESCEND_LINES := [
    "Down we go! I will hold the map. And your sleeve. Lightly.",
    "New floor, same wonderful you. The stairs approve.",
    "Mind the first step. It is dramatic and loves attention.",
    "Deeper still! The cozy thickens most beautifully.",
    "I can smell adventure. Or soup. Either way, onward.",
    "Another floor, another blanket of moss. The forest shows off for you.",
    "Careful, the stairs are showing off their glow again.",
    "The forest grew a new floor while we weren't looking. It does that.",
    "I dusted the handrail. There is no handrail. I did it anyway.",
]

const SIGNS := [
    "Wander kindly. Rest often.",
    "Wisps: please stop losing yourselves.",
    "Free hugs. Ask the glowing one.",
    "Beware: excellent moss ahead.",
    "Stairs down. Or up. Perspective.",
    "This grove is swept daily.",
    "Lost? Me too. Lovely evening though.",
    "Nap often. The ferns insist.",
    "You are exactly where the cozy is.",
    "Sing softly. The walls hum along.",
    "Kevin the rock was here. Still reliable.",
    "No grumps past this point, by decree.",
    "Honk softly if you love lanterns.",
    "This way to the coziest moss. All ways, actually.",
    "Wisps guided home today: too many to count, happily.",
    "Below this point, every floor is a gift the forest wrapped twice.",
    "Deeper is warmer. Trust the stairwell.",
    "If you can read this, a wisp lightened it for you.",
]

## What the wishing pool murmurs back when a sparkle settles on the water.
const WISH_LINES := [
    "A ring of light rises from the water.",
    "The pool keeps your sparkle and sends warmth up your sleeve.",
    "Something below seems a little happier.",
    "The moss around the pool turns gold for a breath.",
]
