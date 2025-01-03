#import "Basic"()(MEMORY_DEBUGGER = (OS != .ANDROID));
File           :: #import "File";
Input          :: #import "Input";
Math           :: #import "Math";
Simp           :: #import "Simp";
WindowCreation :: #import "Window_Creation";

EditorFocus :: enum {
  TILESET :: 0;
  TILEMAP;
}

Tool :: enum {
  TILESET_PAINTER :: 0;
  COLLISION_PAINTER;
}

SUPPORTED_TILEMAP_VERSION: u16 = 0;

// The pane widths are intentionally evenly divisible by 16.
TILESET_PANE_WIDTH_PX :: 400;
TILEMAP_PANE_WIDTH_PX :: 608;
DIVIDER_WIDTH_PX :: 2;
WINDOW_WIDTH_PX :: TILESET_PANE_WIDTH_PX + TILEMAP_PANE_WIDTH_PX + DIVIDER_WIDTH_PX;
WINDOW_HEIGHT_PX :: 650;
TRAY_TEXT_PADDING_PX :: 4;

TILE_BORDER_WIDTH_PX :: 1;
MAX_TILEMAP_HEIGHT_PX :: 600;

TILE_HIGHLIGHT_COLORS :: Math.Vector4.[LIGHT_BLUE, GREEN];
TILE_HIGHLIGHT_COLOR_NAMES :: string.["light blue", "green"];
COLLISION_COLORS :: Math.Vector4.[YELLOW, RED];
COLLISION_COLOR_NAMES :: string.["yellow", "red"];

TARGET_FRAME_TIME_S :: 0.0333;

COLLISION_BIT: u16 = 0x1000;

WHITE       :: Math.Vector4.{1, 1, 1, 1};
BLACK       :: Math.Vector4.{0, 0, 0, 1};
GRAY        :: Math.Vector4.{0.7, 0.7, 0.7, 1};
RED         :: Math.Vector4.{1, 0, 0, 1};
YELLOW      :: Math.Vector4.{1, 1, 0, 1};
GREEN       :: Math.Vector4.{0, 1, 0, 1};
LIGHT_BLUE  :: Math.Vector4.{0.22, 0.88, 0.86, 1};
OCEAN       :: Math.Vector4.{0.2, 0.3, 0.3, 1.0};
LIGHT_OCEAN :: Math.Vector4.{0.25, 0.35, 0.35, 1.0};
DARK_OCEAN  :: Math.Vector4.{0.1, 0.2, 0.2, 1.0};

// `export_tilemap` is sensitive to type byte sizes here. Check that
// implementation if changing any types here.
g_tileset_pathname: string;
g_tray_height: s64;
g_should_quit: bool;
g_tileset: Simp.Texture;
g_tiles: [..] Simp.Texture;
g_tile_width: s64;
g_tile_height: s64;
g_font: *Simp.Dynamic_Font;
g_tileset_cursor_idx := 0;
g_tileset_active_idx := -1;
g_editor_focus := EditorFocus.TILESET;
g_tool := Tool.TILESET_PAINTER;
g_hide_collision := false;
g_tile_highlight_colors_idx := 0;
g_collision_colors_idx := 0;
g_tilemap_width := -1;
g_tilemap_height := -1;
g_tilemap_x := -1;
g_tilemap_y := -1;
g_tilemap_tiles: [] u16 = ---;
g_tilemap_cursor_idx := 0;

