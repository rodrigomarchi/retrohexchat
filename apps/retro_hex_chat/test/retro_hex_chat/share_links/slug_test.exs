defmodule RetroHexChat.ShareLinks.SlugTest do
  @moduledoc """
  What a share slug has to be, and why each property is not decoration.

  A slug goes in a chat message, a browser address bar and a social post, and it
  is read aloud and retyped. It is also the only thing between a stranger and
  knowing that a room exists, so its size is a security parameter.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.ShareLinks.Slug

  test "carries nothing a URL would have to escape" do
    for _ <- 1..200 do
      assert Slug.generate() =~ ~r/\A[a-z2-9]+\z/
    end
  end

  # Someone reads a slug off a screen and types it on a phone. The characters
  # that get confused doing that are excluded, which is also why the alphabet is
  # 31 and not 36.
  test "excludes the characters people confuse when retyping" do
    for _ <- 1..200 do
      refute Slug.generate() =~ ~r/[01ilo]/
    end
  end

  test "is one fixed length, so a truncated slug is not a valid one" do
    lengths = for _ <- 1..200, into: MapSet.new(), do: String.length(Slug.generate())

    assert MapSet.size(lengths) == 1
    assert Slug.length() in MapSet.to_list(lengths)
  end

  test "does not repeat itself over a run long enough to notice" do
    slugs = for _ <- 1..5_000, into: MapSet.new(), do: Slug.generate()

    assert MapSet.size(slugs) == 5_000
  end

  # The alphabet and the length together are what make guessing a live link
  # impractical; the number is asserted so shortening the slug has to argue with
  # a test rather than slip through as a cosmetic change.
  test "is wide enough that guessing is not a strategy" do
    assert Slug.alphabet_size() == 31
    assert Slug.length() == 10
    assert :math.pow(Slug.alphabet_size(), Slug.length()) > 1.0e14
  end

  describe "valid?/1" do
    test "accepts what generate/0 produces" do
      assert Slug.valid?(Slug.generate())
    end

    test "refuses the wrong length, the wrong alphabet, and non-strings" do
      refute Slug.valid?("")
      refute Slug.valid?(String.duplicate("a", Slug.length() - 1))
      refute Slug.valid?(String.duplicate("a", Slug.length() + 1))
      refute Slug.valid?(String.duplicate("A", Slug.length()))
      refute Slug.valid?(String.duplicate("l", Slug.length()))
      refute Slug.valid?(nil)
      refute Slug.valid?(:atom)
    end
  end
end
