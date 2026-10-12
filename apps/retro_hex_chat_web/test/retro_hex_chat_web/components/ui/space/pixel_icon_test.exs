defmodule RetroHexChatWeb.Components.UI.Space.PixelIconTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.Space.PixelIcon

  @moduletag :unit

  @kit_css Path.expand(
             "../../../../../assets/css/retrohex/features/space-ui-kit.generated.css",
             __DIR__
           )

  test "every icon has a rule in the kit's generated CSS" do
    css = File.read!(@kit_css)

    for name <- PixelIcon.names() do
      html = render_component(&PixelIcon.pixel_icon/1, name: name)
      [_, class] = Regex.run(~r/(space-icon--[\w-]+)/, html)
      assert css =~ ".#{class} {", "#{name}: no .#{class} in the generated kit CSS"
    end
  end

  test "is decorative: the control it sits in carries the name" do
    html = render_component(&PixelIcon.pixel_icon/1, name: :ok)

    assert html =~ ~s(aria-hidden="true")
    assert html =~ ~s(class="space-icon space-icon--ok")
  end
end