main :: () {
  window := WindowCreation.create_window(
    window_name="tilemap editor", width=WINDOW_WIDTH_PX, height=WINDOW_HEIGHT_PX
  );
  Simp.set_render_target(window);

  g_font = Simp.get_font_at_size("data", "SpaceMono-Regular.ttf", 16);
  if !g_font {
    print("failed to load font\n");
    return;
  }
  g_tray_height = g_font.character_height + 2 * TRAY_TEXT_PADDING_PX;

  ok := init_from_cmd();
  if !ok return;

  start_time: float64;
  while (!g_should_quit) {
    start_time = seconds_since_init();
    reset_temporary_storage();

    Input.update_window_events();
    handle_input();

    Simp.clear_render_target(OCEAN.x, OCEAN.y, OCEAN.z, OCEAN.w);

    draw_tileset_pane();
    draw_tray();
    draw_tilemap();

    Simp.swap_buffers(window);
    dt := seconds_since_init() - start_time;
    if dt < TARGET_FRAME_TIME_S {
      sleep_milliseconds(cast(s32)((TARGET_FRAME_TIME_S - dt) * 1000));
    }
  }
}

init_from_cmd :: () -> success: bool {
  cmd_args := get_command_line_arguments();
  if !(cmd_args.count == 2 || cmd_args.count == 4) {
    print("usage:\n% tileset.png tile_width_px tile_height_px\n% tilemap.bin\n", cmd_args[0], cmd_args[0]);
    return false;
  }

  if cmd_args.count == 2 {
    return init_from_tilemap(cmd_args);
  } else {
    return init_from_tileset(cmd_args);
  }
}

init_from_tilemap :: (cmd_args: [] string) -> bool {
  tilemap, ok := File.file_open(cmd_args[1]);

  if !ok {
    print("failed to open tilemap to load from\n");
    return false;
  }

  bytes_read: s64;
  version: u16;
  num_bytes := size_of(type_of(version));
  ok, bytes_read = File.file_read(*tilemap, *version, num_bytes);
  if version != SUPPORTED_TILEMAP_VERSION {
    print(tprint("supported tilemap version % doesn't match parsed version %\n", SUPPORTED_TILEMAP_VERSION, version));
    return false;
  }
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  tileset_filename_length: s64;
  num_bytes = size_of(type_of(tileset_filename_length));
  ok, bytes_read = File.file_read(*tilemap, *tileset_filename_length, num_bytes);
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  g_tileset_pathname.data = cast(*u8)alloc(tileset_filename_length);
  g_tileset_pathname.count = tileset_filename_length;
  ok, bytes_read = File.file_read(*tilemap, g_tileset_pathname.data, tileset_filename_length);
  if !ok || bytes_read != tileset_filename_length {
    print("failed to read value or didn't read enough bytes\n");
  }

  num_bytes = size_of(type_of(g_tile_width));
  ok, bytes_read = File.file_read(*tilemap, *g_tile_width, num_bytes);
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  num_bytes = size_of(type_of(g_tile_height));
  ok, bytes_read = File.file_read(*tilemap, *g_tile_height, num_bytes);
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  tilemap_width_tiles: s64;
  num_bytes = size_of(type_of(tilemap_width_tiles));
  ok, bytes_read = File.file_read(*tilemap, *tilemap_width_tiles, num_bytes);
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  tilemap_height_tiles: s64;
  num_bytes = size_of(type_of(tilemap_height_tiles));
  ok, bytes_read = File.file_read(*tilemap, *tilemap_height_tiles, num_bytes);
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  tilemap_length := tilemap_width_tiles * tilemap_height_tiles;
  g_tilemap_tiles = NewArray(tilemap_length, u16, initialized=false);
  num_bytes = tilemap_length * size_of(u16);
  ok, bytes_read = File.file_read(*tilemap, cast(*u8)g_tilemap_tiles.data, num_bytes);
  if !ok || bytes_read != num_bytes {
    print("failed to read value or didn't read enough bytes\n");
  }

  // Load tileset.
  bitmap: Simp.Bitmap;
  defer Simp.deinit(*bitmap);
  ok = Simp.bitmap_load(*bitmap, g_tileset_pathname);
  if !ok {
    print("failed to make bitmap from tileset\n");
    return false;
  }

   ok = Simp.texture_load_from_bitmap(*g_tileset, *bitmap);
   if !ok {
     print("failed to load texture from bitmap\n");
     return false;
   }

  // Check that tile size evenly divides tileset.
  if (g_tileset.width % g_tile_width) || (g_tileset.height % g_tile_height) {
    print(
      "tile width and height must evenly divide tileset width and height (%, %)\n",
      g_tileset.width, g_tileset.height
    );
    return false;
  }

  // Split the tilemap into individual tiles.
  array_reset(*g_tiles);
  g_tiles = bitmap_to_tiles(bitmap, g_tile_width, g_tile_height);

  // Set up tilemap properties.
  g_tilemap_width = TILEMAP_PANE_WIDTH_PX - TILEMAP_PANE_WIDTH_PX % g_tile_width;
  g_tilemap_height = MAX_TILEMAP_HEIGHT_PX - MAX_TILEMAP_HEIGHT_PX % g_tile_height;
  x_padding := (WINDOW_WIDTH_PX - g_tileset.width - DIVIDER_WIDTH_PX - g_tilemap_width) / 2;
  y_padding := (WINDOW_HEIGHT_PX - g_tray_height - DIVIDER_WIDTH_PX - g_tilemap_height) / 2;
  g_tilemap_x = g_tileset.width + DIVIDER_WIDTH_PX + x_padding;
  g_tilemap_y = g_tray_height + TRAY_TEXT_PADDING_PX + DIVIDER_WIDTH_PX + y_padding;

  return true;
}

