#import "Basic"()(MEMORY_DEBUGGER = (OS != .ANDROID));
WindowCreation :: #import "Window_Creation";
Input :: #import "Input";
Math  :: #import "Math";
Simp  :: #import "Simp";

EditorMode :: enum {
  TILESET :: 0;
  COLLISION;
}

g_window_width := 1000;
g_window_height := 500;
g_tray_height: s64;
g_tray_text_padding := 4;
g_should_quit: bool;
g_tileset: Simp.Texture;
g_tiles: [..] Simp.Texture;
g_tile_width: s64;
g_tile_height: s64;
g_font: *Simp.Dynamic_Font;
g_selected_tile_idx: s64 = -1;
g_selected_tile_x: s64 = -1;
g_selected_tile_y: s64 = -1;
g_editor_mode := EditorMode.TILESET;

TILE_BORDER_WIDTH := 1;

WHITE      :: Math.Vector4.{1, 1, 1, 1};
BLACK      :: Math.Vector4.{0, 0, 0, 1};
LIGHT_BLUE :: Math.Vector4.{0.22, 0.88, 0.86, 1};

main :: () {
  window := WindowCreation.create_window(
    window_name="tilemap editor", width=g_window_width, height=g_window_height
  );
  Simp.set_render_target(window);

  ok := init_from_cmd();
  if !ok return;

  g_font = Simp.get_font_at_size("data", "SpaceMono-Regular.ttf", 16);
  if !g_font {
    print("failed to load font\n");
    return;
  }
  g_tray_height = g_font.character_height;

  while (!g_should_quit) {
    reset_temporary_storage();

    Input.update_window_events();
    mouse_x, mouse_y, ok := WindowCreation.get_mouse_pointer_position(window, right_handed=true);
    if !ok print("error: failed to get mouse pointer position\n");
    handle_input(mouse_x, mouse_y);

    Simp.clear_render_target(0.2, 0.3, 0.3, 1.0);

    draw_tileset_pane();
    draw_tray(mouse_x, mouse_y);
    draw_tilemap(mouse_x, mouse_y);

    Simp.swap_buffers(window);
  }
}

init_from_cmd :: () -> success: bool {
  cmd_args := get_command_line_arguments();
  if cmd_args.count != 4 {
    print("usage: % tileset.png tile_width_px tile_height_px\n", cmd_args[0]);
    return false;
  }

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
    print("failed to parse tile set dimensions\n");
    return false;
  }
  if remainder.count != 0 {
    print("tile width and height arguments must parse entirely to s32\n");
    return false;
  }
  if (g_tileset.width % g_tile_width) || (g_tileset.height % g_tile_height) {
    print(
      "tile width and height must evenly divide tile set width and height (%, %)\n",
      g_tileset.width, g_tileset.height
    );
    return false;
  }

  bitmap_to_tiles(bitmap, g_tile_width, g_tile_height);

  return true;
}

handle_input :: (mouse_x: s64, mouse_y: s64) {
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
    } else if event.key_code == #char "M" && event.key_pressed {
      if g_editor_mode == .COLLISION {
        g_editor_mode = .TILESET;
      } else {
        g_editor_mode = .COLLISION;
      }
    } else if event.key_code == .MOUSE_BUTTON_LEFT {
      if event.key_pressed {
        if g_editor_mode == .TILESET && coord_in_tileset(mouse_x, mouse_y) {
          g_selected_tile_x, g_selected_tile_y = get_tile_at(mouse_x, mouse_y);
          tiles_per_row := g_tileset.width / g_tile_width;
          g_selected_tile_idx = g_selected_tile_y * tiles_per_row + g_selected_tile_x;
        }
        break;
      }
    }
  }
}

