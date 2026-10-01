defmodule RetroHexChatWeb.Components.Diagrams.DialogBannersTest do
  @moduledoc """
  A banner illustration is only worth its space if it changes with the thing
  it pictures. These assert the part that can silently stop being true: the
  account card must draw a different lock per state, the channel preview must
  carry the topic and welcome the form currently holds rather than a fixed
  picture of a channel, and the bot roster's lamps must take their colour from
  the bot's state rather than from their position in the list.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.Diagrams.DialogAccount
  import RetroHexChatWeb.Components.Diagrams.DialogChannel
  import RetroHexChatWeb.Components.Diagrams.DialogPreview

  @moduletag :unit

  defp card(state, nickname \\ "Troll") do
    render_component(&diagram_account_card/1, %{state: state, nickname: nickname})
  end

  defp preview(attrs) do
    render_component(
      &diagram_channel_preview/1,
      Map.merge(%{channel_name: "#lobby", topic: "", welcome: ""}, attrs)
    )
  end

  describe "account card" do
    test "an identified session gets the open shackle and a key" do
      html = card(:identified)

      assert html =~ "the padlock open and the key turned"
      assert html =~ "#808000", "the key is drawn in the key colour"
      assert html =~ "verified"
    end

    test "a registered nickname this session has not proved gets a shut padlock" do
      html = card(:registered)

      assert html =~ "the padlock still closed"
      refute html =~ "#808000", "no key is offered until the session identifies"
      assert html =~ "not verified"
    end

    test "a guest gets a blank card and no key at all" do
      html = card(:guest, "")

      assert html =~ "no key beside it"
      assert html =~ "unclaimed"
      refute html =~ "#808000"
    end

    test "a long nickname is clipped rather than run off the card" do
      html = card(:identified, "AVeryLongNickname")

      refute html =~ "AVeryLongNickname"
      assert html =~ "AVeryLon…"
    end
  end

  describe "channel preview" do
    test "carries the topic and the welcome the form currently holds" do
      html = preview(%{topic: "Ban policy", welcome: "Read the rules"})

      assert html =~ "Ban policy"
      assert html =~ "Read the rules"
    end

    test "wraps a welcome message across lines instead of overflowing" do
      html = preview(%{welcome: String.duplicate("word ", 12)})

      assert html =~ ~s(y="53")
      assert html =~ ~s(y="62")
    end

    test "draws empty placeholder bars when nothing greets a joiner" do
      html = preview(%{})

      refute html =~ ~s(fill="#000080" font-size="7")
      assert html =~ ~s(fill="#e0e0e0")
    end
  end

  describe "roster lamps" do
    defp roster(lines) do
      render_component(&diagram_dialog_preview/1, %{
        kind: :roster,
        title: "Bots",
        lines: lines
      })
    end

    test "a bot that is up and one that is not get different lamps" do
      html = roster([%{text: "Helper", tone: :ok}, %{text: "Bracket", tone: :muted}])

      assert html =~ "#00a000", "a running bot's lamp is the roster's running green"
      assert html =~ "#a0a0a0", "a disabled bot's lamp is the roster's grey"
      assert html =~ "Helper"
      assert html =~ "Bracket"
    end

    test "enabled but not running is its own colour, not one of the other two" do
      html = roster([%{text: "Stalled", tone: :warn}])

      assert html =~ "#e0b000"
      refute html =~ "#00a000"
      refute html =~ "#a0a0a0"
    end

    test "a server with no bots draws the empty rows rather than a lamp" do
      html = roster([])

      refute html =~ "<circle"
      assert html =~ ~s(fill="#e0e0e0")
    end
  end

  describe "capability checklist" do
    defp checklist(lines) do
      render_component(&diagram_dialog_preview/1, %{
        kind: :checklist,
        title: "Capabilities",
        lines: lines
      })
    end

    test "nothing chosen draws a box per row and no tick" do
      html = checklist([%{text: "Dice", tone: :normal}, %{text: "Help", tone: :normal}])

      assert html =~ ~s(stroke="#404040")
      refute html =~ ~s(width="2" height="4")
      assert html =~ "Dice"
    end

    test "a chosen capability gets the tick its checkbox would carry" do
      html = checklist([%{text: "Dice", tone: :accent}])

      assert html =~ ~s(width="2" height="4")
    end
  end
end
