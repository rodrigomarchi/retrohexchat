defmodule RetroHexChat.VirtualSpace.MapTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap

  @moduletag :unit

  @map_ids ~w(tavern_cafe_v1 guild_hall_v1 arcane_library_v1 garden_camp_v1)

  describe "get/1" do
    test "returns a definition for every registry id" do
      for map_id <- @map_ids do
        assert {:ok, definition} = SpaceMap.get(map_id)
        assert definition.id == map_id
        assert definition.tile_size == 16
        assert definition.width > 0 and definition.height > 0
        assert definition.spawn != []
      end
    end

    test "rejects an arbitrary id" do
      assert {:error, :unknown_map} = SpaceMap.get("castle_v9")
      assert {:error, :unknown_map} = SpaceMap.get("")
    end
  end

  describe "ids/0" do
    test "lists the four registry ids" do
      assert Enum.sort(SpaceMap.ids()) == Enum.sort(@map_ids)
    end
  end

  describe "collision_set/1" do
    test "expands collision rects into a set of blocked tiles" do
      definition = %{
        collision: [%{x: 1, y: 1, w: 2, h: 2, kind: "desk"}]
      }

      set = SpaceMap.collision_set(definition)

      assert MapSet.member?(set, {1, 1})
      assert MapSet.member?(set, {2, 2})
      refute MapSet.member?(set, {0, 0})
      assert MapSet.size(set) == 4
    end
  end

  describe "tavern_cafe_v1 consistency" do
    setup do
      {:ok, definition} = SpaceMap.get("tavern_cafe_v1")
      %{definition: definition, blocked: SpaceMap.collision_set(definition)}
    end

    test "spawns are inside bounds and off collision tiles", ctx do
      for spawn <- ctx.definition.spawn do
        assert spawn.x >= 0 and spawn.x < ctx.definition.width
        assert spawn.y >= 0 and spawn.y < ctx.definition.height
        refute MapSet.member?(ctx.blocked, {spawn.x, spawn.y})
        assert spawn.dir in ~w(up down left right)
      end
    end

    test "zones fit inside the map bounds", ctx do
      for zone <- ctx.definition.zones do
        assert zone.x >= 0 and zone.y >= 0
        assert zone.x + zone.w <= ctx.definition.width
        assert zone.y + zone.h <= ctx.definition.height
      end
    end

    test "seats do not overlap each other", ctx do
      tiles = Enum.map(ctx.definition.seats, &{&1.x, &1.y})
      assert length(tiles) == length(Enum.uniq(tiles))
    end

    test "interactable ids are unique", ctx do
      ids = Enum.map(ctx.definition.interactables, & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end
  end
end
