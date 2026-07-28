defmodule RetroHexChatWeb.ChatLive.MessagePaginationTest do
  @moduledoc """
  Pagination state of the chat viewport, asserted on the LiveView's own assigns.

  The regression under guard: `has_more` used to be derived from the message
  list *after* the ignore-list and cleared-channel filters ran, so one hidden
  message on the first page ended infinite scroll for that channel — for good,
  because `load_more` refuses to run once `has_more` is false.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.Queries

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp seed(channel, count, author) do
    for i <- 1..count do
      {:ok, msg} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: author,
          content: "seeded #{i}",
          type: "message"
        })

      msg
    end
  end

  defp seed_padded(channel, count, author) do
    for i <- 1..count do
      {:ok, _msg} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: author,
          content: "padded-#{String.pad_leading(to_string(i), 3, "0")}",
          type: "message"
        })
    end
  end

  defp pagination(view) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
    |> Map.take([:has_more, :oldest_message_id, :loading_more, :loaded_message_count])
  end

  describe "first page" do
    test "a channel with more than one page reports more to fetch", %{conn: conn} do
      channel = "#pag#{uid()}"
      ensure_channel(channel)
      seed(channel, 60, "Seeder")

      view = connect_user(conn, "Pag#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      state = pagination(view)
      assert state.has_more
      assert state.oldest_message_id
    end

    test "a channel that fits in one page reports nothing more", %{conn: conn} do
      channel = "#pagsmall#{uid()}"
      ensure_channel(channel)
      seed(channel, 5, "Seeder")

      view = connect_user(conn, "PagS#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      refute pagination(view).has_more
    end
  end

  describe "the regression: filtered rows must not end pagination" do
    test "ignoring the author of every message on page one still leaves more to fetch",
         %{conn: conn} do
      channel = "#pagign#{uid()}"
      ensure_channel(channel)
      seed(channel, 60, "Chatty")

      view = connect_user(conn, "PagI#{uid()}")
      render_click(view, "ignore_add", %{"nickname" => "Chatty", "type" => "all"})
      render_click(view, "switch_channel", %{"channel" => channel})

      state = pagination(view)

      assert state.has_more,
             "an ignored author hid the rows, but the database still has older pages"

      assert state.oldest_message_id,
             "without a cursor load_more refuses to run, which is the same dead end"
    end
  end

  describe "load_more" do
    test "advances the cursor and keeps paginating", %{conn: conn} do
      channel = "#pagmore#{uid()}"
      ensure_channel(channel)
      seed(channel, 130, "Seeder")

      view = connect_user(conn, "PagM#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      first = pagination(view)
      assert first.has_more

      render_click(view, "load_more", %{})
      second = pagination(view)

      assert second.oldest_message_id < first.oldest_message_id
      assert second.has_more
      assert second.loaded_message_count > first.loaded_message_count

      render_click(view, "load_more", %{})
      third = pagination(view)

      refute third.has_more, "130 messages is under three pages, so the third must be the last"

      assert third.oldest_message_id == nil,
             "a last page carries no cursor — there is nothing left to ask for"
    end

    test "is a no-op once the history is exhausted", %{conn: conn} do
      channel = "#pagend#{uid()}"
      ensure_channel(channel)
      seed(channel, 5, "Seeder")

      view = connect_user(conn, "PagE#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      before = pagination(view)
      render_click(view, "load_more", %{})

      assert pagination(view) == before
    end
  end

  # The assigns above say a page was fetched; this says it reached the markup.
  # The two are not the same claim, and only the second one is what a reader
  # sees — the browser drops these rows again (see the plan's PROGRESS), so the
  # server side needs a guard of its own to keep that diagnosis honest.
  describe "the fetched page reaches the rendered stream" do
    test "older messages are in the markup after load_more", %{conn: conn} do
      channel = "#pagrender#{uid()}"
      ensure_channel(channel)
      # Zero-padded so "row 1" is not a prefix of "row 10" — an unpadded
      # substring assertion here passes on the wrong row.
      seed_padded(channel, 60, "Seeder")

      view = connect_user(conn, "PagR#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      refute render(view) =~ "padded-001", "the oldest message is not on the first page"

      render_click(view, "load_more", %{})
      html = render(view)

      assert html =~ "padded-001", "the older page must render, not just update the assigns"
      assert html =~ "padded-060", "and the newest page must survive the prepend"
    end
  end

  # There is deliberately no end-of-scrollback ornament in the chat. The only
  # place it could sit and tell the truth is inside the scrolling element, at
  # the top of the content — and putting it there changes the container's height
  # in the same patch that prepends a page, which defeats the scroll
  # compensation and throws the reader out of the history they just loaded.
  # Outside the scrolling element it becomes a fixed banner claiming "beginning
  # of history" wherever the reader is, which is worse than no marker at all.
  describe "the top of the scrollback" do
    test "carries no marker, rather than one that is always on screen", %{conn: conn} do
      channel = "#pagmark#{uid()}"
      ensure_channel(channel)
      seed(channel, 5, "Seeder")

      view = connect_user(conn, "PagK#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      refute has_element?(view, ~s([data-testid="chat-history-end"]))
    end
  end

  describe "a presentation change does not re-read the history" do
    test "setting a nick colour restyles the loaded rows without paging again", %{conn: conn} do
      channel = "#pagcolor#{uid()}"
      ensure_channel(channel)
      seed(channel, 130, "Colourful")

      view = connect_user(conn, "PagC#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})
      render_click(view, "load_more", %{})

      before = pagination(view)
      assert before.loaded_message_count > 50

      render_click(view, "nicklist_context_action", %{
        "action" => "context_set_color",
        "nick" => "Colourful",
        "color" => "4"
      })

      # The rows are restyled from what the viewport already holds, so the
      # pagination state is untouched — a refetch would have reset it.
      assert pagination(view) == before
    end
  end
end
