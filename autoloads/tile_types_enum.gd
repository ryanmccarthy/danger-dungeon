class_name TileTypes

const RETURN = "R"
const ENCOUNTER = " "
const SAFE = "S"
const EVENT = "E"
const WALL = "#"

## Floor-to-floor stairs. Both are walkable (everything that isn't WALL is), and
## DungeonBuilder deliberately gives them no collider — the party has to be able
## to stand on the tile for it to fire. R stays the only way back to campus.
const STAIR_UP = "<"
const STAIR_DOWN = ">"
