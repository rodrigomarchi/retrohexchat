defmodule RetroHexChatWeb.Components.UI.MessageReactionsTest do
  @moduledoc """
  The strip of reactions under a line, and the quick picks that put one there.

  The strip exists only when there is something in it: a message nobody
  reacted to must take no vertical space at all, or every line in the history
  grows a blank row.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MessageReactions

  @moduletag :unit

  alias RetroHexChat.Chat.EmojiData
  alias RetroHexChatWeb.Components.UI.MessageReactions

  @thumbs "\u{1F44D}"
  @heart "\u{2764}\u{FE0F}"

  defp render_strip(opts) do
    render_component(
      &message_reactions/1,
      Keyword.merge(
        [message_id: 42, viewer: "Ana", on_toggle: "toggle_reaction", reactions: %{}],
        opts
      )
    )
  end

  test "draws one chip per emoji, with its count" do
    html =
      render_strip(
        reactions: %{
          @thumbs => %{count: 2, actors: ["Ana", "Bo"]},
          @heart => %{count: 1, actors: ["Bo"]}
        }
      )

    assert html =~ ~s(data-testid="message-reaction-42-#{@thumbs}")
    assert html =~ ~s(data-testid="message-reaction-42-#{@heart}")
    assert html |> chip(@thumbs) |> Floki.text() =~ "2"
    assert html |> chip(@heart) |> Floki.text() =~ "1"
  end

  # A line nobody reacted to must not grow a blank row: fifty of those is the
  # whole history pushed off the screen.
  test "draws nothing at all when there are no reactions" do
    html = render_strip(reactions: %{})

    refute html =~ ~s(data-testid="message-reactions-42")
  end

  test "draws nothing when the row carries no reactions field" do
    html = render_strip(reactions: nil)

    refute html =~ ~s(data-testid="message-reactions-42")
  end

  # Whether a chip is yours is decided here, from the actor list, so one stored
  # summary serves every reader instead of one summary per person.
  test "marks the chips the viewer is in" do
    html =
      render_strip(
        viewer: "Ana",
        reactions: %{
          @thumbs => %{count: 1, actors: ["Ana"]},
          @heart => %{count: 1, actors: ["Bo"]}
        }
      )

    mine = chip(html, @thumbs)
    theirs = chip(html, @heart)

    assert mine |> Floki.attribute("aria-pressed") == ["true"]
    assert theirs |> Floki.attribute("aria-pressed") == ["false"]
  end

  test "matches the viewer whatever case the actor was stored in" do
    html = render_strip(viewer: "ana", reactions: %{@thumbs => %{count: 1, actors: ["Ana"]}})

    assert chip(html, @thumbs) |> Floki.attribute("aria-pressed") == ["true"]
  end

  test "names who reacted, so a count can be read" do
    html = render_strip(reactions: %{@thumbs => %{count: 2, actors: ["Ana", "Bo"]}})

    assert [title] = chip(html, @thumbs) |> Floki.attribute("title")
    assert title =~ "Ana"
    assert title =~ "Bo"
  end

  describe "the quick picks" do
    test "offer a handful of emoji, each carrying the message it is for" do
      html =
        render_component(&message_reaction_bar/1,
          message_id: 42,
          on_toggle: "toggle_reaction"
        )

      chips = html |> Floki.parse_fragment!() |> Floki.find("button")

      assert chips != []
      assert Enum.all?(chips, &(Floki.attribute(&1, "phx-value-message_id") == ["42"]))
    end

    # The bar filters itself against the catalog, so a pick that is not in it
    # simply vanishes — silently, and only in production. The count is what
    # turns that into a failing test.
    test "offers every pick it declares" do
      assert length(MessageReactions.quick_picks()) == 5
    end

    test "every quick pick is an emoji the catalog knows" do
      html =
        render_component(&message_reaction_bar/1,
          message_id: 42,
          on_toggle: "toggle_reaction"
        )

      emoji =
        html
        |> Floki.parse_fragment!()
        |> Floki.find("button")
        |> Enum.flat_map(&Floki.attribute(&1, "phx-value-emoji"))

      assert emoji != []
      assert Enum.all?(emoji, &EmojiData.known?/1)
    end
  end

  defp chip(html, emoji) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(~s([data-testid="message-reaction-42-#{emoji}"]))
  end
end
