defmodule RetroHexChatWeb.Components.CommandPaletteTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.CommandPalette

  describe "command_palette/1" do
    test "does not render when not visible" do
      html =
        render_component(&CommandPalette.command_palette/1,
          visible: false,
          commands: ["join"],
          filter: ""
        )

      refute html =~ "command-palette"
    end

    test "renders all commands when visible" do
      html =
        render_component(&CommandPalette.command_palette/1,
          visible: true,
          commands: ["join", "part", "nick"],
          filter: ""
        )

      assert html =~ "/join"
      assert html =~ "/part"
      assert html =~ "/nick"
    end

    test "filters commands by prefix" do
      html =
        render_component(&CommandPalette.command_palette/1,
          visible: true,
          commands: ["join", "part", "nick"],
          filter: "jo"
        )

      assert html =~ "/join"
      refute html =~ "/part"
      refute html =~ "/nick"
    end
  end
end
