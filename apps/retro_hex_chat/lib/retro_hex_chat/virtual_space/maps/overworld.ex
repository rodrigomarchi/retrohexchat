defmodule RetroHexChat.VirtualSpace.Maps.Overworld do
  @moduledoc """
  Shared tile vocabulary for the outdoor maps, sourced from the human-made
  `overworld.png` sheet served at `/images/space/overworld.png`.

  Maps no longer ship traced pixel data: they reference tiles by semantic name,
  and each name resolves to a rectangle in a tileset sheet (`col`/`row` in tiles,
  `w`/`h` in tiles for multi-tile props). The client loads the sheet image once
  and slices it with `drawImage`, so the runtime art is the original pixel art.

  `tilesets/0` lists the sheets the client must load; `tiles/0` is the
  name → source-rect legend shared by every outdoor map.
  """

  @overworld_columns 40
  @character_columns 17

  @tiles %{
    # Ground / texture (1×1)
    "grass" => %{ts: "overworld", col: 5, row: 9},
    "grass_tuft" => %{ts: "overworld", col: 6, row: 9},
    "grass_worn" => %{ts: "overworld", col: 6, row: 10},
    "grass_dark" => %{ts: "overworld", col: 4, row: 16},
    "dirt" => %{ts: "overworld", col: 1, row: 30},
    "flowers" => %{ts: "overworld", col: 0, row: 8},
    # Small props (1×1)
    "bush" => %{ts: "overworld", col: 1, row: 14},
    "rock" => %{ts: "overworld", col: 7, row: 5},
    "rock_s" => %{ts: "overworld", col: 9, row: 5},
    "log_l" => %{ts: "overworld", col: 3, row: 5},
    "log_m" => %{ts: "overworld", col: 4, row: 5},
    "log_r" => %{ts: "overworld", col: 5, row: 5},
    # Pond (3×3 of 1×1 tiles)
    "pond_tl" => %{ts: "overworld", col: 2, row: 6},
    "pond_tm" => %{ts: "overworld", col: 3, row: 6},
    "pond_tr" => %{ts: "overworld", col: 4, row: 6},
    "pond_ml" => %{ts: "overworld", col: 2, row: 7},
    "pond_c" => %{ts: "overworld", col: 3, row: 7},
    "pond_mr" => %{ts: "overworld", col: 4, row: 7},
    "pond_bl" => %{ts: "overworld", col: 2, row: 8},
    "pond_bm" => %{ts: "overworld", col: 3, row: 8},
    "pond_br" => %{ts: "overworld", col: 4, row: 8},
    # Brown cliff autotile: left/middle/right columns × lip/face/base rows.
    # `lip` is the grass edge on top of the drop (walkable); `face`/`base` are the
    # exposed rock wall (blocked). Left/right variants cap the ends of a run and
    # double as the west/east vertical side faces of a plateau.
    "cliff_lip_l" => %{ts: "overworld", col: 4, row: 11},
    "cliff_lip_m" => %{ts: "overworld", col: 5, row: 11},
    "cliff_lip_r" => %{ts: "overworld", col: 6, row: 11},
    "cliff_face_l" => %{ts: "overworld", col: 4, row: 12},
    "cliff_face_m" => %{ts: "overworld", col: 5, row: 12},
    "cliff_face_r" => %{ts: "overworld", col: 6, row: 12},
    "cliff_base_l" => %{ts: "overworld", col: 4, row: 14},
    "cliff_base_m" => %{ts: "overworld", col: 5, row: 14},
    "cliff_base_r" => %{ts: "overworld", col: 6, row: 14},
    # Multi-tile props
    "tree" => %{ts: "overworld", col: 5, row: 16, w: 2, h: 2},
    "house" => %{ts: "overworld", col: 6, row: 0, w: 5, h: 5},
    "boulder" => %{ts: "overworld", col: 9, row: 11, w: 3, h: 2},
    "cave" => %{ts: "overworld", col: 7, row: 11, w: 1, h: 2}
  }

  @doc "Tilesets the client must load for an outdoor map."
  @spec tilesets() :: [map()]
  def tilesets do
    [
      %{
        id: "overworld",
        src: "/images/space/overworld.png",
        tile: 16,
        columns: @overworld_columns
      },
      %{
        id: "character",
        src: "/images/space/character.png",
        tile: 16,
        columns: @character_columns
      }
    ]
  end

  @doc "Semantic tile name → source rectangle in a tileset sheet."
  @spec tiles() :: %{optional(String.t()) => map()}
  def tiles, do: @tiles

  @doc "Whether a tile name exists in the shared vocabulary."
  @spec known?(String.t()) :: boolean()
  def known?(name), do: Elixir.Map.has_key?(@tiles, name)
end
