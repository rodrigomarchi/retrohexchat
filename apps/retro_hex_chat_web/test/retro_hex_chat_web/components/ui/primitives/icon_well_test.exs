defmodule RetroHexChatWeb.Components.UI.IconWellTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.IconWell

  @moduletag :unit

  defp well(assigns) do
    ~H"""
    <.icon_well size={@size} data-testid="well"><span>i</span></.icon_well>
    """
  end

  test "each size is its own square, pressed in" do
    for {size, square} <- [{"sm", "h-8 w-8"}, {"md", "h-10 w-10"}, {"lg", "h-12 w-12"}] do
      html = render_component(&well/1, %{size: size})

      assert html =~ square
      assert html =~ "shadow-retro-sunken"
      assert html =~ ~s(data-testid="well")
    end
  end
end
