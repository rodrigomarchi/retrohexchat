defmodule RetroHexChatWeb.Components.UI.NickFlagTest do
  @moduledoc """
  The flag of the language somebody uses the chat in, and the case that
  matters as much: no flag. A locale the chat has no flag for draws nothing,
  never the language menu's globe — a globe beside one nickname would read as
  a fact about that person.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.NickFlag

  @moduletag :unit

  test "draws the language menu's flag, named in its own language" do
    html = render_component(&nick_flag/1, locale: "pt_BR")

    assert html =~ "rh-nick-flag"
    assert html =~ ~s(data-locale="pt_BR")
    assert html =~ "#icon_flag_pt_br"
    assert html =~ ~s|title="Português (Brasil)"|
    assert html =~ ~s|aria-label="Português (Brasil)"|
  end

  test "draws nothing without a locale" do
    refute render_component(&nick_flag/1, locale: nil) =~ "rh-nick-flag"
  end

  test "draws nothing for a locale the chat has no flag for" do
    html = render_component(&nick_flag/1, locale: "ko")

    refute html =~ "rh-nick-flag"
    refute html =~ "icon_globe"
  end

  test "names every flag it can draw" do
    assert language("ja") == "日本語"
    assert language("xx") == nil
    assert language(nil) == nil
  end

  test "hands a browser-drawn nickname the same flag, or nothing" do
    assert %{locale: "ja", language: "日本語", href: href} = payload("ja")
    assert String.ends_with?(href, "#icon_flag_ja")
    assert payload("ko") == nil
    assert payload(nil) == nil
  end
end