init_from_tileset :: (cmd_args: [] string) -> bool {
  g_tileset_pathname = cmd_args[1];

  // Load tileset.
  bitmap: Simp.Bitmap;
  defer Simp.deinit(*bitmap);
  ok := Simp.bitmap_load(*bitmap, cmd_args[1]);
  if !ok {
    print("failed to make bitmap from tileset\n");
    return false;
  }

  ok = Simp.texture_load_from_bitmap(*g_tileset, *bitmap);
  if !ok {
    print("failed to load texture from bitmap\n");
    return false;
  }

  // Check that tile size evenly divides tileset.
  remainder: string;
  g_tile_width, ok, remainder = string_to_int(cmd_args[2], T=s32);
  if ok && remainder.count == 0 {
    g_tile_height, ok, remainder = string_to_int(cmd_args[3], T=s32);
  }
  if !ok {
    print("failed to convert tileset dimensions from CLI to ints\n");
    return false;
  }
  if remainder.count != 0 {
    print("tile width and height arguments must parse entirely to s32\n");
    return false;
  }
  if (g_tileset.width % g_tile_width) || (g_tileset.height % g_tile_height) {
    print(
      "tile width and height must evenly divide tileset width and height (%, %)\n",
      g_tileset.width, g_tileset.height
    );
    return false;
  }

  // Split the tilemap into individual tiles.
  array_reset(*g_tiles);
  g_tiles = bitmap_to_tiles(bitmap, g_tile_width, g_tile_height);

  // Set up tilemap properties.
  // TODO(orphen) make these user-provided.
  g_tilemap_width = TILEMAP_PANE_WIDTH_PX - TILEMAP_PANE_WIDTH_PX % g_tile_width;
  g_tilemap_height = MAX_TILEMAP_HEIGHT_PX - MAX_TILEMAP_HEIGHT_PX % g_tile_height;
  x_padding := (WINDOW_WIDTH_PX - TILESET_PANE_WIDTH_PX - DIVIDER_WIDTH_PX - g_tilemap_width) / 2;
  y_padding := (WINDOW_HEIGHT_PX - g_tray_height - DIVIDER_WIDTH_PX - g_tilemap_height) / 2;
  g_tilemap_x = TILESET_PANE_WIDTH_PX + DIVIDER_WIDTH_PX + x_padding;
  g_tilemap_y = g_tray_height + DIVIDER_WIDTH_PX + y_padding;

  tilemap_width_tiles := g_tilemap_width / g_tile_width;
  tilemap_height_tiles := g_tilemap_height / g_tile_height;
  tilemap_num_tiles := tilemap_width_tiles * tilemap_height_tiles;
  g_tilemap_tiles = NewArray(tilemap_num_tiles, u16);

  return true;
}

