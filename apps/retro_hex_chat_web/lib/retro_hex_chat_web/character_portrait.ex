defmodule RetroHexChatWeb.CharacterPortrait do
  @moduledoc """
  The face of a Space character, for the chat to draw beside a nickname.

  A character is a creator recipe (`RetroHexChat.VirtualSpace.CharacterRecipe`)
  and its pieces are indexed PNGs; the creator's build cuts each piece's head
  out of its first south-facing idle frame (`portrait_<layer>.png`). A portrait
  is those crops recoloured and stacked — base, face, hair, hat, the hair cut
  where the hat hides it — exactly as the browser composes the character in the
  space (`assets/js/lib/space/character_compositor.js`): the colours are
  written into each crop's palette (`patch_plte/2`, the same bytes the browser
  patches), so both draw the same pixels.

  Two more views are cut from the same frame for the creator, which pictures
  each piece on the character being made: the *figure*, the whole character
  (`figure_<layer>.png`), for an outfit, and the *head*, everything worn on
  the head (`head_<layer>.png`), for hair, headwear and face items.

  Composed on request: a portrait is a few hundred pixels, and its URL carries
  the catalog version, so the browser keeps it as long as the art is unchanged.
  The crops are read when this module is compiled and carried in it, so a
  release needs no file of the source tree at runtime.
  """

  alias RetroHexChat.VirtualSpace.CharacterCatalog
  alias RetroHexChat.VirtualSpace.CharacterRecipe
  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  @static Path.expand("../../priv/static", __DIR__)
  @catalog_path Path.join(@static, "images/space/creator/catalog.json")
  @external_resource @catalog_path
  @catalog @catalog_path |> File.read!() |> JSON.decode!()

  # Every crop the catalog names, keyed by its URL.
  @crops (for {_name, layer} <- @catalog["layers"],
              key <- ["portrait", "portraitMask", "figure", "figureMask", "head", "headMask"],
              %{"url" => url} <- [layer[key]],
              into: %{} do
            path = Path.join(@static, url |> String.split("?") |> hd())
            {url, File.read!(path)}
          end)
  for {url, _bytes} <- @crops,
      do: @external_resource(Path.join(@static, url |> String.split("?") |> hd()))

  @typedoc "Which still of a character: the chat's face, the whole of it, or all it wears on its head."
  @type view :: :portrait | :figure | :head

  @views [:portrait, :figure, :head]

  @doc "The address of a recipe's still: its portrait, or the `:figure` or `:head` view."
  @spec path(String.t(), view()) :: String.t()
  def path(recipe, view \\ :portrait)
  def path(recipe, :portrait), do: "/character-portrait/#{CharacterCatalog.version()}/#{recipe}"

  def path(recipe, view) when view in [:figure, :head],
    do: "/character-still/#{view}/#{CharacterCatalog.version()}/#{recipe}"

  @doc "The portrait's side, in pixels."
  @spec size() :: pos_integer()
  def size, do: @catalog["portrait"]["rect"] |> Enum.at(2)

  @doc "A view's width and height, in pixels."
  @spec dimensions(view()) :: {pos_integer(), pos_integer()}
  def dimensions(view) do
    [_x, _y, w, h] = @catalog[Atom.to_string(view)]["rect"]
    {w, h}
  end

  @doc "A recipe's still as PNG bytes, or an error for a recipe the art cannot compose."
  @spec png(String.t(), view()) :: {:ok, binary()} | {:error, :invalid_recipe}
  def png(recipe, view \\ :portrait) when view in @views do
    with {:ok, parsed} <- CharacterRecipe.parse(recipe) do
      {w, h} = dimensions(view)

      {:ok, image} =
        Image.new_from_binary(
          pixels(plan(parsed), Atom.to_string(view), w, h),
          w,
          h,
          4,
          :VIPS_FORMAT_UCHAR
        )

      Image.write_to_buffer(image, ".png")
    end
  end

  # The pieces stacked, base first, on a clear w×h canvas. The overlays move
  # by the base's head offset, as the space's compositor moves them.
  defp pixels([{base, :base, _} | _] = layers, view, w, h) do
    hat = Enum.find_value(layers, &cutting_hat(&1, view))
    [dx, dy] = @catalog["layers"][base]["delta"]["idle"] |> hd() |> hd()
    clear = :binary.copy(<<0, 0, 0, 0>>, w * h)

    Enum.reduce(layers, clear, fn layer, acc ->
      over(acc, placed(layer, view, hat, w, h, dx, dy))
    end)
  end

  defp placed({_name, :base, _colours} = layer, view, hat, _w, _h, _dx, _dy),
    do: layer_pixels(layer, view, hat)

  defp placed(layer, view, hat, w, h, dx, dy),
    do: layer |> layer_pixels(view, hat) |> shift(w, h, dx, dy)

  # A hat that hides the hair under it carries a mask; one that does not, cuts nothing.
  defp cutting_hat({name, :hat, _}, view),
    do: if(Map.has_key?(@catalog["layers"][name], view <> "Mask"), do: name)

  defp cutting_hat(_layer, _view), do: nil

  # `pixels` (w×h RGBA) moved by (dx, dy), clear where nothing moved in.
  defp shift(pixels, _w, _h, 0, 0), do: pixels

  defp shift(pixels, w, h, dx, dy) do
    for y <- 0..(h - 1), x <- 0..(w - 1), into: <<>> do
      {sx, sy} = {x - dx, y - dy}

      if sx in 0..(w - 1) and sy in 0..(h - 1),
        do: binary_part(pixels, (sy * w + sx) * 4, 4),
        else: <<0, 0, 0, 0>>
    end
  end

  # A piece's crop; the hair cut where the hat (if any) covers it.
  defp layer_pixels({name, :hair, colours}, view, hat) when is_binary(hat),
    do: cut(rgba(name, view, colours), rgba(hat, view <> "Mask", %{}))

  defp layer_pixels({name, _kind, colours}, view, _hat), do: rgba(name, view, colours)

  defp plan(r) do
    [
      {"base-#{r.body}-#{r.outfit}", :base,
       %{"skin" => r.skin, "primary" => r.primary, "secondary" => r.secondary}}
    ] ++
      if(r.face,
        do: [{"face-#{r.face}", :face, %{face_channel(r.face) => r.face_colour}}],
        else: []
      ) ++
      if(r.hair, do: [{"hair-#{r.hair}", :hair, %{"hair" => r.hair_colour}}], else: []) ++
      if(r.hat,
        do: [
          {"hat-#{r.hat}", :hat, %{"primary" => r.hat_primary, "secondary" => r.hat_secondary}}
        ],
        else: []
      )
  end

  # The channel a face item is dyed through: its palette follows from it.
  defp face_channel(id), do: @catalog["items"]["face"][id]["channel"]

  # A layer's crop, recoloured, as raw RGBA bytes.
  defp rgba(name, kind, colours) do
    layer = Map.fetch!(@catalog["layers"], name)
    png = file(get_in(layer, [kind, "url"]))
    # A crop is dyed; a mask (what a hat hides) is only ever a shape.
    entries = if String.ends_with?(kind, "Mask"), do: [], else: entries(layer, colours)
    {:ok, image} = png |> patch_plte(entries) |> Image.new_from_buffer()
    image = if Image.bands(image) == 4, do: image, else: with_alpha(image)
    {:ok, bytes} = Image.write_to_binary(image)
    bytes
  end

  defp with_alpha(image) do
    {:ok, image} = Operation.bandjoin_const(image, [255.0])
    image
  end

  defp entries(layer, colours) do
    for {channel, indices} <- layer["channels"],
        Map.has_key?(colours, channel),
        palette = @catalog["palettes"][@catalog["channelPalette"][channel]],
        ramp = Enum.at(palette, rem(colours[channel], length(palette))),
        {index, shade} <- Enum.with_index(indices),
        do: {index, Enum.at(ramp, shade)}
  end

  defp file(url), do: Map.fetch!(@crops, url)

  # Pixel art is fully opaque or fully clear, so "over" is a choice per pixel.
  defp over(below, above) do
    for <<b::binary-4 <- below>>, reduce: {<<>>, above} do
      {acc, <<a::binary-4, rest::binary>>} ->
        <<_::24, alpha>> = a
        {<<acc::binary, if(alpha >= 128, do: a, else: b)::binary>>, rest}
    end
    |> elem(0)
  end

  defp cut(piece, mask) do
    for <<p::binary-4 <- piece>>, reduce: {<<>>, mask} do
      {acc, <<_::24, m, rest::binary>>} ->
        {<<acc::binary, if(m >= 128, do: <<0, 0, 0, 0>>, else: p)::binary>>, rest}
    end
    |> elem(0)
  end

  @doc """
  `png` with palette entries replaced: `entries` is a list of
  `{index, [r, g, b]}`. The chunk's CRC is recomputed; nothing else changes.
  """
  @spec patch_plte(binary(), [{non_neg_integer(), [0..255]}]) :: binary()
  def patch_plte(png, []), do: png

  def patch_plte(<<signature::binary-8, chunks::binary>>, entries) do
    signature <> patch_chunks(chunks, Map.new(entries))
  end

  defp patch_chunks(
         <<length::32, "PLTE", data::binary-size(length), _crc::32, rest::binary>>,
         entries
       ) do
    patched =
      for i <- 0..(div(length, 3) - 1), into: <<>> do
        case Map.fetch(entries, i) do
          {:ok, [r, g, b]} -> <<r, g, b>>
          :error -> binary_part(data, i * 3, 3)
        end
      end

    <<length::32, "PLTE", patched::binary, :erlang.crc32("PLTE" <> patched)::32, rest::binary>>
  end

  defp patch_chunks(
         <<length::32, type::binary-4, data::binary-size(length), crc::32, rest::binary>>,
         entries
       ) do
    <<length::32, type::binary, data::binary, crc::32, patch_chunks(rest, entries)::binary>>
  end

  defp patch_chunks(<<>>, _entries), do: <<>>
end
