defmodule RetroHexChat.VirtualSpace.Maps.GuildHallV1 do
  @moduledoc """
  Guild hall map: a stone great-hall for larger gatherings. Skeleton
  definition — layout details land with the map expansion phase.
  """

  @spec definition() :: map()
  def definition do
    %{
      id: "guild_hall_v1",
      version: 1,
      width: 64,
      height: 48,
      tile_size: 16,
      spawn: [
        %{x: 32, y: 24, dir: "down"},
        %{x: 33, y: 24, dir: "down"},
        %{x: 32, y: 25, dir: "down"},
        %{x: 33, y: 25, dir: "down"}
      ],
      layers: %{floor: [], decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: 64, h: 1, kind: "wall"},
        %{x: 0, y: 47, w: 64, h: 1, kind: "wall"},
        %{x: 0, y: 1, w: 1, h: 46, kind: "wall"},
        %{x: 63, y: 1, w: 1, h: 46, kind: "wall"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 30, y: 22, w: 6, h: 6}
      ],
      interactables: [],
      seats: []
    }
  end
end