handle_input :: () {
  for event : Input.events_this_frame {
    if event.type == .QUIT {
      g_should_quit = true;
      break;
    }

    if event.key_code == .ESCAPE {
      if event.key_pressed {
        g_should_quit = true;
        break;
      }
    } else if event.key_code == .TAB && event.key_pressed {
      if g_editor_focus == .TILESET g_editor_focus = .TILEMAP;
      else if g_editor_focus == .TILEMAP g_editor_focus = .TILESET;
    } else if event.key_code == #char "A" && event.key_pressed {
      if g_editor_focus == .TILESET {
        g_tileset_active_idx = g_tileset_cursor_idx;
      } else if g_editor_focus == .TILEMAP {
        if g_tool == .TILESET_PAINTER && g_tileset_active_idx >= 0 {
          // We reserve `0` to mean no tile.
          g_tilemap_tiles[g_tilemap_cursor_idx] =
            (g_tilemap_tiles[g_tilemap_cursor_idx] & COLLISION_BIT) + cast(u16)(g_tileset_active_idx + 1);
        } else if g_tool == .COLLISION_PAINTER {
          g_tilemap_tiles[g_tilemap_cursor_idx] |= COLLISION_BIT;
        }
      }
    } else if event.key_code == #char "C" && event.key_pressed {
      if g_tool == .TILESET_PAINTER {
        g_tile_highlight_colors_idx = (g_tile_highlight_colors_idx + 1) % TILE_HIGHLIGHT_COLORS.count;
      } else if g_tool == .COLLISION_PAINTER {
        g_collision_colors_idx = (g_collision_colors_idx + 1) % COLLISION_COLORS.count;
      }
    } else if event.key_code == #char "H" && event.key_pressed {
      if g_editor_focus == .TILESET {
        width_tiles := g_tileset.width / g_tile_width;
        x, y := get_tileset_tile_at(g_tileset_cursor_idx);
        if x - 1 >= 0 g_tileset_cursor_idx -= 1;
      } else if g_editor_focus == .TILEMAP {
        width_tiles := g_tilemap_width / g_tile_width;
        x, y := get_tilemap_tile_at(g_tilemap_cursor_idx);
        if x - 1 >= 0 g_tilemap_cursor_idx -= 1;
      }
    } else if event.key_code == #char "J" && event.key_pressed {
      if g_editor_focus == .TILESET {
        tiles_per_row := g_tileset.width / g_tile_width;
        height_tiles := g_tileset.height / g_tile_height;
        x, y := get_tileset_tile_at(g_tileset_cursor_idx);
        if y + 1 < height_tiles g_tileset_cursor_idx += tiles_per_row;
      } else if g_editor_focus == .TILEMAP {
        tiles_per_row := g_tilemap_width / g_tile_width;
        height_tiles := g_tilemap_height / g_tile_height;
        x, y := get_tilemap_tile_at(g_tilemap_cursor_idx);
        if y + 1 < height_tiles g_tilemap_cursor_idx += tiles_per_row;
      }
    } else if event.key_code == #char "K" && event.key_pressed {
      if g_editor_focus == .TILESET {
        tiles_per_row := g_tileset.width / g_tile_width;
        height_tiles := g_tileset.height / g_tile_height;
        x, y := get_tileset_tile_at(g_tileset_cursor_idx);
        if y - 1 >= 0 g_tileset_cursor_idx -= tiles_per_row;
      } else if g_editor_focus == .TILEMAP {
        tiles_per_row := g_tilemap_width / g_tile_width;
        height_tiles := g_tilemap_height / g_tile_height;
        x, y := get_tilemap_tile_at(g_tilemap_cursor_idx);
        if y - 1 >= 0 g_tilemap_cursor_idx -= tiles_per_row;
      }
    } else if event.key_code == #char "L" && event.key_pressed {
      if g_editor_focus == .TILESET {
        tiles_per_row := g_tileset.width / g_tile_width;
        width_tiles := g_tileset.width / g_tile_width;
        x, y := get_tileset_tile_at(g_tileset_cursor_idx);
        if x + 1 < tiles_per_row g_tileset_cursor_idx += 1;
      } else if g_editor_focus == .TILEMAP {
        tiles_per_row := g_tilemap_width / g_tile_width;
        width_tiles := g_tilemap_width / g_tile_width;
        x, y := get_tilemap_tile_at(g_tilemap_cursor_idx);
        if x + 1 < tiles_per_row g_tilemap_cursor_idx += 1;
      }
    } else if event.key_code == #char "Q" && event.key_pressed {
      g_hide_collision ^= true;
    } else if event.key_code == #char "S" && event.key_pressed {
      exported_filename, ok := export_tilemap(g_tileset_pathname, g_tilemap_tiles);
      if !ok {
        print("failed to export tilemap\n");
      } else {
        print(tprint("exported tilemap to %\n", exported_filename));
      }
    } else if event.key_code == #char "T" && event.key_pressed {
      if g_tool == .TILESET_PAINTER {
        g_tool = .COLLISION_PAINTER;
      } else if g_tool == .COLLISION_PAINTER {
        g_tool = .TILESET_PAINTER;
      }
    } else if event.key_code == #char "X" && event.key_pressed {
      if g_editor_focus == .TILESET {
        g_tileset_active_idx = -1;
      } else if g_editor_focus == .TILEMAP {
        if g_tool == .TILESET_PAINTER {
          g_tilemap_tiles[g_tilemap_cursor_idx] &= COLLISION_BIT;
        } else if g_tool == .COLLISION_PAINTER {
          g_tilemap_tiles[g_tilemap_cursor_idx] &= ~COLLISION_BIT;
        }
      }
    }
  }
}

