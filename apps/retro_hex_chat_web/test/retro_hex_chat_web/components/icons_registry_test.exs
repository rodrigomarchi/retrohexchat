defmodule RetroHexChatWeb.Icons.RegistryTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.Icons.Registry

  @moduletag :unit

  # `function_exported?/3` answers for loaded modules only, and nothing has
  # forced these two yet when the suite starts cold.
  setup_all do
    Code.ensure_loaded!(RetroHexChatWeb.Icons)
    Enum.each(Registry.all(), fn {_name, module} -> Code.ensure_loaded!(module) end)
    :ok
  end

  describe "all/0" do
    test "every registered icon points at a module that actually draws it" do
      missing =
        for {name, module} <- Registry.all(),
            not function_exported?(module, name, 1),
            do: {module, name}

      assert missing == [],
             "registry names an art function that does not exist: #{inspect(missing)}"
    end

    test "the facade exposes every registered icon as a component" do
      missing =
        for {name, _module} <- Registry.all(),
            not function_exported?(RetroHexChatWeb.Icons, name, 1),
            do: name

      assert missing == [], "registered but absent from the facade: #{inspect(missing)}"
    end

    test "no icon is registered twice" do
      names = Enum.map(Registry.all(), &elem(&1, 0))

      assert names == Enum.uniq(names)
    end

    test "the whole icon library is registered, not a subset" do
      # A shrinking registry silently drops icons from the sprite and leaves
      # their <use> dangling, so the count is pinned. Raise it deliberately
      # when you add an icon.
      assert length(Registry.all()) >= 344
    end
  end

  describe "flag/1 and game/1" do
    test "a known locale and a known game resolve to registered icons" do
      registered = Map.new(Registry.all())

      assert Map.has_key?(registered, Registry.flag("pt_BR"))
      assert Map.has_key?(registered, Registry.game("hex_pong"))
    end

    test "an unknown locale and an unknown game fall back to registered icons" do
      registered = Map.new(Registry.all())

      assert Map.has_key?(registered, Registry.flag("kl_GL"))
      assert Map.has_key?(registered, Registry.game("no_such_game"))
    end
  end

  describe "sprite ids" do
    test "every icon id is a valid, collision-free SVG fragment id" do
      ids = Enum.map(Registry.all(), fn {name, _} -> Registry.sprite_id(name) end)

      assert ids == Enum.uniq(ids)
      assert Enum.all?(ids, &Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, &1))
    end
  end
end
