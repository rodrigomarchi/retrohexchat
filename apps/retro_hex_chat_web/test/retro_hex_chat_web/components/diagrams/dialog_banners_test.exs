defmodule RetroHexChatWeb.Components.Diagrams.DialogBannersTest do
  @moduledoc """
  A banner illustration is only worth its space if it changes with the thing
  it pictures. These assert the part that can silently stop being true: the
  account card must draw a different lock per state, and the channel preview
  must carry the topic and welcome the form currently holds rather than a
  fixed picture of a channel.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.Diagrams.DialogAccount
  import RetroHexChatWeb.Components.Diagrams.DialogChannel

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
end
