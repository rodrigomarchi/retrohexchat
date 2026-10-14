defmodule RetroHexChat.VirtualSpace.CharacterRecipeTest do
  @moduledoc """
  A character is a short string: one spelling per character, nothing the art
  cannot compose let through, and a stored one always readable.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :unit

  alias RetroHexChat.VirtualSpace.CharacterCatalog, as: Catalog
  alias RetroHexChat.VirtualSpace.CharacterRecipe

  test "the default parses, and prints back as itself" do
    default = CharacterRecipe.default()
    assert {:ok, recipe} = CharacterRecipe.parse(default)
    assert CharacterRecipe.to_string(recipe) == default
  end

  property "a random character is always one the art can compose, the same for the same seed" do
    check all(seed <- term(), max_runs: 200) do
      recipe = CharacterRecipe.random(seed)
      assert CharacterRecipe.valid?(recipe)
      assert CharacterRecipe.random(seed) == recipe
      assert byte_size(recipe) <= CharacterRecipe.max_length()
    end
  end

  property "coerce never fails and always answers with a valid recipe" do
    check all(value <- one_of([string(:printable), constant(nil), integer()]), max_runs: 300) do
      assert CharacterRecipe.valid?(CharacterRecipe.coerce(value))
    end
  end

  test "coerce keeps every field it can read and replaces the rest" do
    assert CharacterRecipe.coerce("c1.b-av.s-7.o-gone-1-2.h-lng-5.w-0.f-0") ==
             "c1.b-av.s-7.o-tun-0-3.h-lng-5.w-0.f-0"
  end

  describe "parse/1 refuses" do
    test "a class name from before the creator" do
      assert {:error, :invalid_recipe} = CharacterRecipe.parse("knight")
    end

    test "a piece the catalog does not have" do
      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse("c1.b-av.s-2.o-tun-0-3.h-afro-2.w-0.f-0")
    end

    test "a colour past the end of its palette" do
      past = Integer.to_string(Catalog.palette_size("skin"), 36) |> String.downcase()

      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse("c1.b-av.s-#{past}.o-tun-0-3.h-0.w-0.f-0")
    end

    test "a second spelling of the same character" do
      # The undershirt has no dye, so its colours are spelt 0.
      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse("c1.b-av.s-2.o-bas-4-0.h-0.w-0.f-0")
    end

    test "fields out of order, or too many" do
      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse("c1.s-2.b-av.o-tun-0-3.h-0.w-0.f-0")

      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse(CharacterRecipe.default() <> ".x-1")
    end
  end

  describe "put/3" do
    test "changes one field" do
      assert {:ok, "c1.b-av.s-7.o-tun-0-3.h-lng-2.w-0.f-0"} =
               CharacterRecipe.put(CharacterRecipe.default(), "skin", "7")
    end

    test "takes a hairstyle off with 0" do
      assert {:ok, recipe} = CharacterRecipe.put(CharacterRecipe.default(), "hair", "0")
      assert {:ok, %{hair: nil}} = CharacterRecipe.parse(recipe)
    end

    test "a face item takes its colour from the palette it is dyed from" do
      # Glasses in the last cloth colour, which no hair palette has.
      index = Catalog.palette_size("fabric") - 1
      last = Integer.to_string(index, 36) |> String.downcase()
      assert Catalog.palette_size("hair") < Catalog.palette_size("fabric")
      assert {:ok, glasses} = CharacterRecipe.put(CharacterRecipe.default(), "face", "gls")

      assert {:ok, glasses} =
               CharacterRecipe.put(glasses, "face_colour", Integer.to_string(index))

      assert String.ends_with?(glasses, ".f-gls-" <> last)

      # A beard cannot be that colour: it is dyed from the hair palette, and
      # changing to it starts on the first colour instead.
      assert {:ok, beard} = CharacterRecipe.put(glasses, "face", "brd")
      assert String.ends_with?(beard, ".f-brd-0")

      assert {:error, :invalid_recipe} =
               CharacterRecipe.put(beard, "face_colour", Integer.to_string(index))

      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse(String.replace(beard, "f-brd-0", "f-brd-" <> last))

      assert {:error, :invalid_recipe} =
               CharacterRecipe.parse(String.replace(beard, "f-brd-0", "f-brd"))

      assert {:ok, bare} = CharacterRecipe.put(beard, "face", "0")
      assert String.ends_with?(bare, ".f-0")
    end

    test "refuses what the art cannot compose" do
      assert {:error, :invalid_recipe} =
               CharacterRecipe.put(CharacterRecipe.default(), "hat", "crown")

      assert {:error, :invalid_recipe} =
               CharacterRecipe.put(CharacterRecipe.default(), "skin", "99")

      assert {:error, :invalid_recipe} =
               CharacterRecipe.put(CharacterRecipe.default(), "nose", "1")
    end
  end
end
