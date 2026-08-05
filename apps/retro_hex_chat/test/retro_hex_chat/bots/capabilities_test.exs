defmodule RetroHexChat.Bots.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Bots.Capabilities

  @moduletag :unit

  describe "module_for/1" do
    test "resolves the stored string form and the atom to the same module" do
      assert Capabilities.module_for("rss") == Capabilities.module_for(:rss)
      assert Capabilities.module_for(:rss) == RetroHexChat.Bots.Capabilities.RSS
    end

    test "an unknown capability resolves to nothing rather than crashing the reader" do
      assert Capabilities.module_for("telepathy") == nil
      assert Capabilities.describe("telepathy") == nil
    end

    test "a name that is not an existing atom does not create one" do
      name = "never_a_capability_#{System.unique_integer([:positive])}"

      assert Capabilities.module_for(name) == nil
      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end
  end

  describe "describe/1" do
    test "every catalogued capability can say what it is for" do
      for {name, _module} <- Capabilities.modules() do
        assert is_binary(Capabilities.describe(name))
        assert Capabilities.describe(name) != ""
      end
    end
  end

  describe "stub?/1" do
    test "marks the three capabilities that answer nothing" do
      assert Capabilities.stub?("game")
      assert Capabilities.stub?(:llm)
      assert Capabilities.stub?("script")
      refute Capabilities.stub?("rss")
    end
  end
end
