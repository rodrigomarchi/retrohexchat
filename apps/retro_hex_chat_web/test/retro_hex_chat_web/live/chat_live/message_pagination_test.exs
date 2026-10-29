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

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Chat.{Queries, Service}
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/")
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

  # How many rows the message viewport is holding — its own mirror of the
  # browser's list, read out of the component's assigns.
  defp viewport_rows(view), do: view |> viewport_rendered() |> length()

  defp viewport_rendered(view) do
    {components, _ids, _uuid} = view.pid |> :sys.get_state() |> Map.fetch!(:components)

    Enum.find_value(components, fn
      {_cid, {MessageViewport, _id, assigns, _private, _prints}} -> assigns.rendered
      _other -> nil
    end)
  end

  # The oldest row the viewport is holding — the one a capped prepend would eat.
  defp viewport_oldest(view) do
    view |> viewport_rendered() |> List.first() |> Map.fetch!(:id)
  end

  defp pagination(view) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
    |> Map.take([:has_more, :oldest_message_id, :loaded_message_count])
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
  # sees.
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

  # The DOM cap applies to one end of the list only. LiveView prunes a negative
  # limit from the front, which is where a prepended page lands, so a cap on
  # both ends deletes every page from the third back with the very patch that
  # inserts it — and the cursor has already moved past it, so it cannot be asked
  # for again. Measured in the browser: 700 messages fetched and dropped while
  # the reader stays on the same 150 rows (`e2e/tests/chat-scrollback-audit.spec.ts`).
  #
  # The viewport's `rendered` is its mirror of what the browser holds, so it is
  # where that rule can be asserted without a browser: the test client applies
  # no stream limit at all, which is exactly why the markup assertion above
  # passes either way.
  describe "paging back past the DOM cap" do
    test "keeps every page the reader loaded", %{conn: conn} do
      channel = "#pagcap#{uid()}"
      ensure_channel(channel)
      seed(channel, 260, "Seeder")

      view = connect_user(conn, "PagX#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})
      for _ <- 1..4, do: render_click(view, "load_more", %{})

      assert viewport_rows(view) == 250,
             "five pages of 50 were loaded; the reader must still have all of them"
    end

    test "an arriving message does not push the oldest loaded row out", %{conn: conn} do
      channel = "#pagtail#{uid()}"
      ensure_channel(channel)
      seed(channel, 260, "Seeder")

      view = connect_user(conn, "PagT#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})
      for _ <- 1..4, do: render_click(view, "load_more", %{})

      before_rows = viewport_rows(view)
      before_oldest = viewport_oldest(view)
      submit_command_sync(view, "still here")

      assert viewport_oldest(view) == before_oldest,
             "the live message is added to the scrollback, not traded for its oldest row"

      assert viewport_rows(view) > before_rows
    end

    test "switching channel gives the cap back", %{conn: conn} do
      channel = "#pagswap#{uid()}"
      other = "#pagswapb#{uid()}"
      ensure_channel(channel)
      ensure_channel(other)
      seed(channel, 260, "Seeder")
      seed(other, 10, "Seeder")

      view = connect_user(conn, "PagW#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})
      for _ <- 1..4, do: render_click(view, "load_more", %{})
      render_click(view, "switch_channel", %{"channel" => other})

      assert viewport_rows(view) <= 50,
             "the scrollback belonged to the channel the reader left"
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

  # The continuous-paper layout: runs of one speaker share a header and a band.
  # The band of a line is decided when it reaches the screen; an older page
  # loading above must never repaint a line the reader is looking at.
  describe "speaker runs and their bands" do
    defp seed_runs(channel, count) do
      for i <- 1..count do
        {:ok, msg} =
          Queries.insert_message(%{
            channel_name: channel,
            author_nickname: if(rem(div(i - 1, 3), 2) == 0, do: "Ana", else: "Bob"),
            content: "run line #{i}",
            type: "message"
          })

        msg
      end
    end

    defp bands(rows), do: Map.new(rows, &{&1.id, &1.band})

    defp assert_alternates(rows) do
      rows
      |> Enum.filter(& &1.band)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [up, down] ->
        if down.group_start?,
          do: assert(up.band != down.band, "neighbouring runs share a band"),
          else: assert(up.band == down.band, "a run changes band halfway")
      end)
    end

    test "the first page is grouped, and the top line opens a run and says its day",
         %{conn: conn} do
      channel = "#runs#{uid()}"
      ensure_channel(channel)
      seed_runs(channel, 12)

      view = connect_user(conn, "Runs#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      rows = viewport_rendered(view)
      [top | _] = rows

      assert top.group_start?
      assert %Date{} = top.day_break
      assert Enum.count(rows, & &1.group_start?) == 4
      assert_alternates(rows)
    end

    test "loading an older page keeps every band already on screen", %{conn: conn} do
      channel = "#runsold#{uid()}"
      ensure_channel(channel)
      # 61 lines: the page boundary falls inside a run, so the old top line
      # loses its header to the page above it.
      seed_runs(channel, 61)

      view = connect_user(conn, "RunsO#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})
      before = viewport_rendered(view)

      render_click(view, "load_more", %{})
      rows = viewport_rendered(view)

      assert Map.take(bands(rows), Map.keys(bands(before))) == bands(before)
      assert_alternates(rows)
      assert hd(rows).group_start?

      old_top = Enum.find(rows, &(&1.id == hd(before).id))
      refute old_top.group_start?, "the old top line now continues the run above it"
      assert old_top.day_break == nil
    end

    test "deleting the line that opened a run gives the next line the header back",
         %{conn: conn} do
      channel = "#runsdel#{uid()}"
      ensure_channel(channel)
      [opener, _second, _third] = seed_runs(channel, 3)

      view = connect_user(conn, "RunsD#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})
      {:ok, _} = Service.delete_message(opener.id, "Ana")
      _ = render(view)

      [deleted, second | _] = viewport_rendered(view)

      assert deleted.deleted_at
      assert deleted.band == nil
      assert second.group_start?, "the run lost the line that named its speaker"
    end

    test "a line arriving from the same speaker continues the run at the bottom",
         %{conn: conn} do
      channel = "#runslive#{uid()}"
      nick = "RunsL#{uid()}"
      ensure_channel(channel)
      seed_runs(channel, 3)
      # Joined before the reader arrives: a join announced on screen is narration
      # and would rightly break the run.
      {:ok, _} = Server.join(channel, "Ana")

      view = connect_user(conn, nick)
      render_click(view, "switch_channel", %{"channel" => channel})
      {:ok, _} = Server.send_message(channel, "Ana", "one more")
      _ = render(view)

      last = view |> viewport_rendered() |> List.last()

      assert last.content == "one more"
      refute last.group_start?
      assert last.band == hd(viewport_rendered(view)).band
    end
  end
end
