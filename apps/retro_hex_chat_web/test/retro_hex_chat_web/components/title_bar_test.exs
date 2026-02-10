defmodule RetroHexChatWeb.Components.TitleBarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.TitleBar

  describe "title_bar/1" do
    test "renders default title" do
      html = render_component(&TitleBar.title_bar/1, %{})
      assert html =~ "RetroHexChat"
      assert html =~ "title-bar-text"
    end

    test "renders custom title" do
      html = render_component(&TitleBar.title_bar/1, title: "Custom Title")
      assert html =~ "Custom Title"
    end
  end
end
