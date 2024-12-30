# tilemap editor

This is a simple tilemap editor. It is specialized for my personal projects, and
you will likely find bugs and quirks when using it outside of my assumptions
(which are explained neither here nor in the code). If anything, it may at least
be an interesting source example of how to design such a tool.

This project is compatible with at least the Jai 0.2.004 toolchain.

# Usage

Compile with `jai te.jai`; run `./te` to see the usage instructions. You can
either load a tileset and blank tilemap or load a previously-exported tilemap.

**Note:** tilemap schema is currently subject to change without a corresponding
schema version bump.

## Controls

- `ESC`: quit the program (no prompt to save your work!)
- `TAB`: change editor focus between tileset and tilemap
- `a`: if the editor focus is the tileset, mark the tile under cursor as active
  for painting; if the editor focus is the tilemap, paint with the active tool
- `c`: if active tool is tileset painter, change the tileset highlight color;
  if active tool is collision painter, change the collision highlight color
- `h, j, k, l`: move tile cursor left, down, up, right
- `q`: hide collision on tilemap
- `s`: export the tilemap to the current working directory
- `t`: switch tool between tileset painter and collision painter
- `x`: if the editor focus is the tileset, set no active tile; if the editor
  focus is the tilemap, delete the tile (tileset tile or collision, depending
  on the active tool) under cursor

# Resources

`data/buch-outdoor.png` is a file used for testing, borrowed from the
[tiled editor](https://github.com/mapeditor/tiled).

`data/SpaceMono-Regular.ttf` is a monospace font provided by Google. Its
license is [here](https://openfontlicense.org).

# TODO

1. add spawn annotations, door annotations, etc., like collision?
1. load in tileset properties, annotate tileset tiles, export annotations
1. implement tilemap undo-paint feature
1. add ability to select tilemap areas and then paint or delete
1. make the UI layout more robust (currently very sensitive to tileset size)
