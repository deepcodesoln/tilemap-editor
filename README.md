# tilemap editor

This is a simple tilemap editor. It is specialized for my personal projects, and
you will likely find bugs and quirks when using it outside of my assumptions
(which are explained neither here nor in the code). If anything, it may at least
be an interesting source example of how to design such a tool.

This project is compatible with at least the Jai 0.2.002 toolchain.

# Usage

Compile with `jai main.jai`; run `./main` to see the usage instructions.

## Controls

**Tileset Mode**

In tileset mode, you can use the mouse to select tiles from the tileset and then
paint on the tilemap. `c` will change the tileset highlight color.

**Collision Mode**

In collision mode, you can use the mouse to mark tiles in the tilemap as
collision tiles. `c` will change the collision highlight color.

# Resources

`data/buch-outdoor.png` is a file used for testing, borrowed from the
[tiled editor](https://github.com/mapeditor/tiled).

`data/SpaceMono-Regular.ttf` is a monospace font provided by Google. Its
license is [here](https://openfontlicense.org).

# TODO

1. paint with collision tiles
1. export tilemap and collision map
1. add spawn tiles, door tiles, etc.?
