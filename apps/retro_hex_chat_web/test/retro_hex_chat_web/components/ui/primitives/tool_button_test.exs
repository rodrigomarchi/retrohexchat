defmodule RetroHexChatWeb.Components.UI.ToolButtonTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ToolButton

  @moduletag :unit

  test "raised is the default look and carries the bevel" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tool_button label="Mute">i</.tool_button>
      """)

    assert html =~ "shadow-retro-raised"
    assert html =~ ~s(type="button")
    refute html =~ "media-dock-button"
  end

  test "the label is both the tooltip and the accessible name" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tool_button label="Open stats">i</.tool_button>
      """)

    assert html =~ ~s(title="Open stats")
    assert html =~ ~s(aria-label="Open stats")
  end

  test "a button named by its visible content keeps the label as tooltip only" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tool_button label="Show the users list" named_by_content size="xs">Users</.tool_button>
      """)

    assert html =~ ~s(title="Show the users list")
    refute html =~ "aria-label"
  end

  test "flat has no chrome at rest and rises under the pointer" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tool_button label="Layout" variant="flat">i</.tool_button>
      """)

    assert html =~ "bg-transparent"
    assert html =~ "hover:shadow-retro-raised"
    assert html =~ "disabled:hover:shadow-none"
  end

  test "active and pressed are separate: drawn sunken, announced independently" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tool_button label="Microphone" variant="flat" active pressed={false}>i</.tool_button>
      """)

    assert html =~ "bg-hover-bg"
    assert html =~ ~r/(^|[\s"])shadow-retro-sunken/
    assert html =~ ~s(aria-pressed="false")
  end

  test "disabled reaches the element and a caller's class wins over the size" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.tool_button label="Mute" variant="flat" size="xs" class="h-full w-full" disabled>
        i
      </.tool_button>
      """)

    assert html =~ "disabled"
    assert html =~ "h-full"
    refute html =~ ~r/[\s"]h-\[22px\]/
  end

  test "title-bar controls are 16 by 14" do
    assert tool_button_class(size: "title") =~ "w-[16px]"
    assert tool_button_class(size: "title") =~ "h-[14px]"
  end

  test "sizes keep the dimensions the toolbars were laid out for" do
    for {size, px} <- [{"xs", "22px"}, {"sm", "24px"}, {"md", "34px"}] do
      assert tool_button_class(size: size) =~ "h-[#{px}]"
    end

    assert tool_button_class(size: "lg") =~ "h-9"
  end

  test "the class function dresses elements that cannot be a button" do
    assert tool_button_class(variant: "flat", size: "sm") =~ "hover:shadow-retro-raised"
    assert tool_button_class(variant: "dock") == "media-dock-button icon-on-dark"
    assert tool_button_class(class: "extra") =~ "extra"
  end
end
