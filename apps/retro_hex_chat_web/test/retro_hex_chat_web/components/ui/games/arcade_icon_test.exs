defmodule RetroHexChatWeb.Components.UI.Games.ArcadeIconTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.Games.ArcadeIcon

  @moduletag :unit

  @kit_css Path.expand(
             "../../../../../assets/css/retrohex/features/arcade-ui-kit.generated.css",
             __DIR__
           )

  test "every icon has a rule in the arcade kit's generated CSS" do
    css = File.read!(@kit_css)

    for name <- ArcadeIcon.names() do
      html = render_component(&ArcadeIcon.arcade_icon/1, name: name)
      [_, class] = Regex.run(~r/(arcade-icon--[\w-]+)/, html)
      assert css =~ ".#{class} {", "#{name}: no .#{class} in the generated kit CSS"
    end
  end
end
