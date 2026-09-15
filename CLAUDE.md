# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Godot 4.7 3D "impossible chess" game: a 6×6 board hosting 36 puzzle levels, each an
unsolvable / player-always-loses scenario (domino tiling, Hamiltonian tour, NIM, orthogonal Latin
squares, …). Most levels intentionally implement no win condition. Level names and descriptions
are written in Chinese; the core `scripts/` files are commented in English.

- Main scene: `res://chess_board.tscn` (set in `project.godot`).
- No build or lint step — it is a plain Godot project (GL Compatibility renderer, Jolt physics).
  Open and run it in the Godot 4.7 editor.

## Running & testing

There is no `tests/` directory and no automated test runner. Levels are verified by running the
project in the editor and inspecting live state.

The repo bundles the **Godot AI MCP plugin** (`addons/godot_ai/`). With a running editor session
(the active project registers session `impossiblechess`), you can drive the game from Claude Code
via the `mcp__godot-ai__*` tools:

- `project_run` / `project_manage(op="stop")` — start / stop the game.
- `editor_manage(op="game_eval", {code})` — run GDScript in the live game (supports `await`).
  To start a single level directly:
  `get_tree().current_scene.board_selector._start_level(Vector2i(row, col))`.
- `logs_read(source="editor")` — surface GDScript parse errors after editing.

A GDScript parse error in a level script does **not** crash the game: `_load_levels()` silently
skips any script whose `load()` returns null. After editing, check `logs_read` for parse errors and
confirm the level actually loaded (e.g. `game_eval` reading `board_selector._levels`).

## Architecture

The core is a handful of `class_name` scripts under `scripts/`, plus one script per level in `levels/`.

### Threading model (the part that spans several files)

Every level runs as an independent **worker thread**. Player input is normalized into a `Move`
(`scripts/move.gd`: `from`, `to`, `action` = MOVE | KEY | EXIT, plus `direction`, `key`,
`mouse_cell`) and flows to the level thread through a shared pending slot guarded by a mutex
(`ChessBoard.request_move` writes it; `Level.waitmove` polls it).

A level's `referee()` **must not touch the scene tree**. It mutates the board through
`board.call_main_thread("method", [args])`, which `call_deferred`s onto the main thread and blocks
the worker on a semaphore until it returns. The base `Level` (`levels/level.gd`) supplies
`referee()`, `waitmove()`, `_judge_and_apply()`, `_is_move_allowed()`, and `_place_at`/`_remove_at`
for domino/piece placement levels. Level scripts override `referee()` (and sometimes
`_is_move_allowed()`).

Dragging is handled by `ChessPiece` (Area3D ray-picking): a drag release calls
`board.request_move(...)`; the referee then confirms via `apply_move` / `reject_move`.

### Level system

- One file per level: `levels/<row><col><name>.gd`, declaring `class_name Level_<row><col><name>`
  and `extends Level`. The two leading digits of the filename give the board square (row, col).
- `BoardSelector` discovers levels through `ProjectSettings.get_global_class_list()` (Godot's
  global class table), not a filesystem scan — so it also works in single-file exports.
  `class_name` registration is mandatory for a level to be found.
- `LEVEL_UNLOCKED` (a 6×6 bool grid) in `scripts/board_selector.gd` gates which squares are
  playable. New levels must be unlocked there to be reachable.
- Levels set `level_name` and `description` (Chinese) in `_init()`.

### Board & pieces

- `scripts/chess_board.gd` (`ChessBoard`): a `_cells[row][col]` grid of `Cell` (`piece`, `type`,
  `is_primary`). `place`/`remove`/`move`/`capture`/`swap_pieces` keep the grid and each piece's
  reverse marker (`piece.row`/`col`/`board`) in sync. Common level-facing helpers: `add_piece`,
  `place_domino`, `place_blocker`, `fill_queens`, `add_marker`, `show_cut_plane`/`clear_mesh`,
  `recolor`, `set_domino_counts`, `show_result`.
- Coordinates are `Vector2i(row, col)`; row maps to world X, col to world Z (`get_chess_position`,
  `world_to_cell`). `ChessUtils` (`scripts/chess_utils.gd`) holds movement patterns
  (`ORTHOGONAL`, `DIAGONAL`, `ADJACENT`, `KNIGHT`), validation, and random helpers.
- `ChessPiece` (`scripts/chess_piece.gd`) defines the `PieceType`/`PieceColor`/`Direction` enums
  and drag input; `draggable = false` makes a piece inert to clicks. `Domino` (`scripts/domino.gd`)
  extends it with polyomino pieces built from shape strings (`*` filled, space/dot empty, `/` new row).
- The HUD (`scripts/ui.gd`, `GameUI`) renders the level name, the `set_domino_counts` panel, and a
  static `description_panel` used for the per-level 说明 info and end-of-level results.

## GDScript gotchas

- `:=` fails to infer a type when the value is an untyped Variant (e.g. `var top := _piles[j] - 1`
  where `_piles` is an untyped `Array`). Annotate explicitly: `var top: int = _piles[j] - 1`.
- Cross-class enum members (e.g. `ChessPiece.PieceColor.RED`) are not constant expressions inside
  `const` arrays — use a `var` (see `Level._palette`).
- Keep each level's `class_name` and `extends` stable: the matching `.gd.uid` sidecar and the
  global class table depend on them.
- `board.call_main_thread("remove", [cell])` clears the grid synchronously (the piece node is
  `queue_free`d a frame later), so reading `board.get_piece` immediately after is safe.
