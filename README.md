# tilemap editor

This is a simple tilemap editor. It is specialized for my personal projects, and
you will likely find bugs and quirks when using it outside of my assumptions
(which are explained neither here nor in the code). If anything, it may at least
be an interesting source example of how to design such a tool.

This project is compatible with at least the Jai 0.2.004 toolchain.

# Usage

Compile with `jai te.jai`; run `./te` to see the usage instructions. You can
either load a tileset and blank tilemap or load a previously-exported tilemap.

**Note:** collision information is not currently exported; tilemap schema is
currently subject to change without a corresponding schema version bump.

## Controls

- `h`: hide collision on tilemap
- `m`: switch editor mode between tileset and collision
- `s`: export the tilemap to the current working directory
- `t`: switch tool between tile/collision painter and eraser

**Tileset Mode**

- mouse: select tiles from the tileset and paint them on the tilemap
- `c`: change the tileset highlight color

**Collision Mode**

- mouse: mark tiles in the tilemap as collision tiles
- `c`: change the collision highlight color

# Resources

`data/buch-outdoor.png` is a file used for testing, borrowed from the
[tiled editor](https://github.com/mapeditor/tiled).

`data/SpaceMono-Regular.ttf` is a monospace font provided by Google. Its
license is [here](https://openfontlicense.org).

# TODO

1. add spawn tiles, door tiles, etc.?
1. convert collision and tileset modes into tools (no modes, just tools)
