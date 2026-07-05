defmodule RetroHexChat.VirtualSpace.Maps.ArcaneLibraryV1 do
  @moduledoc """
  Arcane library map: a hushed hall of bookshelves and study desks. Skeleton
  definition — layout details land with the map expansion phase.
  """

  @spec definition() :: map()
  def definition do
    %{
      id: "arcane_library_v1",
      version: 1,
      width: 64,
      height: 48,
      tile_size: 16,
      spawn: [
        %{x: 8, y: 40, dir: "up"},
        %{x: 9, y: 40, dir: "up"},
        %{x: 10, y: 40, dir: "up"},
        %{x: 11, y: 40, dir: "up"}
      ],
      layers: %{floor: [], decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: 64, h: 1, kind: "wall"},
        %{x: 0, y: 47, w: 64, h: 1, kind: "wall"},
        %{x: 0, y: 1, w: 1, h: 46, kind: "wall"},
        %{x: 63, y: 1, w: 1, h: 46, kind: "wall"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 6, y: 38, w: 8, h: 4}
      ],
      interactables: [],
      seats: []
    }
  end
end
