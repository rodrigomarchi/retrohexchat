defmodule RetroHexChat.VirtualSpace.Construct.LayoutTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.VirtualSpace.Construct.Layout
  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap

  @moduletag :unit

  setup do
    {:ok, base} = SpaceMap.get("construct")
    %{base: base, nobody: %{avatars: [], seated: MapSet.new()}}
  end

  defp place(base, items, kind, x, y, context, dir \\ "down") do
    Layout.edit(base, items, {:place, kind, x, y, dir}, context, "alice")
  end

  describe "the base Construct" do
    test "is an empty room with a gate back and four placeable kinds", %{base: base} do
      assert base.layers.decor |> Enum.map(& &1.tile) |> Enum.reject(&(&1 == "iso_star")) ==
               ["cst_exit"]

      assert base.sea != nil and base.slabs != []

      assert [%{id: "construct_exit", modal: %{kind: "confirm", action: "exit_construct"}}] =
               base.interactables

      assert base.catalog |> Map.keys() |> Enum.sort() == ~w(chair lamp table tree)
      assert base.catalog["chair"].seat
      assert base.catalog["lamp"].lights != []

      for {_kind, entry} <- base.catalog, {dir, tile} <- entry.tiles do
        assert dir in Layout.dirs()
        assert Map.has_key?(base.tiles, tile)
      end
    end

    test "reserves the gate, the ground in front of it and every spawn", %{base: base} do
      reserved = MapSet.new(base.reserved, &{&1.x, &1.y})
      %{x: gx, y: gy} = hd(base.interactables)

      for dx <- -1..1, dy <- -1..1, do: assert({gx + dx, gy + dy} in reserved)
      for spawn <- base.spawn, do: assert({spawn.x, spawn.y} in reserved)
    end
  end

  describe "edit/5 place" do
    test "places an item on free floor", %{base: base, nobody: nobody} do
      assert {:ok, [item]} = place(base, [], "table", 30, 30, nobody)
      assert %{kind: "table", x: 30, y: 30, dir: "down", placed_by: "alice"} = item
      assert is_binary(item.id)
    end

    test "refuses what the room cannot hold", %{base: base, nobody: nobody} do
      assert {:error, :unknown_kind} = place(base, [], "throne", 30, 30, nobody)
      assert {:error, :out_of_bounds} = place(base, [], "chair", -1, 10, nobody)
      assert {:error, :out_of_bounds} = place(base, [], "chair", base.width, 0, nobody)
      %{x: gx, y: gy} = hd(base.interactables)
      %{x: sx, y: sy} = hd(base.spawn)
      assert {:error, :reserved} = place(base, [], "chair", gx, gy, nobody)
      assert {:error, :reserved} = place(base, [], "chair", sx, sy, nobody)
      # The sky around the island is no floor to build on.
      assert {:error, :reserved} = place(base, [], "chair", 0, 0, nobody)
    end

    test "refuses a tile already taken by an item or a person", %{base: base, nobody: nobody} do
      {:ok, items} = place(base, [], "tree", 30, 30, nobody)
      assert {:error, :occupied} = place(base, items, "lamp", 30, 30, nobody)

      someone = %{nobody | avatars: [{32, 32}]}
      assert {:error, :someone_there} = place(base, [], "lamp", 32, 32, someone)
    end

    test "refuses past the room's limit", %{base: base, nobody: nobody} do
      base = %{base | max_items: 1}
      {:ok, items} = place(base, [], "tree", 30, 30, nobody)
      assert {:error, :full} = place(base, items, "tree", 31, 31, nobody)
    end

    test "refuses the piece that would wall somebody off from the gate", %{base: base} do
      # A ring around (35,35) with one gap at (35,34); closing it traps them.
      ring =
        for {x, y} <- [{34, 34}, {36, 34}, {34, 35}, {36, 35}, {34, 36}, {35, 36}, {36, 36}] do
          %{id: "r#{x}-#{y}", kind: "tree", x: x, y: y, dir: "down", placed_by: nil}
        end

      inside = %{avatars: [{35, 35}], seated: MapSet.new()}
      assert {:error, :would_trap} = place(base, ring, "tree", 35, 34, inside)
      assert {:ok, _items} = place(base, ring, "tree", 38, 38, inside)
    end
  end

  describe "edit/5 move, remove and rotate" do
    setup %{base: base, nobody: nobody} do
      {:ok, [chair]} = place(base, [], "chair", 30, 30, nobody)
      %{chair: chair}
    end

    test "moves an item to free floor and onto its own tile", ctx do
      assert {:ok, [moved]} =
               Layout.edit(
                 ctx.base,
                 [ctx.chair],
                 {:move, ctx.chair.id, 31, 30},
                 ctx.nobody,
                 "bob"
               )

      assert {moved.x, moved.y} == {31, 30}
      assert moved.placed_by == "alice"

      assert {:ok, _} =
               Layout.edit(
                 ctx.base,
                 [ctx.chair],
                 {:move, ctx.chair.id, 30, 30},
                 ctx.nobody,
                 "bob"
               )
    end

    test "removes and turns an item", ctx do
      assert {:ok, []} =
               Layout.edit(ctx.base, [ctx.chair], {:remove, ctx.chair.id}, ctx.nobody, "bob")

      assert {:ok, [%{dir: "right"}]} =
               Layout.edit(ctx.base, [ctx.chair], {:rotate, ctx.chair.id}, ctx.nobody, "bob")
    end

    test "leaves a chair alone while somebody sits in it", ctx do
      seated = %{ctx.nobody | seated: MapSet.new([Layout.seat_id(ctx.chair)])}

      for op <- [{:move, ctx.chair.id, 32, 32}, {:remove, ctx.chair.id}, {:rotate, ctx.chair.id}] do
        assert {:error, :seat_taken} = Layout.edit(ctx.base, [ctx.chair], op, seated, "bob")
      end
    end

    test "names an item that is not there", ctx do
      assert {:error, :unknown_item} =
               Layout.edit(ctx.base, [ctx.chair], {:remove, "nope"}, ctx.nobody, "bob")
    end
  end

  describe "apply/2" do
    test "puts each item on the map with what its kind brings", %{base: base, nobody: nobody} do
      {:ok, items} = place(base, [], "chair", 30, 30, nobody, "right")
      {:ok, items} = place(base, items, "lamp", 32, 32, nobody)
      map = Layout.apply(base, items)
      [chair, lamp] = items

      assert %{tile: "cst_chair_r", sort: "stand", item_id: chair_id} =
               Enum.find(map.layers.decor, &(&1[:item_id] == chair.id))

      assert chair_id == chair.id
      assert MapSet.member?(SpaceMap.collision_set(map), {32, 32})
      assert [%{id: seat_id, x: 30, y: 30, dir: "right"}] = map.seats
      assert seat_id == Layout.seat_id(chair)
      assert Enum.count(map.lights, &(&1.x == lamp.x and &1.y == lamp.y)) == 2
      assert length(map.items) == 2
    end
  end

  describe "normalize/2" do
    test "keeps stored items this build can draw on buildable floor", %{base: base} do
      raw = [
        %{"id" => "a", "kind" => "tree", "x" => 30, "y" => 30, "dir" => "right"},
        %{"id" => "b", "kind" => "throne", "x" => 31, "y" => 31},
        %{"id" => "c", "kind" => "lamp", "x" => 10, "y" => 10},
        %{"id" => "d", "kind" => "lamp", "x" => 30, "y" => 30},
        %{"id" => "e", "kind" => "chair", "x" => "7", "y" => 27},
        %{"id" => "f", "kind" => "chair", "x" => 29, "y" => 29, "dir" => "sideways"}
      ]

      assert [%{id: "a", dir: "right"}, %{id: "f", dir: "down"}] = Layout.normalize(base, raw)
    end
  end
end
