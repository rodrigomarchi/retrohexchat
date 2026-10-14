defmodule RetroHexChat.VirtualSpace.CharacterRecipe do
  @moduledoc """
  A character made in the Space's creator, as one short string.

  The character is not a picture anybody uploads or a server renders: it is a
  choice among the pieces the catalog ships — a body, the outfit it wears, a
  hairstyle, a hat, a face item — and a colour from a palette for each part
  that can be dyed. That choice is what travels: on the wire, in the URL that
  walks a player through a portal, on the nickname's row. Every client composes
  the same figure from it.

      c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0

  `c1` names the format; then body, skin colour, outfit with its two colours,
  hairstyle with its colour (`h-0` is bald), headwear with its two colours
  (`w-0` is bare-headed) and face item with its colour (`f-0` is none; a
  beard takes a hair colour, glasses a fabric one). A colour is one base-36
  digit, an index into its palette. Every field is always present and in that
  order, so one character has exactly one spelling: `to_string(parse(s)) == s`.

  `parse/1` is strict and is what a message from a client goes through.
  `coerce/1` never fails: a field the catalog no longer has falls back to the
  default's, which is what a stored recipe needs when the art moves on.
  """

  import Kernel, except: [to_string: 1]

  alias RetroHexChat.Nickname
  alias RetroHexChat.VirtualSpace.CharacterCatalog, as: Catalog

  @enforce_keys [:body, :skin, :outfit, :primary, :secondary]
  defstruct [
    :body,
    :skin,
    :outfit,
    :primary,
    :secondary,
    hair: nil,
    hair_colour: 0,
    hat: nil,
    hat_primary: 0,
    hat_secondary: 0,
    face: nil,
    face_colour: 0
  ]

  @type t :: %__MODULE__{
          body: String.t(),
          skin: non_neg_integer(),
          outfit: String.t(),
          primary: non_neg_integer(),
          secondary: non_neg_integer(),
          hair: String.t() | nil,
          hair_colour: non_neg_integer(),
          hat: String.t() | nil,
          hat_primary: non_neg_integer(),
          hat_secondary: non_neg_integer(),
          face: String.t() | nil,
          face_colour: non_neg_integer()
        }

  @max_length 64
  @digits ~c"0123456789abcdefghijklmnopqrstuvwxyz"

  @doc "The longest a recipe can be; stored columns and URLs are sized from it."
  @spec max_length() :: pos_integer()
  def max_length, do: @max_length

  @doc "Parses a recipe, refusing anything the catalog cannot compose."
  @spec parse(term()) :: {:ok, t()} | {:error, :invalid_recipe}
  def parse(string) when is_binary(string) and byte_size(string) <= @max_length do
    with ["c1", b, s, o, h, w, f] <- String.split(string, "."),
         {:ok, body} <- body(b),
         {:ok, skin} <- colour(s, "s", "skin"),
         {:ok, {outfit, primary, secondary}} <- outfit(o, body),
         {:ok, {hair, hair_colour}} <- hair(h),
         {:ok, {hat, hat_primary, hat_secondary}} <- hat(w),
         {:ok, {face, face_colour}} <- face(f) do
      recipe = %__MODULE__{
        body: body,
        skin: skin,
        outfit: outfit,
        primary: primary,
        secondary: secondary,
        hair: hair,
        hair_colour: hair_colour,
        hat: hat,
        hat_primary: hat_primary,
        hat_secondary: hat_secondary,
        face: face,
        face_colour: face_colour
      }

      # One character, one spelling: "o-bas-3-0" for an outfit with no dye is
      # refused rather than kept as a second name for "o-bas-0-0".
      if to_string(recipe) == string, do: {:ok, recipe}, else: {:error, :invalid_recipe}
    else
      _ -> {:error, :invalid_recipe}
    end
  end

  def parse(_other), do: {:error, :invalid_recipe}

  @doc "Whether `string` is a recipe the catalog can compose, spelt canonically."
  @spec valid?(term()) :: boolean()
  def valid?(string), do: match?({:ok, _}, parse(string))

  @doc """
  The closest composable recipe to `value`, field by field; the default for
  anything unreadable. Never fails.
  """
  @spec coerce(term()) :: String.t()
  def coerce(value) when is_binary(value) do
    case parse(value) do
      {:ok, _} -> value
      {:error, _} -> value |> loose() |> to_string()
    end
  end

  def coerce(_other), do: Catalog.default()

  @doc "The recipe as its canonical string."
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = r) do
    Enum.join(
      [
        "c1",
        "b-" <> r.body,
        "s-" <> digit(r.skin),
        "o-#{r.outfit}-#{dye(r.primary, r.outfit, 0)}-#{dye(r.secondary, r.outfit, 1)}",
        if(r.hair, do: "h-#{r.hair}-#{digit(r.hair_colour)}", else: "h-0"),
        if(r.hat,
          do:
            "w-#{r.hat}-#{hat_dye(r.hat_primary, r.hat, 0)}-#{hat_dye(r.hat_secondary, r.hat, 1)}",
          else: "w-0"
        ),
        if(r.face, do: "f-#{r.face}-#{digit(r.face_colour)}", else: "f-0")
      ],
      "."
    )
  end

  @fields ~w(body skin outfit primary secondary hair hair_colour hat hat_primary hat_secondary face face_colour)

  @doc """
  `recipe` with one field changed, as the creator's controls change it.

  `field` is one of #{Enum.map_join(@fields, ", ", &"`#{&1}`")}; `value` is a
  catalog id (`"0"` takes a hairstyle, hat or face item off) or a colour
  index. A body that cannot wear the outfit on it changes into the first
  outfit it can. Anything the catalog cannot compose is refused.
  """
  @spec put(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_recipe}
  def put(recipe, field, value) when field in @fields and is_binary(value) do
    {:ok, current} = recipe |> coerce() |> parse()

    with {:ok, changed} <- change(current, field, value),
         string = to_string(changed),
         {:ok, _} <- parse(string) do
      {:ok, string}
    else
      _ -> {:error, :invalid_recipe}
    end
  end

  def put(_recipe, _field, _value), do: {:error, :invalid_recipe}

  defp change(r, "body", id) do
    cond do
      id not in Catalog.bodies() -> :error
      Catalog.base?(id, r.outfit) -> {:ok, %{r | body: id}}
      true -> {:ok, %{r | body: id, outfit: hd(Catalog.outfits_for(id))}}
    end
  end

  defp change(r, "outfit", id), do: {:ok, %{r | outfit: id}}

  # A face item dyed from another palette keeps its colour when that palette
  # has it, and takes the first one when it does not.
  defp change(r, "face", id) when id != "0" do
    case Catalog.face_palette(id) do
      nil ->
        :error

      palette ->
        colour = if r.face_colour < Catalog.palette_size(palette), do: r.face_colour, else: 0
        {:ok, %{r | face: id, face_colour: colour}}
    end
  end

  defp change(r, field, "0") when field in ~w(hair hat face),
    do: {:ok, Map.put(r, String.to_existing_atom(field), nil)}

  defp change(r, field, id) when field in ~w(hair hat face),
    do: {:ok, Map.put(r, String.to_existing_atom(field), id)}

  defp change(r, field, value) do
    case Integer.parse(value) do
      {n, ""} when n >= 0 -> {:ok, Map.put(r, String.to_existing_atom(field), n)}
      _ -> :error
    end
  end

  @doc "The default character."
  @spec default() :: String.t()
  def default, do: Catalog.default()

  @doc """
  A character picked at random but always the same for the same `seed`: a
  person who has not made one yet still looks like somebody, and the same
  somebody every time they come back.
  """
  @spec random(term()) :: String.t()
  def random(seed) do
    <<a::32, b::32, c::32, _::binary>> = :crypto.hash(:sha256, :erlang.term_to_binary(seed))
    state = :rand.seed_s(:exsss, {a, b, c})
    {body, state} = pick(Catalog.bodies(), state)
    {outfit, state} = pick(Catalog.outfits_for(body), state)
    {skin, state} = index("skin", state)
    {primary, state} = index("fabric", state)
    {secondary, state} = index("fabric", state)
    {hair, state} = pick([nil | Catalog.hair()], state)
    {hair_colour, state} = index("hair", state)
    {hat, state} = pick([nil | Map.keys(Catalog.headwear()) |> Enum.sort()], state)
    {hat_primary, state} = index("fabric", state)
    {hat_secondary, state} = index("fabric", state)
    {face, state} = pick([nil | Catalog.face()], state)

    {face_colour, _state} =
      if face, do: index(Catalog.face_palette(face), state), else: {0, state}

    Kernel.to_string(%__MODULE__{
      body: body,
      skin: skin,
      outfit: outfit,
      primary: primary,
      secondary: secondary,
      hair: hair,
      hair_colour: hair_colour,
      hat: hat,
      hat_primary: hat_primary,
      hat_secondary: hat_secondary,
      face: face,
      face_colour: face_colour
    })
  end

  @doc """
  The character a space dresses `nickname` in before they make one: the same
  one the space's seat for them wears (its key is `"nick:"` and the folded
  nickname), so the creator opens on the figure they were already shown as.
  """
  @spec for_nickname(String.t()) :: String.t()
  def for_nickname(nickname), do: random("nick:" <> Nickname.key(nickname))

  # --- fields ---

  defp body("b-" <> id), do: if(id in Catalog.bodies(), do: {:ok, id}, else: :error)
  defp body(_), do: :error

  defp colour(<<tag::binary-1, "-", rest::binary>>, tag, palette), do: index_of(rest, palette)
  defp colour(_, _, _), do: :error

  defp outfit("o-" <> rest, body) do
    with [id, p, s] <- String.split(rest, "-"),
         true <- Catalog.base?(body, id),
         {:ok, p} <- index_of(p, "fabric"),
         {:ok, s} <- index_of(s, "fabric") do
      {:ok, {id, p, s}}
    else
      _ -> :error
    end
  end

  defp outfit(_, _), do: :error

  defp hair("h-0"), do: {:ok, {nil, 0}}

  defp hair("h-" <> rest) do
    with [id, c] <- String.split(rest, "-"),
         true <- id in Catalog.hair(),
         {:ok, c} <- index_of(c, "hair") do
      {:ok, {id, c}}
    else
      _ -> :error
    end
  end

  defp hair(_), do: :error

  defp hat("w-0"), do: {:ok, {nil, 0, 0}}

  defp hat("w-" <> rest) do
    with [id, p, s] <- String.split(rest, "-"),
         true <- Map.has_key?(Catalog.headwear(), id),
         {:ok, p} <- index_of(p, "fabric"),
         {:ok, s} <- index_of(s, "fabric") do
      {:ok, {id, p, s}}
    else
      _ -> :error
    end
  end

  defp hat(_), do: :error

  defp face("f-0"), do: {:ok, {nil, 0}}

  defp face("f-" <> rest) do
    with [id, c] <- String.split(rest, "-"),
         palette when is_binary(palette) <- Catalog.face_palette(id),
         {:ok, c} <- index_of(c, palette) do
      {:ok, {id, c}}
    else
      _ -> :error
    end
  end

  defp face(_), do: :error

  defp index_of(<<char>>, palette) do
    case Enum.find_index(@digits, &(&1 == char)) do
      nil -> :error
      i -> if i < Catalog.palette_size(palette), do: {:ok, i}, else: :error
    end
  end

  defp index_of(_, _), do: :error

  # An index past the digits spells a character no parse accepts.
  defp digit(i) when is_integer(i) and i >= 0 and i < 36, do: <<Enum.at(@digits, i)>>
  defp digit(_i), do: "?"

  # A colour slot the piece does not have is spelt 0, so it cannot make a
  # second name for the same character.
  defp dye(i, outfit, slot),
    do: if(slot < Map.get(Catalog.outfits(), outfit, 0), do: digit(i), else: "0")

  defp hat_dye(i, hat, slot),
    do: if(slot < Map.get(Catalog.headwear(), hat, 0), do: digit(i), else: "0")

  # --- coerce ---

  defp loose(value) do
    {:ok, base} = parse(Catalog.default())

    case String.split(value, ".") do
      ["c1", b, s, o, h, w, f] ->
        body = ok_or(body(b), base.body)
        skin = ok_or(colour(s, "s", "skin"), base.skin)

        {outfit, primary, secondary} =
          ok_or(outfit(o, body), fallback_outfit(base, body))

        {hair, hair_colour} = ok_or(hair(h), {base.hair, base.hair_colour})

        {hat, hat_primary, hat_secondary} =
          ok_or(hat(w), {base.hat, base.hat_primary, base.hat_secondary})

        {face, face_colour} = ok_or(face(f), {base.face, base.face_colour})

        %__MODULE__{
          body: body,
          skin: skin,
          outfit: outfit,
          primary: primary,
          secondary: secondary,
          hair: hair,
          hair_colour: hair_colour,
          hat: hat,
          hat_primary: hat_primary,
          hat_secondary: hat_secondary,
          face: face,
          face_colour: face_colour
        }

      _ ->
        base
    end
  end

  defp fallback_outfit(base, body) do
    if Catalog.base?(body, base.outfit),
      do: {base.outfit, base.primary, base.secondary},
      else: {hd(Catalog.outfits_for(body)), base.primary, base.secondary}
  end

  defp ok_or({:ok, value}, _default), do: value
  defp ok_or(_error, default), do: default

  defp pick(list, state) do
    {i, state} = :rand.uniform_s(length(list), state)
    {Enum.at(list, i - 1), state}
  end

  defp index(palette, state) do
    {i, state} = :rand.uniform_s(Catalog.palette_size(palette), state)
    {i - 1, state}
  end

  defimpl String.Chars do
    alias RetroHexChat.VirtualSpace.CharacterRecipe

    def to_string(recipe), do: CharacterRecipe.to_string(recipe)
  end
end
