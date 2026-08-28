defmodule RetroHexChatWeb.Components.UI.ShareMessageCardTest do
  @moduledoc """
  What a share link looks like once it lands in a conversation.

  The card draws itself from the database rather than from a scrape: the useful
  thing about a link into this app is the state of the room it names, not the
  title of a page.
  """
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.MessageRow

  @base %{
    id: 1,
    author: "ana",
    timestamp: ~U[2026-08-28 12:00:00Z],
    content: "bora jogar https://retrohexchat.app/join/abcdefghjk",
    type: :message
  }

  test "a message carrying one of our links draws a card" do
    html = render_row(Map.put(@base, :share_card, card()))

    assert html =~ "share-message-card"
    assert html =~ "Hex Pong"
    assert html =~ "ana"
    assert html =~ "/join/abcdefghjk"
  end

  test "a message with no link of ours draws none" do
    html = render_row(@base)

    refute html =~ "share-message-card"
  end

  # Stripping formatting is a reader saying they want the text and nothing else.
  test "stripped formatting means no card" do
    html = render_row(Map.put(@base, :share_card, card()), strip_formatting: true)

    refute html =~ "share-message-card"
  end

  test "a kind with no art still draws, with a name and a way in" do
    html = render_row(Map.put(@base, :share_card, %{card() | kind: "call", target: %{}}))

    assert html =~ "share-message-card"
    assert html =~ "/join/abcdefghjk"
  end

  defp card do
    %{
      slug: "abcdefghjk",
      kind: "play",
      target: %{"game_id" => "hex_pong"},
      creator_nick: "ana",
      live?: true
    }
  end

  defp render_row(msg, opts \\ []) do
    render_component(&MessageRow.message_row_body/1,
      msg: msg,
      nick_color_fn: fn _nick -> "c1" end,
      timestamp_format: :short,
      timezone: "Etc/UTC",
      strip_formatting: Keyword.get(opts, :strip_formatting, false)
    )
  end
end