draw_tileset_pane :: () {
  // Vertical divider.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    cast(float)TILESET_PANE_WIDTH_PX, xx (g_tray_height + TRAY_TEXT_PADDING_PX),
    xx (TILESET_PANE_WIDTH_PX + DIVIDER_WIDTH_PX), xx WINDOW_HEIGHT_PX,
    DARK_OCEAN
  );

  // Tile set.
  Simp.set_shader_for_images(*g_tileset);
  Simp.immediate_quad(
    0.0, xx (WINDOW_HEIGHT_PX - g_tileset.height),
    xx g_tileset.width, xx WINDOW_HEIGHT_PX,
    WHITE
  );

  // Horizontal divider.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    0.0, xx (WINDOW_HEIGHT_PX - g_tileset.height),
    xx TILESET_PANE_WIDTH_PX, xx (WINDOW_HEIGHT_PX - g_tileset.height - 2),
    DARK_OCEAN
  );

  // Border around active tile in tileset.
  if g_tileset_active_idx >= 0 {
    Simp.set_shader_for_color();
    x, y := get_tileset_tile_at(g_tileset_active_idx);
    border_x1 := x * g_tile_width;
    border_y1 := WINDOW_HEIGHT_PX - (y * g_tile_height) - g_tile_height;
    immediate_outline(
      border_x1, border_y1,
      border_x1 + g_tile_width, border_y1 + g_tile_height,
      TILE_BORDER_WIDTH_PX,
      TILE_HIGHLIGHT_COLORS[g_tile_highlight_colors_idx]
    );
  }

  // Highlight cursor tile in tileset.
  Simp.set_shader_for_color(enable_blend=true);
  x, y := get_tileset_tile_at(g_tileset_cursor_idx);
  border_x1 := x * g_tile_width;
  border_y1 := WINDOW_HEIGHT_PX - (y * g_tile_height) - g_tile_height;
  color := TILE_HIGHLIGHT_COLORS[g_tile_highlight_colors_idx];
  color.w = 0.5;
  Simp.immediate_quad(
    cast(float)border_x1, xx border_y1,
    xx (border_x1 + g_tile_width), xx (border_y1 + g_tile_height),
    color
  );

  // Lines of text.
  text := tprint("tile width     : %", g_tile_width);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - g_font.character_height,
    WHITE
  );

  text = tprint("tile height    : %", g_tile_height);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 2),
    WHITE
  );

  x, y = get_tileset_tile_at(g_tileset_cursor_idx);
  text = tprint("cursor tile    : % (%, %)", g_tileset_cursor_idx, x, y);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 3),
    WHITE
  );

  if g_tileset_active_idx == -1 {
    text = tprint("active tile    : none");
  } else {
    x, y = get_tileset_tile_at(g_tileset_active_idx);
    text = tprint("active tile    : % (%, %)", g_tileset_active_idx, x, y);
  }
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 4),
    WHITE
  );

  tool := ifx g_tool == .TILESET_PAINTER then tprint("tileset painter") else tprint("collision painter");
  text = tprint("tool:          : %", tool);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 5),
    WHITE
  );

  text = tprint("tile highlight : %", TILE_HIGHLIGHT_COLOR_NAMES[g_tile_highlight_colors_idx]);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 6),
    WHITE
  );

  text = tprint("collision color: %", COLLISION_COLOR_NAMES[g_collision_colors_idx]);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 7),
    WHITE
  );

  text = tprint("collision shown: %", !g_hide_collision);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 8),
    WHITE
  );

  focus := ifx g_editor_focus == .TILESET then tprint("tileset") else tprint("tilemap");
  text = tprint("editor focus   : %", focus);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, WINDOW_HEIGHT_PX - g_tileset.height - (g_font.character_height * 9),
    WHITE
  );
}

