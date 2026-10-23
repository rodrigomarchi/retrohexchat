defmodule RetroHexChatWeb.Components.UI.InsetTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Inset

  @moduletag :unit

  test "the default is the white field panel" do
    assigns = %{}
    html = rendered_to_string(~H|<.inset class="p-2">notes</.inset>|)

    assert html =~ ~s(<div class="shadow-retro-field bg-white p-2">)
  end

  # The deeper bevel a status box or a group of controls sits in, on the
  # window's grey, as the section of the page it is.
  test "the sunken bevel, on the window's grey, as a section" do
    assigns = %{}

    html =
      rendered_to_string(~H|<.inset bevel="sunken" tone="surface" as="section" id="s">x</.inset>|)

    assert html =~ ~s(<section id="s" class="shadow-retro-sunken bg-surface">)
  end

  test "tone none keeps whatever is behind it" do
    assigns = %{}
    html = rendered_to_string(~H|<.inset bevel="sunken" tone="none">x</.inset>|)

    assert html =~ ~s(class="shadow-retro-sunken")
    refute html =~ "bg-"
  end
end
