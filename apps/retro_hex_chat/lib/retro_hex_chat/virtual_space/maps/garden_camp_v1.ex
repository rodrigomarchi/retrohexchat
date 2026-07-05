defmodule RetroHexChat.VirtualSpace.Maps.GardenCampV1 do
  @moduledoc """
  Garden camp map: an open-air campfire clearing among hedges. Skeleton
  definition — layout details land with the map expansion phase.
  """

  @spec definition() :: map()
  def definition do
    %{
      id: "garden_camp_v1",
      version: 1,
      width: 64,
      height: 48,
      tile_size: 16,
      spawn: [
        %{x: 20, y: 20, dir: "down"},
        %{x: 21, y: 20, dir: "down"},
        %{x: 22, y: 20, dir: "down"},
        %{x: 23, y: 20, dir: "down"}
      ],
      layers: %{floor: [], decor: [], above: []},
      collision: [
        %{x: 0, y: 0, w: 64, h: 1, kind: "hedge"},
        %{x: 0, y: 47, w: 64, h: 1, kind: "hedge"},
        %{x: 0, y: 1, w: 1, h: 46, kind: "hedge"},
        %{x: 63, y: 1, w: 1, h: 46, kind: "hedge"}
      ],
      zones: [
        %{id: "spawn", kind: "spawn", x: 18, y: 18, w: 8, h: 6}
      ],
      interactables: [],
      seats: []
    }
  end
end