draw_tray :: () {
  // Horizontal divider.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    0.0, xx (g_tray_height + TRAY_TEXT_PADDING_PX),
    xx WINDOW_WIDTH_PX, xx (g_tray_height + TRAY_TEXT_PADDING_PX + DIVIDER_WIDTH_PX),
    DARK_OCEAN
  );
}

draw_tilemap :: () {
  // Draw tilemap placeholder background.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    cast(float)g_tilemap_x, xx g_tilemap_y,
    xx (g_tilemap_x + g_tilemap_width), xx (g_tilemap_y + g_tilemap_height),
    LIGHT_OCEAN
  );

  // Draw tilemap.
  for _tileset_idx, tilemap_idx: g_tilemap_tiles {
    if !_tileset_idx continue; // `0` means no tile, no collision.

    tilemap_idx_x := tilemap_idx % (g_tilemap_width / g_tile_width);
    tilemap_idx_y := tilemap_idx / (g_tilemap_width / g_tile_width);
    tilemap_x := g_tilemap_x + tilemap_idx_x * g_tile_width;
    tilemap_y := g_tilemap_y + g_tilemap_height - tilemap_idx_y * g_tile_height - g_tile_height;

    if _tileset_idx & ~COLLISION_BIT {
      tileset_idx := (_tileset_idx & ~COLLISION_BIT) - 1;
      Simp.set_shader_for_images(*g_tiles[tileset_idx]);
      Simp.immediate_quad(
        cast(float)tilemap_x, xx tilemap_y,
        xx (tilemap_x + g_tile_width), xx (tilemap_y + g_tile_height),
        WHITE
      );
    }
    if _tileset_idx & COLLISION_BIT && !g_hide_collision {
      color := COLLISION_COLORS[g_collision_colors_idx];
      color.w = 0.5;
      Simp.set_shader_for_color(enable_blend=true);
      Simp.immediate_quad(
        cast(float)tilemap_x, xx tilemap_y,
        xx (tilemap_x + g_tile_width), xx (tilemap_y + g_tile_height),
        color
      );
    }
  }

  // Maybe draw active tileset tile under cursor; always draw outline.
  x, y := get_tilemap_tile_at(g_tilemap_cursor_idx);

  x1 := g_tilemap_x + x * g_tile_width;
  y1 := (g_tilemap_y + g_tilemap_height) - (y * g_tile_height) - g_tile_height;

  if g_tool == .TILESET_PAINTER && g_tileset_active_idx >= 0 {
    Simp.set_shader_for_images(*g_tiles[g_tileset_active_idx]);
    Simp.immediate_quad(
      cast(float)x1, xx y1,
      xx (x1 + g_tile_width), xx (y1 + g_tile_height),
      WHITE
    );
  } else if g_tool == .COLLISION_PAINTER {
    color := COLLISION_COLORS[g_collision_colors_idx];
    color.w = 0.5;
    Simp.set_shader_for_color(enable_blend=true);
    Simp.immediate_quad(
      cast(float)x1, xx y1, xx (x1 + g_tile_width), xx (y1 + g_tile_height),
      color
    );
  }

  immediate_outline(
    x1, y1,
    x1 + g_tile_width, y1 + g_tile_height,
    TILE_BORDER_WIDTH_PX,
    TILE_HIGHLIGHT_COLORS[g_tile_highlight_colors_idx]
  );
}

