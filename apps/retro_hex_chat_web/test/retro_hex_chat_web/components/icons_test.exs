defmodule RetroHexChatWeb.IconsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Phoenix.HTML.Safe
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Icons.Registry
  alias RetroHexChatWeb.Icons.Sprite

  @moduletag :unit

  describe "an icon component" do
    test "points a <use> at the sprite instead of drawing the art inline" do
      html = render_component(&Icons.icon_folder/1, class: "w-4 h-4")

      assert html =~ ~s(<use href="#{Sprite.href(:icon_folder)}")
      refute html =~ "<path"
      refute html =~ "<rect"
    end

    test "keeps the class it was given and stays out of the accessibility tree" do
      html = render_component(&Icons.icon_folder/1, class: "h-6 w-6 shrink-0")

      assert html =~ ~s(class="h-6 w-6 shrink-0")
      assert html =~ ~s(aria-hidden="true")
    end

    test "renders without a class" do
      html = render_component(&Icons.icon_folder/1, [])

      assert html =~ "<use href="
    end

    test "renders when applied as a plain function, not through a template" do
      # The mobile menu drawer picks its category icon by name at runtime:
      # `apply(Icons, section.icon_fn, [%{class: "h-4 w-4"}])`. That map carries
      # no `__changed__`, so an icon must not require component assigns.
      html =
        Icons
        |> apply(:icon_folder, [%{class: "h-[14px] w-[14px]"}])
        |> Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert html =~ "<use href="
      assert html =~ ~s(class="h-[14px] w-[14px]")
    end

    test "every registered icon renders a <use> and no art" do
      offenders =
        for {name, _module} <- Registry.all(),
            html = render_component(Function.capture(Icons, name, 1), class: "w-4"),
            not (html =~ "<use href=") or html =~ "<path" or html =~ "<rect",
            do: name

      assert offenders == [], "still drawing art inline: #{inspect(offenders)}"
    end
  end

  describe "flag_icon/1" do
    test "resolves a known locale to that locale's flag" do
      html = render_component(&Icons.flag_icon/1, locale: "pt_BR", class: "h-4")

      assert html =~ Sprite.href(Registry.flag("pt_BR"))
      assert html =~ ~s(class="h-4")
    end

    test "falls back for an unknown locale" do
      html = render_component(&Icons.flag_icon/1, locale: "kl_GL", class: "h-4")

      assert html =~ Sprite.href(Registry.flag("kl_GL"))
    end
  end

  describe "game_icon/1" do
    test "resolves a known game to its box art" do
      html = render_component(&Icons.game_icon/1, game_id: "hex_pong", class: "h-6")

      assert html =~ Sprite.href(Registry.game("hex_pong"))
    end

    test "falls back for an unknown game" do
      html = render_component(&Icons.game_icon/1, game_id: "no_such_game", class: "h-6")

      assert html =~ Sprite.href(Registry.game("no_such_game"))
    end
  end

  describe "Sprite.href/1" do
    test "is the digested sprite path plus the icon's fragment" do
      href = Sprite.href(:icon_folder)

      assert href =~ "/assets/icons/sprite"
      assert String.ends_with?(href, "#icon_folder")
    end
  end
end
