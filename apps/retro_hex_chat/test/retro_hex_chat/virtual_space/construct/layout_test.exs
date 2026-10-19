defmodule RetroHexChat.VirtualSpace.Construct.LayoutTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Catalog
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
    test "is an empty room with a gate back and a catalog of kinds", %{base: base} do
      assert base.layers.decor |> Enum.map(& &1.tile) |> Enum.reject(&(&1 == "iso_star")) ==
               ["cst_exit"]

      assert base.sea != nil and base.slabs != []

      assert [%{id: "construct_exit", modal: %{kind: "confirm", action: "exit_construct"}}] =
               base.interactables

      assert ~w(chair lamp table tree door die coin teleporter sign arcade board screen) --
               Map.keys(base.catalog) == []

      assert base.catalog["chair"].seat
      assert base.catalog["lamp"].lights != []
      refute base.catalog["teleporter"].blocks
      assert base.catalog["board"].only == ["channel"]

      for {_kind, entry} <- base.catalog do
        assert entry.group in ~w(furniture office garden gamer structure fun fair fantasy eot)
        layers = Enum.map(entry.layers, & &1.tiles)

        for tiles <- [entry.tiles | Map.values(entry.states) ++ layers], {dir, tile} <- tiles do
          assert dir in entry.dirs
          assert Map.has_key?(base.tiles, tile)
        end
      end

      # The End of Time's pieces are drawn from the End of Time's own sheet.
      assert ~w(construct endoftime) == Enum.map(base.tilesets, & &1.id)
      assert %{ts: "endoftime", frames: 8} = base.tiles["eot_morpheus"]
      assert base.catalog["sofa"].seats == [[0, 0], [0, 1]]
      assert base.catalog["eot_balrog"].size == [5, 2]

      # A piece that moves is a strip of frames on the Construct's own sheet,
      # and its mirror moves with it.
      assert %{frames: 6, period_ms: 1200} = base.tiles["cst_bell_tower"]
      assert %{frames: 6, flip_x: true} = base.tiles["cst_nu_r"]
      assert base.catalog["bell_tower"].group == "fantasy"
      assert base.catalog["big_top"].group == "fair"

      # The island's lamppost switches off; its unlit copy is the Construct's.
      lamp = base.catalog["eot_lamp"]
      assert lamp.use == "toggle_light"
      assert %{ts: "endoftime"} = base.tiles[lamp.tiles["down"]]
      assert %{ts: "construct"} = base.tiles[lamp.states["off"]["down"]]

      # Its gate of code is a gate to nowhere.
      assert base.catalog["eot_portal"].use == nil
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

  describe "use/5" do
    defp use_on(base, items, item, context, roll \\ fn _n -> 1 end),
      do: Layout.use(base, items, item.id, context, roll)

    test "switches a lamp off and back on, and its light with it", %{base: base, nobody: nobody} do
      {:ok, [lamp] = items} = place(base, [], "lamp", 30, 30, nobody)
      assert {:ok, [off] = items, :changed} = use_on(base, items, lamp, nobody)
      assert off.state == %{"on" => false}

      map = Layout.apply(base, items)
      refute Enum.any?(map.lights, &(&1.x == 30 and &1.y == 30))
      assert %{tile: "cst_lamp_off"} = Enum.find(map.layers.decor, &(&1[:item_id] == lamp.id))

      assert {:ok, [on], :changed} = use_on(base, items, off, nobody)
      assert on.state == %{"on" => true}
    end

    test "opens a door to walk through and refuses to close it on somebody", ctx do
      {:ok, [door] = items} = place(ctx.base, [], "door", 30, 30, ctx.nobody)
      assert MapSet.member?(SpaceMap.collision_set(Layout.apply(ctx.base, items)), {30, 30})

      assert {:ok, [open] = items, :changed} = use_on(ctx.base, items, door, ctx.nobody)
      refute MapSet.member?(SpaceMap.collision_set(Layout.apply(ctx.base, items)), {30, 30})

      in_doorway = %{ctx.nobody | avatars: [{30, 30}]}
      assert {:error, :someone_there} = use_on(ctx.base, items, open, in_doorway)

      assert {:ok, [%{state: %{"open" => false}}], :changed} =
               use_on(ctx.base, items, open, ctx.nobody)
    end

    test "closes a door on the far side of somebody: they open it again", %{base: base} do
      # The ring around (35,35) is closed by an open door at (35,34).
      ring =
        for {x, y} <- [{34, 34}, {36, 34}, {34, 35}, {36, 35}, {34, 36}, {35, 36}, {36, 36}] do
          %{id: "r#{x}-#{y}", kind: "tree", x: x, y: y, dir: "down", placed_by: nil, state: %{}}
        end

      door = %{
        id: "d",
        kind: "door",
        x: 35,
        y: 34,
        dir: "down",
        placed_by: nil,
        state: %{"open" => true}
      }

      inside = %{avatars: [{35, 35}], seated: MapSet.new()}
      assert {:ok, items, :changed} = use_on(base, ring ++ [door], door, inside)

      # And with them behind the shut door, the room still takes edits.
      assert {:ok, _items} = place(base, items, "plant", 20, 20, inside)
    end

    test "rolls a die and flips a coin with the roll it is given", %{base: base, nobody: nobody} do
      {:ok, items} = place(base, [], "die", 30, 30, nobody)
      {:ok, [die, coin] = items} = place(base, items, "coin", 31, 31, nobody)

      assert {:ok, items, {:rolled, "die", 5}} = use_on(base, items, die, nobody, fn 6 -> 5 end)

      assert {:ok, items, {:rolled, "coin", "tails"}} =
               use_on(base, items, coin, nobody, fn 2 -> 2 end)

      map = Layout.apply(base, items)
      assert %{kind: "hologram", text: "5"} = Enum.find(map.labels, &(&1.x == 30))
      assert %{tile: "cst_coin_tails"} = Enum.find(map.layers.decor, &(&1[:item_id] == coin.id))
    end

    test "pairs teleporters as they are placed and sends you to the twin", ctx do
      {:ok, [a] = items} = place(ctx.base, [], "teleporter", 30, 30, ctx.nobody)
      assert {:error, :unpaired} = use_on(ctx.base, items, a, ctx.nobody)

      {:ok, [a, b] = items} = place(ctx.base, items, "teleporter", 40, 40, ctx.nobody)
      assert a.state["link"] == b.id and b.state["link"] == a.id
      assert {:ok, ^items, {:teleport, {40, 40}}} = use_on(ctx.base, items, a, ctx.nobody)

      # A pad is walked onto, not around.
      refute MapSet.member?(SpaceMap.collision_set(Layout.apply(ctx.base, items)), {30, 30})

      {:ok, [lonely]} = Layout.edit(ctx.base, items, {:remove, b.id}, ctx.nobody, "bob")
      assert lonely.state == %{}
    end

    test "opens a panel for signs, boards, screens and arcade cabinets", %{
      base: base,
      nobody: nobody
    } do
      for {kind, x} <- [{"sign", 30}, {"board", 32}, {"screen", 34}, {"arcade", 36}] do
        {:ok, [item] = items} = place(base, [], kind, x, 30, nobody)
        assert {:ok, ^items, {:panel, ^kind}} = use_on(base, items, item, nobody)
      end
    end

    test "has nothing to do on a plain piece", %{base: base, nobody: nobody} do
      {:ok, [table] = items} = place(base, [], "table", 30, 30, nobody)
      assert {:error, :not_usable} = use_on(base, items, table, nobody)
      assert {:error, :unknown_item} = Layout.use(base, items, "nope", nobody, & &1)
    end

    test "every usable piece is an interactable on the map", %{base: base, nobody: nobody} do
      {:ok, items} = place(base, [], "lamp", 30, 30, nobody)
      {:ok, [lamp, _table] = items} = place(base, items, "table", 31, 31, nobody)
      map = Layout.apply(base, items)

      assert %{kind: "item", use: "toggle_light", x: 30, y: 30} =
               Enum.find(map.interactables, &(&1.id == Layout.interactable_id(lamp)))

      assert length(map.interactables) == length(base.interactables) + 1
      assert %{interactables: _, labels: _} = Layout.patch(map, 3)
    end
  end

  describe "a board belongs to a channel" do
    test "is refused in a private conversation's Construct", %{base: base, nobody: nobody} do
      private = Map.put(nobody, :conversation, "direct_message")
      assert {:error, :unknown_kind} = place(base, [], "board", 30, 30, private)
      assert {:ok, _items} = place(base, [], "screen", 30, 30, private)
    end
  end

  describe "edit/5 label" do
    setup %{base: base, nobody: nobody} do
      {:ok, [sign] = items} = place(base, [], "sign", 30, 30, nobody)
      %{sign: sign, items: items}
    end

    test "lets the author write their sign and shows it over the board", ctx do
      assert {:ok, [sign]} =
               Layout.edit(
                 ctx.base,
                 ctx.items,
                 {:label, ctx.sign.id, "  Bem-vindos\u0007 ", false},
                 ctx.nobody,
                 "Alice"
               )

      assert sign.state == %{"text" => "Bem-vindos", "text_by" => "Alice"}

      assert [%{kind: "hologram", text: "Bem-vindos"}] =
               Layout.apply(ctx.base, [sign]).labels
    end

    test "lets a moderator rewrite or clear somebody else's sign", ctx do
      assert {:error, :not_allowed} =
               Layout.edit(
                 ctx.base,
                 ctx.items,
                 {:label, ctx.sign.id, "mine", false},
                 ctx.nobody,
                 "bob"
               )

      assert {:ok, [%{state: state}]} =
               Layout.edit(
                 ctx.base,
                 ctx.items,
                 {:label, ctx.sign.id, "", true},
                 ctx.nobody,
                 "bob"
               )

      assert state == %{}
    end

    test "refuses a line too long and a piece that is no sign", ctx do
      long = String.duplicate("a", Layout.sign_max() + 1)

      assert {:error, :too_long} =
               Layout.edit(
                 ctx.base,
                 ctx.items,
                 {:label, ctx.sign.id, long, false},
                 ctx.nobody,
                 "alice"
               )

      {:ok, items} = place(ctx.base, ctx.items, "table", 31, 31, ctx.nobody)
      table = List.last(items)

      assert {:error, :not_usable} =
               Layout.edit(ctx.base, items, {:label, table.id, "x", true}, ctx.nobody, "alice")
    end
  end

  describe "rotate through a kind's own facings" do
    test "a corner turns four ways, a chair two", %{base: base, nobody: nobody} do
      {:ok, [corner] = items} = place(base, [], "corner", 30, 30, nobody)

      dirs =
        Enum.map_reduce(1..4, items, fn _, items ->
          {:ok, [turned] = items} = Layout.edit(base, items, {:rotate, corner.id}, nobody, "a")
          {turned.dir, items}
        end)
        |> elem(0)

      assert dirs == ~w(right up left down)
      assert Layout.dirs(base, "chair") == ~w(down right)
    end
  end

  describe "normalize/2 of states" do
    test "keeps what each kind's use knows and drops the rest", %{base: base} do
      raw = [
        %{
          "id" => "l",
          "kind" => "lamp",
          "x" => 30,
          "y" => 30,
          "state" => %{"on" => false, "x" => 1}
        },
        %{"id" => "d", "kind" => "die", "x" => 31, "y" => 30, "state" => %{"face" => 9}},
        %{
          "id" => "t1",
          "kind" => "teleporter",
          "x" => 32,
          "y" => 30,
          "state" => %{"link" => "t2"}
        },
        %{
          "id" => "t2",
          "kind" => "teleporter",
          "x" => 33,
          "y" => 30,
          "state" => %{"link" => "t1"}
        },
        %{
          "id" => "t3",
          "kind" => "teleporter",
          "x" => 34,
          "y" => 30,
          "state" => %{"link" => "t1"}
        },
        %{
          "id" => "s",
          "kind" => "sign",
          "x" => 35,
          "y" => 30,
          "state" => %{"text" => String.duplicate("a", 99)}
        },
        %{"id" => "c", "kind" => "corner", "x" => 36, "y" => 30, "dir" => "left"}
      ]

      states = base |> Layout.normalize(raw) |> Map.new(&{&1.id, &1.state})

      assert states == %{
               "l" => %{"on" => false},
               "d" => %{},
               "t1" => %{"link" => "t2"},
               "t2" => %{"link" => "t1"},
               "t3" => %{},
               "s" => %{},
               "c" => %{}
             }

      assert %{dir: "left"} = base |> Layout.normalize(raw) |> Enum.find(&(&1.id == "c"))
      assert %{state: %{"on" => false}} = Layout.view(hd(Layout.normalize(base, raw)))
    end
  end

  describe "paint/4" do
    test "paints a rectangle, corners in any order, and only the floor shows it", %{base: base} do
      assert [%{id: "wood", tile: wood} | _] = base.materials
      assert {:ok, floor} = Layout.paint(base, nil, {31, 31, 30, 30}, "wood")
      assert byte_size(floor) == base.width * base.height

      rows = Layout.apply(base, [], floor).layers.floor
      assert String.at(Enum.at(rows, 30), 30) == wood
      assert String.at(Enum.at(rows, 31), 31) == wood
      assert String.at(Enum.at(rows, 32), 32) == "w"

      # Paint spilling past the island stays sky.
      {:ok, edge} = Layout.paint(base, nil, {0, 0, 9, 9}, "wood")
      rows = Layout.apply(base, [], edge).layers.floor
      assert String.at(Enum.at(rows, 0), 0) == base.ground
      assert String.at(Enum.at(rows, 8), 8) == wood
    end

    test "erases back to white and refuses what it cannot paint", %{base: base} do
      {:ok, floor} = Layout.paint(base, nil, {30, 30, 31, 31}, "grass")
      {:ok, floor} = Layout.paint(base, floor, {30, 30, 30, 30}, "none")
      rows = Layout.apply(base, [], floor).layers.floor
      assert String.at(Enum.at(rows, 30), 30) == "w"

      assert {:error, :unknown_material} = Layout.paint(base, nil, {30, 30, 30, 30}, "lava")
      assert {:error, :out_of_bounds} = Layout.paint(base, nil, {30, 30, 99, 30}, "wood")
    end

    test "a stored floor is kept only when it fits this map", %{base: base} do
      {:ok, floor} = Layout.paint(base, nil, {30, 30, 31, 31}, "stone")
      assert Layout.normalize_floor(base, floor) == floor
      assert Layout.normalize_floor(base, "...") == nil
      assert Layout.normalize_floor(base, String.duplicate("x", base.width * base.height)) == nil
      assert Layout.normalize_floor(base, nil) == nil
    end

    test "the floor rides on a patch only when asked", %{base: base} do
      map = Layout.apply(base, [])
      refute Map.has_key?(Layout.patch(map, 1), :floor)
      assert %{floor: [_ | _]} = Layout.patch(map, 1, floor?: true)
    end
  end

  describe "pieces bigger than a tile" do
    # A bench two tiles long down the y axis, a seat on each tile, and a
    # 2×2 statue whose art stands on its front corner.
    setup %{base: base} do
      chair = base.catalog["chair"]

      base =
        base
        |> put_in([:catalog, "bench"], %{
          chair
          | size: [1, 2],
            seat: false,
            seats: [[0, 0], [0, 1]]
        })
        |> put_in([:catalog, "statue"], %{base.catalog["tree"] | size: [2, 2], foot: [1, 1]})

      %{base: base}
    end

    test "covers its whole footprint, and turning it swaps the axes", %{base: base} do
      assert Layout.footprint(base, "bench", 30, 30, "down") == [{30, 30}, {30, 31}]
      assert Layout.footprint(base, "bench", 30, 30, "right") == [{30, 30}, {31, 30}]

      assert Layout.footprint(base, "statue", 30, 30, "down") ==
               [{30, 30}, {31, 30}, {30, 31}, {31, 31}]
    end

    test "refuses a footprint that lands on a piece, a person or kept floor", ctx do
      {:ok, items} = place(ctx.base, [], "tree", 30, 31, ctx.nobody)
      assert {:error, :occupied} = place(ctx.base, items, "bench", 30, 30, ctx.nobody)
      assert {:ok, _} = place(ctx.base, items, "bench", 31, 30, ctx.nobody)

      someone = %{ctx.nobody | avatars: [{40, 41}]}
      assert {:error, :someone_there} = place(ctx.base, [], "bench", 40, 40, someone)

      # The far tile of the bench would be off the floor.
      assert {:error, :reserved} = place(ctx.base, [], "bench", 30, 55, ctx.nobody)
    end

    test "blocks, seats and answers E on every tile it covers", %{base: base, nobody: nobody} do
      {:ok, [bench] = items} = place(base, [], "bench", 30, 30, nobody)
      map = Layout.apply(base, items)
      blocked = SpaceMap.collision_set(map)

      assert MapSet.member?(blocked, {30, 30}) and MapSet.member?(blocked, {30, 31})

      assert [%{x: 30, y: 30}, %{x: 30, y: 31}] =
               Enum.filter(map.seats, &(&1.item_id == bench.id))

      # A bench's art stands in its middle, under whoever sits on it.
      assert %{x: 30.0, y: 30.5} = Enum.find(map.layers.decor, &(&1[:item_id] == bench.id))

      {:ok, [statue] = items} = place(base, [], "statue", 30, 30, nobody)
      map = Layout.apply(base, items)
      assert %{x: 31, y: 31} = Enum.find(map.layers.decor, &(&1[:item_id] == statue.id))
    end

    test "a sofa held by somebody on its second seat stays put", %{base: base, nobody: nobody} do
      {:ok, [bench] = items} = place(base, [], "bench", 30, 30, nobody)
      seated = %{nobody | seated: MapSet.new([Layout.seat_id(bench) <> ":1"])}

      assert {:error, :seat_taken} =
               Layout.edit(base, items, {:move, bench.id, 34, 34}, seated, "bob")
    end

    test "turns only where the turned footprint fits", %{base: base, nobody: nobody} do
      {:ok, items} = place(base, [], "tree", 31, 30, nobody)
      {:ok, [_tree, bench] = items} = place(base, items, "bench", 30, 30, nobody)

      assert {:error, :occupied} = Layout.edit(base, items, {:rotate, bench.id}, nobody, "bob")

      {:ok, [bench]} = place(base, [], "bench", 30, 30, nobody)

      assert {:ok, [%{dir: "right"}]} =
               Layout.edit(base, [bench], {:rotate, bench.id}, nobody, "bob")
    end

    test "is moved by its corner over its own old tiles", %{base: base, nobody: nobody} do
      {:ok, [bench] = items} = place(base, [], "bench", 30, 30, nobody)

      assert {:ok, [%{x: 30, y: 31}]} =
               Layout.edit(base, items, {:move, bench.id, 30, 31}, nobody, "bob")
    end

    test "a stored piece that no longer fits beside its neighbour is dropped", %{base: base} do
      raw = [
        %{"id" => "a", "kind" => "tree", "x" => 30, "y" => 31},
        %{"id" => "b", "kind" => "bench", "x" => 30, "y" => 30},
        %{"id" => "c", "kind" => "bench", "x" => 32, "y" => 30}
      ]

      assert ~w(a c) == base |> Layout.normalize(raw) |> Enum.map(& &1.id)
    end

    test "walls somebody in with its whole footprint", %{base: base} do
      # A ring around (35,35) whose last gap is closed by the bench's far tile.
      ring =
        for {x, y} <- [{34, 34}, {36, 34}, {34, 35}, {36, 35}, {34, 36}, {35, 36}, {36, 36}] do
          %{id: "r#{x}-#{y}", kind: "tree", x: x, y: y, dir: "down", placed_by: nil, state: %{}}
        end

      inside = %{avatars: [{35, 35}], seated: MapSet.new()}
      assert {:error, :would_trap} = place(base, ring, "bench", 35, 33, inside, "down")
      assert {:ok, _items} = place(base, ring, "bench", 40, 40, inside, "down")
    end
  end

  describe "the Game Room's furniture" do
    setup do
      {:ok, room} = SpaceMap.get("game_room")
      %{room: room, items: Layout.normalize(room, [])}
    end

    test "comes with the room, every piece of it from the Construct's catalog", ctx do
      assert length(ctx.items) == length(ctx.room.fixed_items)
      assert Enum.all?(ctx.items, &Layout.fixed?/1)
      kinds = MapSet.new(ctx.items, & &1.kind)

      for kind <- ~w(arcade racing_arcade pool_table ping_pong_table beanbag gaming_chair) do
        assert kind in kinds
      end

      map = Layout.apply(ctx.room, ctx.items)
      assert map.seats != []
      assert [%{id: "game_room_exit", modal: %{action: "exit_game_room"}} | _] = map.interactables
      assert Enum.count(map.items, &(&1.kind == "arcade")) >= 4
    end

    test "every cabinet plays a Retro Game of its own", ctx do
      games =
        for item <- ctx.items, item.kind in ~w(arcade racing_arcade), do: Map.get(item, :game)

      assert length(games) == 8
      assert Enum.all?(games, &Catalog.valid_game_id?/1)
      assert games == Enum.uniq(games)
      assert Enum.find(ctx.items, &(&1.id == "fixed:1")).game == "hex_pong"
    end

    test "cannot be moved, turned or removed", ctx do
      cabinet = Enum.find(ctx.items, &(&1.kind == "racing_arcade"))

      for op <- [{:move, cabinet.id, 20, 20}, {:remove, cabinet.id}, {:rotate, cabinet.id}] do
        assert {:error, :fixed} = Layout.edit(ctx.room, ctx.items, op, ctx.nobody, "alice")
      end
    end
  end

  describe "the Office's furniture" do
    setup do
      {:ok, office} = SpaceMap.get("office")
      %{office: office, items: Layout.normalize(office, [])}
    end

    test "comes with the room, every piece of it from the Construct's catalog", ctx do
      assert length(ctx.items) == length(ctx.office.fixed_items)
      assert Enum.all?(ctx.items, &Layout.fixed?/1)
      assert Enum.all?(ctx.items, &Map.has_key?(ctx.office.catalog, &1.kind))

      kinds = MapSet.new(ctx.items, & &1.kind)

      for kind <- ~w(reception_desk workstation office_chair meeting_table glass_wall glass_door) do
        assert kind in kinds
      end

      map = Layout.apply(ctx.office, ctx.items)
      assert Enum.all?(map.items, &(&1.fixed == true))
      assert map.seats != []
      assert [%{id: "office_exit", modal: %{action: "exit_office"}} | _] = map.interactables
    end

    test "cannot be moved, turned, removed or written on", ctx do
      [desk | _] = Enum.filter(ctx.items, &(&1.kind == "workstation"))

      for op <- [{:move, desk.id, 20, 20}, {:remove, desk.id}, {:rotate, desk.id}] do
        assert {:error, :fixed} = Layout.edit(ctx.office, ctx.items, op, ctx.nobody, "alice")
      end

      assert {:error, :fixed} =
               Layout.edit(ctx.office, ctx.items, {:label, desk.id, "hi", true}, ctx.nobody, "a")
    end

    test "keeps its place whatever storage says, and what its lamps were doing", ctx do
      lamp = Enum.find(ctx.items, &(&1.kind == "lamp"))

      stored = [
        %{"id" => lamp.id, "kind" => "lamp", "x" => 20, "y" => 20, "state" => %{"on" => false}}
      ]

      assert [kept | _] =
               ctx.office |> Layout.normalize(stored) |> Enum.filter(&(&1.id == lamp.id))

      assert {kept.kind, kept.x, kept.y} == {"lamp", lamp.x, lamp.y}
      assert kept.state == %{"on" => false}

      # A state stored for another piece under the same id is not this one's.
      moved = [put_in(hd(stored)["kind"], "glass_door")]

      assert [%{state: state}] =
               ctx.office |> Layout.normalize(moved) |> Enum.filter(&(&1.id == lamp.id))

      assert state == %{}
    end

    test "draws its walls flush on the floor, with no contact shadow, and says so in a patch",
         ctx do
      map = Layout.apply(ctx.office, ctx.items)
      ids = fn kind -> ctx.items |> Enum.filter(&(&1.kind == kind)) |> MapSet.new(& &1.id) end
      walls = MapSet.union(ids.("wall"), ids.("glass_wall"))
      lamps = ids.("lamp")

      decor = Enum.filter(map.layers.decor, &Map.has_key?(&1, :item_id))
      assert Enum.all?(Enum.filter(decor, &(&1.item_id in walls)), &(&1.shadow == false))
      refute Enum.any?(Enum.filter(decor, &(&1.item_id in lamps)), &Map.has_key?(&1, :shadow))
      assert Enum.any?(Layout.patch(map, 1).decor, &(&1[:shadow] == false))
    end

    test "is never where a stored piece lands: the piece is dropped", ctx do
      desk = Enum.find(ctx.items, &(&1.kind == "workstation"))
      stored = [%{"id" => "p1", "kind" => "plant", "x" => desk.x, "y" => desk.y}]

      refute ctx.office |> Layout.normalize(stored) |> Enum.any?(&(&1.id == "p1"))
    end

    test "does not count against the pieces a room holds", ctx do
      office = %{ctx.office | max_items: 1}
      items = Layout.normalize(office, [])

      assert {:ok, items} = place(office, items, "plant", 20, 20, ctx.nobody)
      assert {:error, :full} = place(office, items, "plant", 21, 20, ctx.nobody)
    end
  end

  describe "where a piece's art stands, and where it sorts" do
    test "a long piece stands forward of its centre and sorts on it", %{base: base} do
      table = %{
        id: "t",
        kind: "long_table",
        x: 30,
        y: 30,
        dir: "down",
        placed_by: nil,
        state: %{}
      }

      prop =
        base
        |> Layout.apply([table])
        |> get_in([:layers, :decor])
        |> Enum.find(&(&1[:item_id] == "t"))

      assert_in_delta prop.x, 30.6, 1.0e-9
      assert_in_delta prop.y, 31.1, 1.0e-9
      # Between whoever stands behind its back half and in front of it.
      assert_in_delta prop.depth, 60.5, 1.0e-9
    end

    test "a one-tile piece and a sofa need no order of their own", %{base: base} do
      chair = %{id: "c", kind: "chair", x: 30, y: 30, dir: "down", placed_by: nil, state: %{}}
      sofa = %{id: "s", kind: "sofa", x: 33, y: 30, dir: "down", placed_by: nil, state: %{}}
      decor = base |> Layout.apply([chair, sofa]) |> get_in([:layers, :decor])

      refute decor |> Enum.find(&(&1[:item_id] == "c")) |> Map.has_key?(:depth)
      assert %{x: 33.0, y: 30.5} = sofa_prop = Enum.find(decor, &(&1[:item_id] == "s"))
      refute Map.has_key?(sofa_prop, :depth)
    end

    test "a pane stands on the edge its facing names, sorted just behind it", %{base: base} do
      for {dir, {x, y}} <- [
            {"down", {30.75, 30.25}},
            {"up", {29.75, 30.25}},
            {"right", {30.25, 30.75}},
            {"left", {30.25, 29.75}}
          ] do
        pane = %{id: "p", kind: "glass_wall", x: 30, y: 30, dir: dir, placed_by: nil, state: %{}}

        prop =
          base
          |> Layout.apply([pane])
          |> get_in([:layers, :decor])
          |> Enum.find(&(&1[:item_id] == "p"))

        assert {prop.x, prop.y} == {x, y}, dir
        assert_in_delta prop.depth, x + y - 0.01, 1.0e-9
      end
    end
  end
end