// Not guaranteed to give an index inside the tileset.
get_tileset_tile_at :: (x: s64, y: s64) -> tile_x: s64, tile_y: s64 {
  tile_x := x / g_tile_width;
  // Tile ID 0 is the top-left tile of the tileset.
  tile_y := (WINDOW_HEIGHT_PX - y) / g_tile_height;
  return tile_x, tile_y;
}

// Not guaranteed to give an index inside the tileset.
get_tileset_tile_at :: (idx: s64) -> tile_x: s64, tile_y: s64 {
  tile_y := idx / (g_tileset.width / g_tile_width);
  tile_x := idx % (g_tileset.width / g_tile_width);
  return tile_x, tile_y;
}

// Not guaranteed to give an index inside the tilemap.
get_tilemap_tile_at :: (x: s64, y: s64) -> tile_x: s64, tile_y: s64 {
  tile_x := (x - g_tilemap_x) / g_tile_width;
  // Tile ID 0 is the top-lef tile of the tilemap.
  tile_y := (g_tilemap_y + g_tilemap_height - y) / g_tile_height;
  return tile_x, tile_y;
}

// Not guaranteed to give an index inside the tilemap.
get_tilemap_tile_at :: (idx: s64) -> tile_x: s64, tile_y: s64 {
  tile_y := idx / (g_tilemap_width / g_tile_width);
  tile_x := idx % (g_tilemap_width / g_tile_width);
  return tile_x, tile_y;
}

immediate_outline :: (x1: s64, y1: s64, x2: s64, y2: s64, width: s64, color: Math.Vector4) {
  Simp.set_shader_for_color();

  // Drawn in left, top, right, bottom order.
  Simp.immediate_quad(
    cast(float)x1, xx y1,
    xx (x1 + width), xx y2,
    color
  );
  Simp.immediate_quad(
    cast(float)x1, xx (y2 - width),
    xx x2, xx y2,
    color
  );
  Simp.immediate_quad(
    cast(float)(x2 - width), xx y1,
    xx x2, xx y2,
    color
  );
  Simp.immediate_quad(
    cast(float)x1, xx y1,
    xx x2, xx (y1 + width),
    color
  );
}

