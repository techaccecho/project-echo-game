extends Node2D
## The abandoned fishing hut on the north-west shore of Level 1. The pack's
## fisherman's house, weathered down and half overgrown, with a door that
## opens onto world/fishing_hut_interior.tscn. Somewhere to sleep that is not
## another man's bed.
##
## The hut isn't y-sort-enabled itself, so it draws as one block against the
## player: whichever of the two has the larger y wins. The FishingHut node's
## own origin is the sort key, and it sits 20px north of Art, the building's
## actual bottom-left, so the player's collision (whose own origin sits above
## his feet) still reads as "further south" than the hut once he is pressed
## up against the front wall. See BlacksmithHouse for the same trick, tuned
## by hand for its own collision instead.
