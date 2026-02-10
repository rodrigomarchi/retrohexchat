defmodule RetroHexChatWeb.Components.WindowTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Window

  describe "window/1" do
    test "renders title" do
      html =
        render_component(&Window.window/1,
          title: "My Window",
          class: "",
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Window content" end}]
        )

      assert html =~ "My Window"
      assert html =~ "title-bar-text"
    end

    test "renders inner block content" do
      html =
        render_component(&Window.window/1,
          title: "Test",
          class: "",
          inner_block: [
            %{__slot__: :inner_block, inner_block: fn _, _ -> "Inner content here" end}
          ]
        )

      assert html =~ "Inner content here"
      assert html =~ "window-body"
    end

    test "applies custom class" do
      html =
        render_component(&Window.window/1,
          title: "Test",
          class: "custom-class",
          inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "Content" end}]
        )

      assert html =~ "custom-class"
    end
  end
end
