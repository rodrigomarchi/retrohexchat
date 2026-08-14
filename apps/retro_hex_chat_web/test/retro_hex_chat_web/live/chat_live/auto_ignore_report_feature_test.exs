defmodule RetroHexChatWeb.ChatLive.AutoIgnoreReportFeatureTest do
  @moduledoc """
  An auto-ignore has to leave a trace on the server.

  The decision is made in one reader's session and never reaches the sender, so
  a flooding bot went quiet across the server with nothing to show for it. The
  persisted entry is no substitute: it carries no flag saying it was automatic,
  and it is dropped when it expires.

  These drive the real path — messages into a real LiveView until the real
  threshold trips — because the interesting failure is the reporting call never
  being reached, which a test of the reporting function alone would not catch.
  Telemetry is emitted synchronously in the LiveView process, so this asserts on
  a message rather than on a rendered row.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.FloodProtection

  @event [:retro_hex_chat, :chat, :auto_ignore]

  setup do
    handler = "auto-ignore-test-#{System.unique_integer([:positive])}"
    test = self()

    :telemetry.attach(
      handler,
      @event,
      fn _event, measurements, metadata, _config ->
        send(test, {:auto_ignore, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)
    :ok
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp flood(view, channel, author, count) do
    for id <- 1..count do
      send(view.pid, %{
        event: "new_message",
        payload: %{
          id: id,
          channel: channel,
          author: author,
          content: "message #{id}",
          type: :message,
          timestamp: DateTime.utc_now()
        }
      })
    end

    # One synchronous round-trip after the sends: handle_info runs in order, so
    # a reply to this proves every message above was already processed.
    _ = render(view)
    :ok
  end

  test "a sender past the threshold is reported, with where and what kind", %{conn: conn} do
    nick = "Reader#{uid()}"
    channel = "#flood#{uid()}"
    sender = "Chatty#{uid()}"
    ensure_channel(channel)

    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    render_click(view, "switch_channel", %{"channel" => channel})

    over_threshold = FloodProtection.get_flood_threshold(FloodProtection.new()) + 1
    flood(view, channel, sender, over_threshold)

    assert_receive {:auto_ignore, measurements, metadata}, 2_000

    assert measurements.count == 1
    assert metadata[:sender] == sender
    assert metadata[:surface] == "channel"

    assert metadata[:kind] == "user",
           "a nickname with no bot server behind it is a person"
  end

  test "the reader's nickname is not in the report", %{conn: conn} do
    # Monitoring a bot needs to know which bot went quiet, not who stopped
    # listening. The count of events already says how many readers it reached.
    nick = "Private#{uid()}"
    channel = "#quiet#{uid()}"
    sender = "Loud#{uid()}"
    ensure_channel(channel)

    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    render_click(view, "switch_channel", %{"channel" => channel})

    flood(view, channel, sender, FloodProtection.get_flood_threshold(FloodProtection.new()) + 1)

    assert_receive {:auto_ignore, _measurements, metadata}, 2_000

    refute nick in Map.values(metadata),
           "the reader was named in #{inspect(metadata)}"
  end

  test "a sender under the threshold is not reported", %{conn: conn} do
    nick = "Calm#{uid()}"
    channel = "#calm#{uid()}"
    sender = "Polite#{uid()}"
    ensure_channel(channel)

    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    render_click(view, "switch_channel", %{"channel" => channel})

    under_threshold = FloodProtection.get_flood_threshold(FloodProtection.new()) - 1
    flood(view, channel, sender, under_threshold)

    refute_receive {:auto_ignore, _measurements, _metadata}, 300
  end

  test "one sender is reported once, not once per message", %{conn: conn} do
    # The auto-ignore is already active after the first trip; reporting again on
    # every later message would turn one incident into a flood of its own.
    nick = "Once#{uid()}"
    channel = "#once#{uid()}"
    sender = "Repeat#{uid()}"
    ensure_channel(channel)

    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    render_click(view, "switch_channel", %{"channel" => channel})

    flood(view, channel, sender, FloodProtection.get_flood_threshold(FloodProtection.new()) * 3)

    assert_receive {:auto_ignore, _measurements, _metadata}, 2_000
    refute_receive {:auto_ignore, _measurements, _metadata}, 300
  end
end
