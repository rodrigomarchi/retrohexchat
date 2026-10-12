defmodule RetroHexChat.VirtualSpace.Construct.Layout do
  @moduledoc """
  What people have placed in a Construct, and the rules for placing it.

  Pure: the runtime holds the items, this module answers whether an edit may
  happen and what the map looks like with the items on it. An item covers its
  kind's footprint of floor — one tile for a chair, two for a dining table —
  whatever its art overhangs: a tree's canopy rises into the void, its trunk
  is what you bump into. The item's `x, y` is the footprint's back corner (its
  smallest x and y); the art stands on the kind's `foot` point inside it.

  The base map (`Maps.Construct`) carries the catalog of placeable kinds, the
  tiles nobody may build on (the gate, the ground in front of it, the spawns)
  and how many items a room holds. Every edit is checked here, on the server:
  the client's green or red ghost is a preview of this answer, never a
  substitute for it.

  Some kinds do something when somebody next to them presses E (`use/5`): a
  lamp switches, a door opens, a die rolls, a teleporter sends you to its
  twin, a sign, a board, a screen or an arcade cabinet opens a panel. What a
  piece is doing lives in its `state`, a small map of string keys that is
  stored with it, so a lamp left off is still off when the room comes back.
  """

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap

  @dirs ~w(down right)
  @unpainted ?.
  @sign_max 40
  @die_faces 6

  @type item :: %{
          id: String.t(),
          kind: String.t(),
          x: integer(),
          y: integer(),
          dir: String.t(),
          placed_by: String.t() | nil,
          state: map()
        }

  @type op ::
          {:place, String.t(), integer(), integer(), String.t()}
          | {:move, String.t(), integer(), integer()}
          | {:remove, String.t()}
          | {:rotate, String.t()}
          | {:label, String.t(), String.t(), boolean()}
          | {:paint, integer(), integer(), integer(), integer(), String.t()}

  @typedoc """
  The painted floor: one character per tile of the map, row by row — a
  material's tile, or `.` where the floor is its own white. `nil` is a floor
  nobody has painted.
  """
  @type floor :: String.t() | nil

  @typedoc """
  What pressing E on a piece did. `:changed` is a new look for the piece (a
  lamp switched, a door swung); the others are for the caller to act on.
  """
  @type effect ::
          :changed
          | {:rolled, String.t(), integer() | String.t()}
          | {:teleport, {integer(), integer()}}
          | {:panel, String.t()}

  @type error ::
          :unknown_kind
          | :unknown_item
          | :out_of_bounds
          | :reserved
          | :occupied
          | :someone_there
          | :seat_taken
          | :would_trap
          | :full
          | :not_usable
          | :unpaired
          | :not_allowed
          | :too_long
          | :unknown_material

  @typedoc """
  What an edit is judged against, beyond the items themselves: the tiles people
  stand on (nobody gets a table dropped on their feet, nobody gets walled in)
  and the chairs somebody is sitting in.
  """
  @type context :: %{
          required(:avatars) => [{integer(), integer()}],
          required(:seated) => MapSet.t(String.t()),
          optional(:conversation) => String.t()
        }

  @doc "The facings an item can be placed in, unless its kind names its own."
  @spec dirs() :: [String.t()]
  def dirs, do: @dirs

  @doc "The facings a kind turns through."
  @spec dirs(map(), String.t()) :: [String.t()]
  def dirs(base, kind) do
    case get_in(base, [:catalog, kind, :dirs]) do
      [_ | _] = dirs -> dirs
      _ -> @dirs
    end
  end

  @doc "The longest line a sign holds."
  @spec sign_max() :: pos_integer()
  def sign_max, do: @sign_max

  @doc """
  The map with the items on it: each item adds a standing prop, a blocked tile,
  and whatever its kind brings — a seat for a chair, a light for a lamp.
  """
  @spec apply(map(), [item()], floor()) :: map()
  def apply(base, items, floor \\ nil) do
    catalog = Map.get(base, :catalog, %{})
    placed = Enum.filter(items, &Map.has_key?(catalog, &1.kind))

    blocking = Enum.filter(placed, &blocks?(catalog, &1))

    base
    |> update_in([:layers, :decor], &(&1 ++ Enum.flat_map(placed, fn i -> decor(catalog, i) end)))
    |> Map.update!(:collision, &(&1 ++ Enum.map(blocking, fn i -> blocked(catalog, i) end)))
    |> Map.update(:seats, seats(catalog, placed), &(&1 ++ seats(catalog, placed)))
    |> Map.update(:lights, lights(catalog, placed), &(&1 ++ lights(catalog, placed)))
    |> Map.update(:labels, labels(catalog, placed), &(&1 ++ labels(catalog, placed)))
    |> Map.update(
      :interactables,
      usable(catalog, placed),
      &(&1 ++ usable(catalog, placed))
    )
    |> Map.put(:items, Enum.map(placed, &view/1))
    |> paint_floor(floor)
  end

  @doc """
  Paint the tiles of a rectangle (corners in any order) with a material, or
  with `"none"` back to the white floor. Painting is no piece: it blocks
  nothing and counts against no limit.
  """
  @spec paint(map(), floor(), {integer(), integer(), integer(), integer()}, String.t()) ::
          {:ok, String.t()} | {:error, :unknown_material | :out_of_bounds}
  def paint(base, floor, {xa, ya, xb, yb}, material) do
    {x0, x1} = Enum.min_max([xa, xb])
    {y0, y1} = Enum.min_max([ya, yb])

    with {:ok, char} <- material_char(base, material),
         true <-
           (in_bounds?(base, x0, y0) and in_bounds?(base, x1, y1)) || {:error, :out_of_bounds} do
      width = base.width
      run = :binary.copy(<<char>>, x1 - x0 + 1)

      painted =
        Enum.reduce(y0..y1//1, floor || blank_floor(base), fn y, acc ->
          at = y * width + x0
          <<before::binary-size(at), _old::binary-size(x1 - x0 + 1), rest::binary>> = acc
          before <> run <> rest
        end)

      {:ok, painted}
    end
  end

  @doc """
  A floor read back from storage: kept when it is this map's size and paints
  only materials this build knows, else the floor goes back to white.
  """
  @spec normalize_floor(map(), term()) :: floor()
  def normalize_floor(base, floor) when is_binary(floor) do
    known = MapSet.new([@unpainted | Enum.map(materials(base), &material_tile/1)])

    if byte_size(floor) == base.width * base.height and
         floor |> :binary.bin_to_list() |> Enum.all?(&MapSet.member?(known, &1)),
       do: floor,
       else: nil
  end

  def normalize_floor(_base, _floor), do: nil

  defp materials(base), do: Map.get(base, :materials, [])

  defp material_tile(%{tile: <<char>>}), do: char

  defp material_char(_base, "none"), do: {:ok, @unpainted}

  defp material_char(base, material) do
    case Enum.find(materials(base), &(&1.id == material)) do
      %{tile: <<char>>} -> {:ok, char}
      _unknown -> {:error, :unknown_material}
    end
  end

  defp blank_floor(base), do: :binary.copy(<<@unpainted>>, base.width * base.height)

  # A painted tile shows only on the floor itself: the sky around it stays sky.
  defp paint_floor(map, nil), do: map

  defp paint_floor(%{width: width, ground: <<ground>>} = map, floor) do
    rows =
      map.layers.floor
      |> Enum.with_index()
      |> Enum.map(fn {row, y} ->
        painted = binary_part(floor, y * width, width)

        row
        |> :binary.bin_to_list()
        |> Enum.zip(:binary.bin_to_list(painted))
        |> Enum.map(fn
          {base, @unpainted} -> base
          {^ground, _paint} -> ground
          {_base, paint} -> paint
        end)
        |> List.to_string()
      end)

    put_in(map, [:layers, :floor], rows)
  end

  @doc "The interactable id a usable piece answers to."
  @spec interactable_id(item()) :: String.t()
  def interactable_id(item), do: "item:" <> item.id

  @doc """
  The tiles a piece of `kind` covers with its back corner on `x, y`, facing
  `dir`. Turning a piece mirrors it across the screen, which swaps the floor's
  axes: a table two tiles long down one axis runs down the other once turned.
  """
  @spec footprint(map(), String.t(), integer(), integer(), String.t()) :: [{integer(), integer()}]
  def footprint(base, kind, x, y, dir) do
    {w, h} = size(get_in(base, [:catalog, kind]), dir)
    for dy <- 0..(h - 1)//1, dx <- 0..(w - 1)//1, do: {x + dx, y + dy}
  end

  @doc "The tiles a placed piece covers."
  @spec footprint(map(), item()) :: [{integer(), integer()}]
  def footprint(base, item), do: footprint(base, item.kind, item.x, item.y, item.dir)

  defp size(entry, dir) do
    [w, h] = (entry && entry[:size]) || [1, 1]
    if mirrored?(dir), do: {h, w}, else: {w, h}
  end

  defp mirrored?(dir), do: dir in ["right", "left"]

  # Where on the floor a piece's art (or one of its layers) stands: a point
  # inside the footprint, by default its centre.
  defp foot_point(entry, item, foot \\ nil) do
    {w, h} = size(entry, "down")
    [fx, fy] = foot || entry[:foot] || [(w - 1) / 2, (h - 1) / 2]
    {fx, fy} = if mirrored?(item.dir), do: {fy, fx}, else: {fx, fy}
    {item.x + fx, item.y + fy}
  end

  @doc """
  The part of the map an edit changes, for the clients already standing in it.
  The base never changes, so this is all a client needs to redraw the room;
  `floor?: true` adds the painted floor, for an edit that painted it.
  """
  @spec patch(map(), non_neg_integer(), keyword()) :: map()
  def patch(map, revision, opts \\ []) do
    patch = %{
      revision: revision,
      items: map.items,
      decor: map.layers.decor,
      collision: map.collision,
      seats: map.seats,
      lights: map.lights,
      labels: Map.get(map, :labels, []),
      interactables: Map.get(map, :interactables, [])
    }

    # The floor's rows travel only with the edit that painted them.
    if Keyword.get(opts, :floor?, false),
      do: Map.put(patch, :floor, map.layers.floor),
      else: patch
  end

  @doc """
  Apply one edit to the items, or say why it cannot happen.

  `actor` is the nickname that made the edit, recorded on a placed item.
  """
  @spec edit(map(), [item()], op(), context(), String.t()) ::
          {:ok, [item()]} | {:error, error()}
  def edit(base, items, {:place, kind, x, y, dir}, context, actor) do
    cond do
      not placeable?(base, kind, context) ->
        {:error, :unknown_kind}

      length(items) >= Map.get(base, :max_items, 0) ->
        {:error, :full}

      true ->
        item = %{
          id: Ecto.UUID.generate(),
          kind: kind,
          x: x,
          y: y,
          dir: dir_or_default(dirs(base, kind), dir),
          placed_by: actor,
          state: %{}
        }

        with :ok <- tile_free(base, items, context, kind, x, y, item.dir, nil) do
          checked(base, pair_teleporter(base, items, item), context)
        end
    end
  end

  def edit(base, items, {:move, id, x, y}, context, _actor) do
    with {:ok, item} <- find(items, id),
         :ok <- not_sat_on(item, context),
         :ok <- tile_free(base, items, context, item.kind, x, y, item.dir, id) do
      checked(base, replace(items, %{item | x: x, y: y}), context)
    end
  end

  def edit(_base, items, {:remove, id}, context, _actor) do
    with {:ok, item} <- find(items, id),
         :ok <- not_sat_on(item, context) do
      {:ok, items |> Enum.reject(&(&1.id == id)) |> Enum.map(&unlink(&1, id))}
    end
  end

  # A turned piece must still fit: a long table turned may run into a wall.
  def edit(base, items, {:rotate, id}, context, _actor) do
    with {:ok, item} <- find(items, id),
         :ok <- not_sat_on(item, context),
         dir = next_dir(dirs(base, item.kind), item.dir),
         :ok <- turned_fits(base, items, context, item, dir) do
      checked(base, replace(items, %{item | dir: dir}), context)
    end
  end

  # A sign says what its author wrote. Somebody who may moderate the
  # conversation (an operator of the channel, either person of a private one)
  # can rewrite or clear any sign; anybody else only their own.
  def edit(base, items, {:label, id, text, moderator?}, _context, actor) do
    text = normalize_text(text)

    with {:ok, item} <- find(items, id),
         :ok <- a_sign(base, item),
         :ok <- may_label(item, actor, moderator?),
         :ok <- fits_sign(text) do
      {:ok, replace(items, %{item | state: sign_state(text, actor)})}
    end
  end

  @doc """
  Press E on a piece, or say why nothing happens.

  `roll` draws the dice: given `n`, a number from 1 to `n`. The runtime passes
  `:rand.uniform/1`; a test passes a fixed answer.
  """
  @spec use(map(), [item()], String.t(), context(), (pos_integer() -> pos_integer())) ::
          {:ok, [item()], effect()} | {:error, error()}
  def use(base, items, id, context, roll) do
    with {:ok, item} <- find(items, id) do
      act(use_of(base, item), base, items, item, context, roll)
    end
  end

  defp act("toggle_light", _base, items, item, _context, _roll) do
    on = Map.get(state_of(item), "on", true)
    {:ok, replace(items, put_state(item, "on", not on)), :changed}
  end

  defp act("door", base, items, item, context, _roll) do
    if Map.get(state_of(item), "open", false),
      do: close_door(base, items, item, context),
      else: {:ok, replace(items, put_state(item, "open", true)), :changed}
  end

  defp act("roll_die", _base, items, item, _context, roll) do
    face = roll.(@die_faces)
    {:ok, replace(items, put_state(item, "face", face)), {:rolled, "die", face}}
  end

  defp act("flip_coin", _base, items, item, _context, roll) do
    face = if roll.(2) == 1, do: "heads", else: "tails"
    {:ok, replace(items, put_state(item, "face", face)), {:rolled, "coin", face}}
  end

  defp act("teleport", _base, items, item, _context, _roll) do
    case Enum.find(items, &(&1.id == state_of(item)["link"])) do
      nil -> {:error, :unpaired}
      twin -> {:ok, items, {:teleport, {twin.x, twin.y}}}
    end
  end

  defp act(panel, _base, items, _item, _context, _roll)
       when panel in ~w(sign arcade board screen),
       do: {:ok, items, {:panel, panel}}

  defp act(_use, _base, _items, _item, _context, _roll), do: {:error, :not_usable}

  # A door does not close on somebody standing in it, nor shut anybody in.
  defp close_door(base, items, item, context) do
    if Enum.any?(footprint(base, item), &(&1 in context.avatars)) do
      {:error, :someone_there}
    else
      closed = replace(items, put_state(item, "open", false))
      with {:ok, closed} <- checked(base, closed, context), do: {:ok, closed, :changed}
    end
  end

  @doc """
  Items read back from storage, keeping only the ones this build can draw and
  that still land on buildable floor. A stored row is data from an older build,
  and a kind that has since been retired must not break the room.
  """
  @spec normalize(map(), [map()]) :: [item()]
  def normalize(base, raw_items) when is_list(raw_items) do
    catalog = Map.get(base, :catalog, %{})

    items =
      raw_items
      |> Enum.flat_map(&normalize_item/1)
      |> Enum.filter(&Map.has_key?(catalog, &1.kind))
      |> Enum.map(fn item ->
        %{
          item
          | dir: dir_or_default(dirs(base, item.kind), item.dir),
            state: clean_state(use_of(base, item), item.state)
        }
      end)
      |> keep_fitting(base)
      |> Enum.take(Map.get(base, :max_items, 0))

    drop_broken_links(items)
  end

  def normalize(_base, _raw_items), do: []

  @doc "An item in the shape storage and the wire carry it."
  @spec view(item()) :: map()
  def view(item) do
    view = %{
      id: item.id,
      kind: item.kind,
      x: item.x,
      y: item.y,
      dir: item.dir,
      placed_by: item.placed_by
    }

    case Map.get(item, :state, %{}) do
      state when map_size(state) == 0 -> view
      state -> Map.put(view, :state, state)
    end
  end

  # --- Private ---

  defp normalize_item(%{} = raw) do
    get = fn key -> Map.get(raw, key) || Map.get(raw, Atom.to_string(key)) end

    with id when is_binary(id) <- get.(:id),
         kind when is_binary(kind) <- get.(:kind),
         x when is_integer(x) <- get.(:x),
         y when is_integer(y) <- get.(:y) do
      [
        %{
          id: id,
          kind: kind,
          x: x,
          y: y,
          dir: get.(:dir),
          placed_by: get.(:placed_by),
          state: string_keys(get.(:state))
        }
      ]
    else
      _malformed -> []
    end
  end

  defp normalize_item(_raw), do: []

  defp string_keys(%{} = state), do: Map.new(state, fn {k, v} -> {to_string(k), v} end)
  defp string_keys(_state), do: %{}

  # Only what a kind's use knows survives a reload; anything else is dropped.
  defp clean_state("toggle_light", %{"on" => false}), do: %{"on" => false}
  defp clean_state("door", %{"open" => true}), do: %{"open" => true}

  defp clean_state("roll_die", %{"face" => face}) when face in 1..@die_faces//1,
    do: %{"face" => face}

  defp clean_state("flip_coin", %{"face" => face}) when face in ~w(heads tails),
    do: %{"face" => face}

  defp clean_state("teleport", %{"link" => link}) when is_binary(link), do: %{"link" => link}

  defp clean_state("sign", %{"text" => text} = state) when is_binary(text) do
    text = normalize_text(text)

    if text != "" and String.length(text) <= @sign_max,
      do: sign_state(text, Map.get(state, "text_by")),
      else: %{}
  end

  defp clean_state(_use, _state), do: %{}

  # Stored pieces are kept in order while their footprint lands on free,
  # buildable floor: a piece whose kind grew since it was placed, and now
  # overlaps its neighbour, is the one that goes.
  defp keep_fitting(items, base) do
    {kept, _taken} = Enum.reduce(items, {[], MapSet.new()}, &keep_if_fits(base, &1, &2))
    Enum.reverse(kept)
  end

  defp keep_if_fits(base, item, {kept, taken}) do
    tiles = footprint(base, item)

    fits? =
      Enum.all?(tiles, fn {x, y} -> buildable?(base, x, y) end) and
        not Enum.any?(tiles, &MapSet.member?(taken, &1))

    if fits?,
      do: {[item | kept], MapSet.union(taken, MapSet.new(tiles))},
      else: {kept, taken}
  end

  # A teleporter whose twin is gone, or whose twin points elsewhere, is a pad
  # waiting for a new twin.
  defp drop_broken_links(items) do
    by_id = Map.new(items, &{&1.id, &1})

    Enum.map(items, fn item ->
      with link when is_binary(link) <- state_of(item)["link"],
           %{state: %{"link" => back}} when back == item.id <- Map.get(by_id, link) do
        item
      else
        nil -> item
        _broken -> %{item | state: Map.delete(item.state, "link")}
      end
    end)
  end

  # A piece is its art, and the layers its kind draws with it (the flames at
  # the Balrog's feet), each on its own point of the footprint.
  defp decor(catalog, item) do
    entry = Map.fetch!(catalog, item.kind)
    {x, y} = foot_point(entry, item)

    main = %{x: x, y: y, tile: tile_of(entry, item), sort: "stand", item_id: item.id}

    extra =
      for layer <- Map.get(entry, :layers, []) do
        {lx, ly} = foot_point(entry, item, layer.foot)
        tile = Map.get(layer.tiles, item.dir) || Map.get(layer.tiles, "down")
        %{x: lx, y: ly, tile: tile, sort: "stand", item_id: item.id}
      end

    [main | extra]
  end

  defp tile_of(entry, item) do
    tiles =
      case state_key(entry[:use], state_of(item)) do
        nil -> entry.tiles
        key -> get_in(entry, [:states, key]) || entry.tiles
      end

    Map.get(tiles, item.dir) || Map.get(tiles, "down")
  end

  # Which of a kind's alternate sprites the piece wears now.
  defp state_key("toggle_light", %{"on" => false}), do: "off"
  defp state_key("door", %{"open" => true}), do: "open"
  defp state_key("roll_die", %{"face" => face}), do: "face:#{face}"
  defp state_key("flip_coin", %{"face" => face}), do: face
  defp state_key(_use, _state), do: nil

  defp blocks?(catalog, item) do
    entry = Map.fetch!(catalog, item.kind)

    Map.get(entry, :blocks, true) and
      not (entry[:use] == "door" and Map.get(state_of(item), "open", false))
  end

  # One interactable per tile of the footprint, so E works from any side of a
  # long piece; the runtime reads the piece's id before the `#`.
  defp usable(catalog, items) do
    for item <- items,
        use = get_in(catalog, [item.kind, :use]),
        {{x, y}, n} <- Enum.with_index(footprint(%{catalog: catalog}, item)) do
      id = if n == 0, do: interactable_id(item), else: "#{interactable_id(item)}##{n}"
      %{id: id, kind: "item", use: use, x: x, y: y}
    end
  end

  # A sign's line floats over its board, and a die shows the face it last
  # landed on the same way; how each is drawn is its catalog entry's `label`.
  defp labels(catalog, items) do
    for item <- items,
        entry = Map.fetch!(catalog, item.kind),
        text = label_text(entry[:use], state_of(item)),
        drawn = entry[:label] do
      {x, y} = foot_point(entry, item)
      Map.merge(drawn, %{kind: "hologram", text: text, x: x, y: y, h: 1})
    end
  end

  defp label_text("sign", %{"text" => text}), do: text
  defp label_text("roll_die", %{"face" => face}), do: "#{face}"
  defp label_text(_use, _state), do: nil

  defp use_of(base, item), do: get_in(base, [:catalog, item.kind, :use])

  defp a_sign(base, item) do
    if use_of(base, item) == "sign", do: :ok, else: {:error, :not_usable}
  end

  defp placeable?(base, kind, context) do
    case get_in(base, [:catalog, kind]) do
      nil -> false
      entry -> conversation_allows?(Map.get(entry, :only), context)
    end
  end

  defp conversation_allows?(nil, _context), do: true

  defp conversation_allows?(only, context),
    do: Map.get(context, :conversation, "channel") in only

  defp put_state(item, key, value), do: Map.put(item, :state, Map.put(state_of(item), key, value))

  defp state_of(item), do: Map.get(item, :state) || %{}

  # A new teleporter answers the newest one still waiting for a twin.
  defp pair_teleporter(base, items, item) do
    waiting =
      if use_of(base, item) == "teleport" do
        items
        |> Enum.reverse()
        |> Enum.find(&(use_of(base, &1) == "teleport" and not Map.has_key?(state_of(&1), "link")))
      end

    case waiting do
      nil ->
        items ++ [item]

      twin ->
        replace(items, put_state(twin, "link", item.id)) ++ [put_state(item, "link", twin.id)]
    end
  end

  defp unlink(%{state: %{"link" => id} = state} = item, id),
    do: %{item | state: Map.delete(state, "link")}

  defp unlink(item, _id), do: item

  defp may_label(_item, _actor, true), do: :ok

  defp may_label(%{placed_by: placed_by}, actor, false) when is_binary(placed_by) do
    if String.downcase(placed_by) == String.downcase(actor),
      do: :ok,
      else: {:error, :not_allowed}
  end

  defp may_label(_item, _actor, false), do: {:error, :not_allowed}

  defp fits_sign(text) do
    if String.length(text) > @sign_max, do: {:error, :too_long}, else: :ok
  end

  defp sign_state("", _author), do: %{}
  defp sign_state(text, nil), do: %{"text" => text}
  defp sign_state(text, author), do: %{"text" => text, "text_by" => author}

  defp normalize_text(text) when is_binary(text) do
    text
    |> String.replace(~r/\p{C}/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp normalize_text(_text), do: ""

  defp blocked(catalog, item) do
    {w, h} = size(Map.fetch!(catalog, item.kind), item.dir)
    %{x: item.x, y: item.y, w: w, h: h, kind: "item"}
  end

  defp seats(catalog, items) do
    Enum.flat_map(items, &item_seats(Map.fetch!(catalog, &1.kind), &1))
  end

  # A chair is one seat; a sofa or a bench names the tiles of its footprint
  # that are seats, each its own.
  defp item_seats(%{seats: [_ | _] = spots}, item) do
    for {[dx, dy], n} <- Enum.with_index(spots) do
      {dx, dy} = if mirrored?(item.dir), do: {dy, dx}, else: {dx, dy}

      %{
        id: "#{seat_id(item)}:#{n}",
        x: item.x + dx,
        y: item.y + dy,
        dir: item.dir,
        item_id: item.id
      }
    end
  end

  defp item_seats(%{seat: true}, item),
    do: [%{id: seat_id(item), x: item.x, y: item.y, dir: item.dir, item_id: item.id}]

  defp item_seats(_entry, _item), do: []

  defp lights(catalog, items) do
    for item <- items,
        Map.get(state_of(item), "on", true),
        entry = Map.fetch!(catalog, item.kind),
        light <- entry[:lights] || [] do
      {x, y} = foot_point(entry, item)
      Map.merge(light, %{x: x, y: y})
    end
  end

  @doc "The seat a placed chair offers; a piece with several seats numbers them after it."
  @spec seat_id(item()) :: String.t()
  def seat_id(item), do: "seat:" <> item.id

  defp find(items, id) do
    case Enum.find(items, &(&1.id == id)) do
      nil -> {:error, :unknown_item}
      item -> {:ok, item}
    end
  end

  defp replace(items, updated) do
    Enum.map(items, fn item -> if item.id == updated.id, do: updated, else: item end)
  end

  defp not_sat_on(item, %{seated: seated}) do
    taken? =
      Enum.any?(seated, &(&1 == seat_id(item) or String.starts_with?(&1, seat_id(item) <> ":")))

    if taken?, do: {:error, :seat_taken}, else: :ok
  end

  # Every tile of the footprint must be floor nobody keeps clear, with no other
  # piece on it and nobody standing there; the first tile that is not says why.
  defp tile_free(base, items, context, kind, x, y, dir, moving_id) do
    taken =
      items
      |> Enum.reject(&(&1.id == moving_id))
      |> Enum.flat_map(&footprint(base, &1))
      |> MapSet.new()

    base
    |> footprint(kind, x, y, dir)
    |> Enum.find_value(:ok, fn {tx, ty} ->
      cond do
        not in_bounds?(base, tx, ty) -> {:error, :out_of_bounds}
        not buildable?(base, tx, ty) -> {:error, :reserved}
        MapSet.member?(taken, {tx, ty}) -> {:error, :occupied}
        {tx, ty} in context.avatars -> {:error, :someone_there}
        true -> nil
      end
    end)
  end

  # A one-tile piece turns on the spot; a longer one must find room for the
  # footprint it turns into, people around it included.
  defp turned_fits(base, items, context, item, dir) do
    if footprint(base, item.kind, item.x, item.y, dir) == footprint(base, item),
      do: :ok,
      else: tile_free(base, items, context, item.kind, item.x, item.y, dir, item.id)
  end

  # An edit that closes the last way between somebody and the gate is refused:
  # the room is shared, and one person's wall is everyone else's prison.
  defp checked(base, items, context) do
    if everyone_reaches_gate?(base, items, context.avatars),
      do: {:ok, items},
      else: {:error, :would_trap}
  end

  defp everyone_reaches_gate?(_base, _items, []), do: true

  defp everyone_reaches_gate?(base, items, avatars) do
    catalog = Map.get(base, :catalog, %{})

    blocked =
      base
      |> SpaceMap.collision_set()
      |> MapSet.union(
        items
        |> Enum.filter(&(Map.has_key?(catalog, &1.kind) and blocks?(catalog, &1)))
        |> Enum.flat_map(&footprint(base, &1))
        |> MapSet.new()
      )

    gate = gate_apron(base, blocked)
    reachable = flood(base, blocked, Enum.to_list(gate), gate)
    Enum.all?(avatars, &(neighbours_or_self(&1) |> Enum.any?(fn t -> t in reachable end)))
  end

  # The walkable reserved tiles: the ground in front of the gate and the spawns.
  defp gate_apron(base, blocked) do
    base
    |> reserved()
    |> Enum.reject(&MapSet.member?(blocked, &1))
    |> MapSet.new()
  end

  defp flood(_base, _blocked, [], seen), do: seen

  defp flood(base, blocked, [{x, y} | rest], seen) do
    next =
      for {nx, ny} <- [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}],
          in_bounds?(base, nx, ny),
          not MapSet.member?(blocked, {nx, ny}),
          not MapSet.member?(seen, {nx, ny}),
          do: {nx, ny}

    flood(base, blocked, next ++ rest, MapSet.union(seen, MapSet.new(next)))
  end

  # Somebody sitting is on a chair's own blocked tile; they are free if they can
  # step off it, which is what reaching any neighbour means.
  defp neighbours_or_self({x, y}), do: [{x, y}, {x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  defp buildable?(base, x, y) do
    in_bounds?(base, x, y) and
      not MapSet.member?(reserved(base), {x, y}) and
      not MapSet.member?(SpaceMap.collision_set(base), {x, y})
  end

  defp reserved(base), do: MapSet.new(Map.get(base, :reserved, []), &{&1.x, &1.y})

  defp in_bounds?(base, x, y), do: x >= 0 and y >= 0 and x < base.width and y < base.height

  defp dir_or_default(dirs, dir) do
    if dir in dirs, do: dir, else: hd(dirs)
  end

  defp next_dir(dirs, dir) do
    index = Enum.find_index(dirs, &(&1 == dir)) || 0
    Enum.at(dirs, rem(index + 1, length(dirs)))
  end
end
