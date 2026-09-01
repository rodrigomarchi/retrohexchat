defmodule RetroHexChatWeb.Components.UI.ShareMessageCardTest do
  @moduledoc """
  What a share link looks like once it lands in a conversation.

  The card draws itself from the database rather than from a scrape: the useful
  thing about a link into this app is the state of the room it names, not the
  title of a page. Two states, and the ended one is the half that was missing —
  a link that stopped working used to make the card disappear, leaving a bare
  address under a message that had explained itself the day before.
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

  describe "a live card" do
    test "a message carrying one of our links draws a card" do
      html = render_row(Map.put(@base, :share_card, card()))

      assert html =~ "share-message-card"
      assert html =~ ~s(data-share-state="live")
      assert html =~ "Hex Pong"
      assert html =~ "/join/abcdefghjk"
    end

    test "a message with no link of ours draws none" do
      refute render_row(@base) =~ "share-message-card"
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

    test "the way in comes with the way to pass it on" do
      html = render_row(Map.put(@base, :share_card, card()))

      assert html =~ ~s(data-testid="share-message-enter")
      assert html =~ ~s(data-testid="share-message-copy")
      assert html =~ ~s(phx-hook="CopyValueHook")
      assert html =~ ~s(data-copy-text=)
    end

    test "a conference names the channel and counts who is inside" do
      html =
        render_row(
          Map.put(@base, :share_card, %{
            card()
            | kind: "call",
              channel_name: "#retro",
              participants: ["ana", "bob"],
              count: 2
          })
        )

      assert html =~ "Call in #retro"
      assert html =~ "ana, bob"
      assert html =~ "2 people inside now"
      assert html =~ ~s(data-share-count="2")
    end

    # The one number the card is for: it comes from the summary it was handed,
    # so a screen that redraws with a new summary redraws with a new number.
    test "the count is whatever the summary said, not a stored figure" do
      inside = fn count ->
        render_row(
          Map.put(@base, :share_card, %{card() | kind: "call", count: count, participants: []})
        )
      end

      assert inside.(1) =~ "1 person inside now"
      assert inside.(7) =~ "7 people inside now"
    end
  end

  # What a card is for once the room is gone: not a blank space and not a bare
  # "Over", but the record of what happened. The numbers are derived on read in
  # `ShareLinks.Card`, so what is asserted here is only that the component says
  # them — and says nothing when the kind has none.
  describe "the record an ended card keeps" do
    test "a conference says how long it ran and how many were in it" do
      html =
        render_row(
          Map.put(
            @base,
            :share_card,
            ended(
              kind: "call",
              channel_name: "#retro",
              metrics: %{duration_seconds: 1_500, visitors: 5}
            )
          )
        )

      assert html =~ "25 minutes"
      assert html =~ "5 people took part"
      assert html =~ ~s(data-share-duration="1500")
      assert html =~ ~s(data-share-visitors="5")
    end

    test "one person is one person" do
      html =
        render_row(
          Map.put(
            @base,
            :share_card,
            ended(kind: "call", metrics: %{duration_seconds: 90, visitors: 1})
          )
        )

      assert html =~ "1 minute"
      assert html =~ "1 person took part"
    end

    # A conference that ran for forty seconds lasted less than a minute. The
    # exact number is a fact about the clock, not about the meeting.
    test "a short one is not reported to the second" do
      html =
        render_row(
          Map.put(
            @base,
            :share_card,
            ended(kind: "call", metrics: %{duration_seconds: 42, visitors: 2})
          )
        )

      assert html =~ "less than a minute"
      # The raw number is still on the element for anything that wants to do
      # arithmetic; what must not happen is a card reading "42 seconds".
      assert html =~ ~s(data-share-duration="42")
      refute html =~ "42 second"
    end

    test "a long one is reported in hours" do
      html =
        render_row(
          Map.put(
            @base,
            :share_card,
            ended(kind: "call", metrics: %{duration_seconds: 7_500, visitors: 3})
          )
        )

      assert html =~ "2 hours"
    end

    # Two people by definition, so the only number worth saying is the time.
    test "a session says the time and does not count to two" do
      html =
        render_row(
          Map.put(
            @base,
            :share_card,
            ended(kind: "p2p", metrics: %{duration_seconds: 600, visitors: nil})
          )
        )

      assert html =~ "lasted 10 minutes"
      refute html =~ "took part"
      refute html =~ ~s(data-share-visitors=")
    end

    # A place has no beginning to measure from. Falling back to who shared it is
    # the honest sentence, not a duration invented from a catalogue entry.
    test "a kind with no session falls back to who shared it" do
      html = render_row(Map.put(@base, :share_card, ended(kind: "space")))

      assert html =~ "shared by ana"
      refute html =~ "lasted"
    end
  end

  describe "an ended card" do
    test "loses the way in and keeps a way forward" do
      html = render_row(Map.put(@base, :share_card, ended(kind: "call", channel_name: "#retro")))

      assert html =~ ~s(data-share-state="ended")
      refute html =~ ~s(data-testid="share-message-enter")
      refute html =~ ~s(data-testid="share-message-copy")
      assert html =~ ~s(data-testid="share-message-next")
      assert html =~ "Open #retro"
      assert html =~ "/chat?join="
    end

    test "a match somebody already took says so, and offers the game" do
      html =
        render_row(
          Map.put(@base, :share_card, ended(reason: :full, target: %{"game_id" => "hex_pong"}))
        )

      assert html =~ "Taken"
      assert html =~ "Play Hex Pong"
      assert html =~ "/play/hex_pong"
    end

    test "a revoked link is a card that says so, not a card that vanished" do
      html = render_row(Map.put(@base, :share_card, ended(reason: :revoked)))

      assert html =~ "share-message-card"
      assert html =~ "Closed"
    end

    test "an expired one says that instead" do
      assert render_row(Map.put(@base, :share_card, ended(reason: :expired))) =~ "Expired"
    end
  end

  # The card sits in a conversation whose readers may not be in that channel.
  # The domain decides; what is asserted here is that the component has no
  # second opinion — a card with no name shows none, anywhere it might have.
  describe "a channel the reader may not be told about" do
    test "is never named, in either state, even though the card is carrying it" do
      # `target` holds the channel because the room is in it; `channel_name` is
      # the domain's answer to "may this reader be told". A component that read
      # the first would be a second copy of the rule, and this is where that
      # would show.
      for state <- [:live, :ended] do
        html =
          render_row(
            Map.put(@base, :share_card, %{
              card()
              | kind: "call",
                state: state,
                target: %{"room_token" => "tok", "channel_name" => "#secret"},
                channel_name: nil,
                count: 3
            })
          )

        assert html =~ "share-message-card"
        refute html =~ "#secret"
        assert html =~ "A conference"
      end
    end
  end

  # The door a conference writes is a system line, and a system line takes its
  # own branch of the row. The card was attached to it and never drawn: every
  # test here built a `:message` row, so the one shape that actually carries a
  # card in production was the one shape nothing rendered.
  describe "the row a session's door actually arrives on" do
    test "a system message carrying one of our links draws the card" do
      html =
        render_row(
          @base
          |> Map.put(:type, :system)
          |> Map.put(:author, "System")
          |> Map.put(:share_card, %{card() | kind: "call", channel_name: "#retro", count: 2})
        )

      assert html =~ "share-message-card"
      assert html =~ ~s(data-share-state="live")
      assert html =~ "Call in #retro"
      assert html =~ ~s(data-testid="share-message-enter")
    end

    test "an ended one keeps the record on the same row" do
      html =
        render_row(
          @base
          |> Map.put(:type, :system)
          |> Map.put(:share_card, ended(reason: :over, kind: "call"))
        )

      assert html =~ ~s(data-share-state="ended")
      assert html =~ ~s(data-testid="share-message-next")
    end

    test "a system message with no link of ours draws none" do
      refute render_row(Map.put(@base, :type, :system)) =~ "share-message-card"
    end
  end

  defp card do
    %{
      slug: "abcdefghjk",
      kind: "play",
      target: %{"game_id" => "hex_pong"},
      creator_nick: "ana",
      state: :live,
      reason: nil,
      count: nil,
      participants: [],
      channel_name: nil,
      game_id: "hex_pong",
      metrics: nil
    }
  end

  defp ended(overrides) do
    card()
    |> Map.merge(%{state: :ended, reason: Keyword.get(overrides, :reason, :over)})
    |> Map.merge(Map.new(Keyword.delete(overrides, :reason)))
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
