defmodule RetroHexChatWeb.CharacterPortraitTest do
  @moduledoc """
  The chat's portrait of a character is the creator's own pieces, recoloured
  and stacked exactly as the space composes them. The golden images are
  written by the reference compositor (`virtual.space/tools/build_creator.py`
  → `creator_contact_sheet.write_goldens/1`); the server must draw the same
  pixels.
  """
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  alias RetroHexChat.VirtualSpace.CharacterCatalog
  alias RetroHexChatWeb.CharacterPortrait
  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  @goldens Path.expand("../fixtures/character_portraits", __DIR__)

  test "every golden portrait is drawn pixel for pixel" do
    files = Path.wildcard(Path.join(@goldens, "*.png"))
    assert files != []

    for file <- files do
      recipe = Path.basename(file, ".png")
      assert {:ok, png} = CharacterPortrait.png(recipe)

      assert pixels(png) == pixels(File.read!(file)),
             "#{recipe} is not the portrait the art draws"
    end
  end

  test "a recipe the art cannot compose has no portrait" do
    assert {:error, :invalid_recipe} = CharacterPortrait.png("knight")
  end

  test "patching a palette rewrites the entries and the chunk's CRC" do
    crop =
      File.read!(
        Path.expand("../../priv/static/images/space/creator/portrait_hair-lng.png", __DIR__)
      )

    patched = CharacterPortrait.patch_plte(crop, [{1, [1, 2, 3]}])

    assert byte_size(patched) == byte_size(crop)
    assert {plte, crc} = plte_chunk(patched)
    assert binary_part(plte, 3, 3) == <<1, 2, 3>>
    assert crc == :erlang.crc32("PLTE" <> plte)
    # Every other entry is as it was.
    {original, _crc} = plte_chunk(crop)

    assert binary_part(plte, 6, byte_size(plte) - 6) ==
             binary_part(original, 6, byte_size(original) - 6)

    assert {:ok, _image} = Image.new_from_buffer(patched)
  end

  defp plte_chunk(<<_signature::binary-8, chunks::binary>>), do: find_plte(chunks)

  defp find_plte(<<length::32, "PLTE", data::binary-size(length), crc::32, _::binary>>),
    do: {data, crc}

  defp find_plte(
         <<length::32, _type::binary-4, _data::binary-size(length), _crc::32, rest::binary>>
       ),
       do: find_plte(rest)

  describe "GET /character-portrait/:version/:recipe" do
    test "serves the portrait for good", %{conn: conn} do
      conn = get(conn, CharacterPortrait.path(CharacterCatalog.default()))

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["image/png"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end

    test "is a 404 for a recipe the art cannot compose, or an old version", %{conn: conn} do
      assert conn
             |> get("/character-portrait/#{CharacterCatalog.version()}/knight")
             |> response(404)

      assert conn |> get("/character-portrait/old/#{CharacterCatalog.default()}") |> response(404)
    end
  end

  defp pixels(png) do
    {:ok, image} = Image.new_from_buffer(png)

    image =
      if Image.bands(image) == 4,
        do: image,
        else: elem(Operation.bandjoin_const(image, [255.0]), 1)

    {:ok, bytes} = Image.write_to_binary(image)
    bytes
  end
end
