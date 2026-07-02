defmodule RetroHexChatWeb.Components.UI.DialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Dialog

  @moduletag :unit

  defp render_dialog(assigns) do
    render_component(
      &dialog/1,
      Keyword.merge(
        [
          id: "test-dialog",
          inner_block: %{inner_block: fn _, _ -> "body" end}
        ],
        assigns
      )
    )
  end

  describe "dialog/1 scope" do
    test "viewport scope (default) overlays the whole screen" do
      html = render_dialog([])

      # Overlay and centering container are fixed to the viewport.
      assert html =~ ~s(id="test-dialog-bg" class="fixed inset-0)
      assert html =~ ~s(class="fixed inset-0 flex items-center justify-center)
      # Mobile takes the full dynamic viewport height.
      assert html =~ "min-h-[100dvh]"
    end

    test "window scope anchors to the enclosing desktop window" do
      html = render_dialog(scope: :window)

      # Overlay and centering container anchor to the nearest positioned
      # ancestor (the desktop window root), not the viewport.
      assert html =~ ~s(id="test-dialog-bg" class="absolute inset-0)
      assert html =~ ~s(class="absolute inset-0 flex items-center justify-center)
      refute html =~ "fixed inset-0"
      # The frame fits the window instead of claiming the viewport height.
      refute html =~ "min-h-[100dvh]"
      assert html =~ "max-h-full"
    end
  end
end