// Assumes tile width and height divide the bitmap's width and height evenly.
bitmap_to_tiles :: (bitmap: Simp.Bitmap, tile_width: s64, tile_height: s64) -> [..] Simp.Texture {
  num_tiles := (bitmap.width * bitmap.height) / (tile_width * tile_height);
  tiles: [..] Simp.Texture;
  array_reserve(*tiles, num_tiles);

  tile_bitmap: Simp.Bitmap;
  Simp.bitmap_alloc(*tile_bitmap, xx tile_width, xx tile_height, bitmap.format);
  defer Simp.deinit(*tile_bitmap);

  bytes_per_pixel := bitmap.data.count / (bitmap.width * bitmap.height);
  tile_bytes := NewArray(tile_width * tile_height * bytes_per_pixel, u8);
  defer array_free(tile_bytes);

  tiles_per_row := bitmap.width / tile_width;
  for global_tile_idx: 0..num_tiles - 1 {
    global_tile_x := global_tile_idx % tiles_per_row;
    global_tile_y := global_tile_idx / tiles_per_row;
    for internal_tile_y: 0..tile_height - 1 {
      src := bitmap.data.data +
             ((tile_height * tile_width * bytes_per_pixel * tiles_per_row * global_tile_y) +
              (tiles_per_row * tile_width * bytes_per_pixel * internal_tile_y) +
              (global_tile_x * tile_width * bytes_per_pixel));
      dst := tile_bitmap.data.data + (tile_width * bytes_per_pixel * internal_tile_y);
      memcpy(dst, src, tile_width * bytes_per_pixel);
    }

    texture: Simp.Texture;
    ok := Simp.texture_load_from_bitmap(*texture, *tile_bitmap);
    if !ok print("failed to load texture from tile bitmap\n");
    array_add(*tiles, texture);
  }

  return tiles;
}

/**
 * Write tilemap out as binary in the following order.
 *
 * - format version (u16)
 * - tileset file name length (s64)
 * - tileset file name (u8 * above length)
 * - tile width in pixels (s64)
 * - tile height in pixels (s64)
 * - tilemap width in tiles (s64)
 * - tilemap height in tiles (s64)
 * - tilemap bytes (u16 * above length)
 *
 * Tilemap IDs are 2 bytes, encoded as follows:
 * - MSB (bit 15): 1: collision; 0: no collision
 * - bits 14 - 0 : tile ID; tile ID `0` means "no tile"
 */
export_tilemap :: (tileset_path: string, tilemap: [] u16) -> export_pathname: string, ok: bool {
  if g_tilemap_tiles.count <= 0 {
    print("can't export an empty tilemap\n");
    return "", false;
  }

  export_pathname :: "tilemap.bin";
  file, ok := File.file_open(export_pathname, for_writing=true);
  if !ok {
    print("error opening file for tilemap export\n");
    return "", false;
  }

  builder: String_Builder;
  init_string_builder(*builder);

  // Have to write from a variable, not a constant, since Jai may inline constants.
  tilemap_format_version := SUPPORTED_TILEMAP_VERSION;
  append(*builder, cast(*u8)*tilemap_format_version, size_of(type_of(tilemap_format_version)));
  append(*builder, cast(*u8)*tileset_path.count, size_of(type_of(tileset_path.count)));
  append(*builder, tileset_path.data, tileset_path.count);
  append(*builder, cast(*u8)*g_tile_width, size_of(type_of(g_tile_width)));
  append(*builder, cast(*u8)*g_tile_height, size_of(type_of(g_tile_height)));
  tilemap_width_tiles := g_tilemap_width / g_tile_width;
  append(*builder, cast(*u8)*tilemap_width_tiles, size_of(type_of(tilemap_width_tiles)));
  tilemap_height_tiles := g_tilemap_height / g_tile_height;
  append(*builder, cast(*u8)*tilemap_height_tiles, size_of(type_of(tilemap_height_tiles)));
  append(*builder, cast(*u8)g_tilemap_tiles.data, size_of(u16) * g_tilemap_tiles.count);

  buff := builder_to_string(*builder);
  defer free(buff);
  ok = File.file_write(*file, buff.data, buff.count);
  if !ok {
    print("error writing tilemap to file for tilemap export\n");
    return "", false;
  }

  File.file_close(*file);
  return export_pathname, ok;
}
