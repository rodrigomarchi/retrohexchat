defmodule RetroHexChat.Commands.Handlers.AliasTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Alias

  @context %{
    nickname: "Test",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: false,
    operator_in: []
  }

  describe "validate/1" do
    test "accepts empty string (bare /alias)" do
      assert :ok = Alias.validate("")
    end

    test "accepts add subcommand" do
      assert :ok = Alias.validate("add hi /me says hello!")
    end

    test "rejects add without name" do
      assert {:error, _} = Alias.validate("add")
    end

    test "rejects add with name but no expansion" do
      assert {:error, _} = Alias.validate("add hi")
    end

    test "accepts remove subcommand" do
      assert :ok = Alias.validate("remove hi")
    end

    test "rejects remove without name" do
      assert {:error, _} = Alias.validate("remove")
    end

    test "accepts list subcommand" do
      assert :ok = Alias.validate("list")
    end
  end

  describe "execute/2" do
    test "bare /alias opens alias dialog" do
      assert {:ok, :ui_action, :open_alias_dialog, %{}} = Alias.execute([], @context)
    end

    test "add returns alias_added with name and expansion" do
      assert {:ok, :ui_action, :alias_added, %{name: "hi", expansion: "/me says hello!"}} =
               Alias.execute(["add", "hi", "/me", "says", "hello!"], @context)
    end

    test "remove returns alias_removed with name" do
      assert {:ok, :ui_action, :alias_removed, %{name: "hi"}} =
               Alias.execute(["remove", "hi"], @context)
    end

    test "list returns alias_list_display ui_action" do
      assert {:ok, :ui_action, :alias_list_display, %{}} = Alias.execute(["list"], @context)
    end
  end

  describe "help/0" do
    test "returns help map with correct name" do
      help = Alias.help()
      assert help.name == "alias"
    end

    test "returns help map with syntax string" do
      help = Alias.help()
      assert is_binary(help.syntax)
      assert help.syntax =~ "/alias"
    end

    test "returns help map with description" do
      help = Alias.help()
      assert is_binary(help.description)
    end

    test "returns help map with examples list" do
      help = Alias.help()
      assert [_ | _] = help.examples
    end
  end
end
