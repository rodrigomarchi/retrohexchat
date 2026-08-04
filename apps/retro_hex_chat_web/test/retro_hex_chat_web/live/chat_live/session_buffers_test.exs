defmodule RetroHexChatWeb.ChatLive.SessionBuffersTest do
  @moduledoc """
  The two ephemeral session buffers that are capped rather than paginated.

  Neither the URL catcher nor the admin console transcript lives in the
  database, so there is no older page to fetch — the correct bound is a cap.
  Before it, both grew for the lifetime of the LiveView process.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

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

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  describe "URL catcher buffer" do
    test "keeps the newest captures and drops the rest", %{conn: conn} do
      channel = "#urlcap#{uid()}"
      ensure_channel(channel)

      view = connect_user(conn, "UrlCap#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      # 250 URLs across 5 messages. Batched deliberately: flood auto-ignore trips
      # at roughly ten messages from one author and halts the handler before
      # capture, so one URL per message would measure flood protection instead
      # of the cap.
      for batch <- 0..4 do
        urls =
          Enum.map_join(1..50, " ", fn n -> "https://example.com/#{batch * 50 + n}" end)

        send(view.pid, %{
          event: "new_message",
          payload: %{
            id: batch,
            channel: channel,
            author: "Poster",
            content: "look at #{urls}",
            type: "message",
            timestamp: DateTime.utc_now()
          }
        })
      end

      render(view)
      entries = assigns(view).url_catcher_entries

      refute entries == [], "no URL was captured at all — check the payload shape"

      assert length(entries) <= 200,
             "an unbounded buffer would hold every URL the session ever saw"

      assert Enum.any?(entries, &String.ends_with?(&1.url, "/250")),
             "the cap must drop the oldest, not refuse the newest"
    end

    test "captures Markdown links by rendered URL policy", %{conn: conn} do
      channel = "#urlmd#{uid()}"
      ensure_channel(channel)

      view = connect_user(conn, "UrlMd#{uid()}")
      render_click(view, "switch_channel", %{"channel" => channel})

      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: 1,
          channel: channel,
          author: "Poster",
          content: "`https://code.example` [guide](https://docs.example/guide)",
          content_format: "markdown",
          type: "message",
          timestamp: DateTime.utc_now()
        }
      })

      render(view)
      urls = assigns(view).url_catcher_entries |> Enum.map(& &1.url)

      assert "https://docs.example/guide" in urls
      refute "https://code.example" in urls
    end
  end
end
