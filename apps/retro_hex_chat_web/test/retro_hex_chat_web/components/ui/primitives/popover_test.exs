defmodule RetroHexChatWeb.Components.UI.PopoverTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.DropdownMenu
  import RetroHexChatWeb.Components.UI.Popover

  alias Phoenix.LiveView.JS

  @moduletag :unit

  defp render_popover(placement) do
    assigns = %{placement: placement}

    rendered_to_string(~H"""
    <.popover label="Summary" placement={@placement} trigger_testid="toggle" panel_testid="panel">
      <:trigger>i</:trigger>
      body
    </.popover>
    """)
  end

  test "is a details element the browser side can keep open and close like a menu" do
    html = render_popover("below-end")

    # `data-popover` is what the browser side keys on: it keeps the open state
    # across patches and closes the popover on a click outside or Escape.
    assert html =~ "<details"
    assert html =~ "data-popover"
    refute html =~ "remove_attr"
    assert html =~ ~s(aria-label="Summary")
    assert html =~ ~s(data-testid="toggle")
    assert html =~ ~s(data-testid="panel")
  end

  test "hangs the panel from the edge the placement names" do
    assert render_popover("below-end") =~ "top-full"
    assert render_popover("above-end") =~ "bottom-full right-0"
    assert render_popover("above") =~ "-translate-x-1/2"
  end

  test "close_after runs the action and then closes the popover it sits in" do
    %JS{ops: ops} = close_after("lock")

    assert [
             ["push", %{event: "lock"}],
             ["dispatch", %{event: "rhc:popover-close"}]
           ] =
             ops
  end

  test "menu rows are buttons, and a destructive row says so in its words" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.dropdown_menu label="Moderation">
        <:trigger>M</:trigger>
        <.dropdown_menu_item checked>
          <:icon>i</:icon>
          Lock
        </.dropdown_menu_item>
        <.dropdown_menu_item tone="danger">
          <:icon>i</:icon>
          End
        </.dropdown_menu_item>
      </.dropdown_menu>
      """)

    assert html =~ ~s(role="menu")
    assert html =~ ~s(aria-haspopup="menu")
    assert html =~ "icon_checkmark"
    assert html =~ ~s(<button type="button" role="menuitemcheckbox")
    assert html =~ ~s(aria-checked="true")
    assert html =~ "text-error-dark"
  end
end