draw_tileset_pane :: () {
  // Vertical divider.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    cast(float)g_tileset.width, xx (g_tray_height + g_tray_text_padding),
    xx (g_tileset.width + 2), xx g_window_height,
    BLACK
  );

  // Tile set.
  Simp.set_shader_for_images(*g_tileset);
  Simp.immediate_quad(
    0.0, xx (g_window_height - g_tileset.height),
    xx g_tileset.width, xx g_window_height,
    WHITE
  );

  // Border around selected tile set.
  if g_editor_mode == .TILESET && g_selected_tile_idx >= 0 {
    Simp.set_shader_for_color();
    border_x1 := g_selected_tile_x * g_tile_width;
    border_y1 := g_window_height - (g_selected_tile_y * g_tile_height) - g_tile_height;
    immediate_outline(
      border_x1, border_y1,
      border_x1 + g_tile_width, border_y1 + g_tile_height,
      TILE_BORDER_WIDTH,
      LIGHT_BLUE
    );
  }

  // Lines of text.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    0.0, xx (g_window_height - g_tileset.height),
    xx g_tileset.width, xx (g_window_height - g_tileset.height - 2),
    BLACK
  );

  text := tprint("tile width   : %", g_tile_width);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, g_window_height - g_tileset.height - g_font.character_height,
    WHITE
  );

  text = tprint("tile height  : %", g_tile_height);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, g_window_height - g_tileset.height - (g_font.character_height * 2),
    WHITE
  );

  if g_editor_mode != .TILESET {
    text = tprint("selected tile: n/a");
  } else if g_selected_tile_idx >= 0 {
    text = tprint("selected tile: %", g_selected_tile_idx);
  } else {
    text = tprint("selected tile: none");
  }
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, g_window_height - g_tileset.height - (g_font.character_height * 3),
    WHITE
  );

  mode := ifx g_editor_mode == .TILESET then tprint("tile set") else tprint("collision");
  text = tprint("editor mode  : %", mode);
  Simp.prepare_text(g_font, text);
  Simp.draw_prepared_text(
    g_font,
    0, g_window_height - g_tileset.height - (g_font.character_height * 4),
    WHITE
  );
}

draw_tray :: (mouse_x: s64, mouse_y: s64) {
  // Horizontal divider.
  Simp.set_shader_for_color();
  Simp.immediate_quad(
    0.0, xx (g_tray_height + g_tray_text_padding),
    xx g_window_width, xx (g_tray_height + 2),
    BLACK
  );

  // Maybe draw position in tile set.
  if coord_in_tileset(mouse_x, mouse_y) {
    tile_x, tile_y := get_tile_at(mouse_x, mouse_y);
    text := tprint("tile set: %, %", tile_x, tile_y);
    Simp.prepare_text(g_font, text);
    Simp.draw_prepared_text(
      g_font,
      0, g_tray_text_padding,
      WHITE
    );
  }
}

draw_tilemap :: (mouse_x: s64, mouse_y: s64) {
  if g_selected_tile_idx >= 0 && g_editor_mode == .TILESET && coord_in_tilemap(mouse_x, mouse_y) {
    Simp.set_shader_for_images(*g_tiles[g_selected_tile_idx]);
    x1 := mouse_x - mouse_x % g_tile_width;
    y1 := mouse_y - mouse_y % g_tile_height;
    Simp.immediate_quad(
      cast(float)x1, xx y1,
      xx (x1 + g_tile_width), xx (y1 + g_tile_height),
      WHITE
    );
  }
}

coord_in_tileset :: (x: s64, y: s64) -> bool {
  in := true;
  if x > g_tileset.width in = false;
  if y < g_window_height - g_tileset.height in = false;
  return in;
}

coord_in_tilemap :: (x: s64, y: s64) -> bool {
  in := true;
  if x <= g_tileset.width in = false;
  if y <= g_tray_height + g_tray_text_padding in = false;
  return in;
}

// Assumes `coord_in_tileset` returned `true` on same frame.
get_tile_at :: (x: s64, y: s64) -> tile_x: s64, tile_y: s64 {
  tiles_per_row := g_tileset.width / g_tile_width;
  tile_x := x / g_tile_width;
  // Tile ID 0 is the top-left tile of the tile set.
  tile_y := (g_window_height - y) / g_tile_height;
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
// Resets `g_tiles`.
bitmap_to_tiles :: (bitmap: Simp.Bitmap, tile_width: s64, tile_height: s64) {
  num_tiles := (bitmap.width * bitmap.height) / (tile_width * tile_height);
  array_reset(*g_tiles);
  array_reserve(*g_tiles, num_tiles);

  tile_bitmap: Simp.Bitmap;
  Simp.bitmap_alloc(*tile_bitmap, xx tile_width, xx tile_height, Simp.Texture_Format.RGBA8);
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
    array_add(*g_tiles, texture);
  }
}
