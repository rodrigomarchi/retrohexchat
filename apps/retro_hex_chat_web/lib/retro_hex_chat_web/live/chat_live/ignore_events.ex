defmodule RetroHexChatWeb.ChatLive.IgnoreEvents do
  @moduledoc """
  Handle events for the Ignore List dialog.

  Covers: open_ignore_dialog, close_ignore_dialog, ignore_select,
  ignore_dialog_add, close_ignore_add_dialog, ignore_dialog_add_confirm,
  ignore_dialog_remove.

  Attached as `attach_hook(:ignore_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      error_message: 1,
      maybe_persist_ignore_list: 2,
      cancel_ignore_timer: 2,
      maybe_start_ignore_timer: 3,
      parse_dialog_duration: 1
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{FloodTracker, IgnoreList}

  def handle_event("open_ignore_dialog", _params, socket) do
    {:halt, assign(socket, show_ignore_dialog: true)}
  end

  def handle_event("close_ignore_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_ignore_dialog: false,
       ignore_selected: nil,
       show_ignore_add_dialog: false
     )}
  end

  def handle_event("ignore_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, ignore_selected: nick)}
  end

  def handle_event("ignore_dialog_add", _params, socket) do
    {:halt, assign(socket, show_ignore_add_dialog: true)}
  end

  def handle_event("close_ignore_add_dialog", _params, socket) do
    {:halt, assign(socket, show_ignore_add_dialog: false)}
  end

  def handle_event("ignore_dialog_add_confirm", params, socket) do
    nick = params["nickname"]
    type = String.to_existing_atom(params["type"])
    duration_str = params["duration"]

    {duration, expires_at} = parse_dialog_duration(duration_str)

    session = socket.assigns.session

    case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_ignore_add_dialog: false)
         |> cancel_ignore_timer(nick)
         |> maybe_start_ignore_timer(nick, duration)
         |> maybe_persist_ignore_list(new_session)
         |> stream_insert(:chat_messages, system_message("* #{nick} is now ignored (#{type})"))}

      {:error, reason} ->
        {:halt,
         stream_insert(socket, :chat_messages, error_message("Failed to add ignore: #{reason}"))}
    end
  end

  def handle_event("ignore_dialog_remove", _params, socket) do
    nick = socket.assigns.ignore_selected

    if nick do
      session = socket.assigns.session

      case IgnoreList.remove_entry(session.ignore_list, nick) do
        {:ok, updated_list} ->
          new_session = Session.set_ignore_list(session, updated_list)

          {:halt,
           socket
           |> assign(session: new_session, ignore_selected: nil)
           |> cancel_ignore_timer(nick)
           |> cancel_auto_ignore_with_cooldown(nick)
           |> maybe_persist_ignore_list(new_session)
           |> stream_insert(:chat_messages, system_message("* #{nick} is no longer ignored"))}

        {:error, :not_found} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ────────────────────────────────────────────────

  @cooldown_duration_ms 60_000

  @spec cancel_auto_ignore_with_cooldown(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp cancel_auto_ignore_with_cooldown(socket, nick) do
    sender_key = String.downcase(nick)
    auto_state = socket.assigns.auto_ignore_state

    case Map.get(auto_state.active, sender_key) do
      nil ->
        socket

      timer_ref ->
        Process.cancel_timer(timer_ref)

        # Remove from active, add cooldown
        new_active = Map.delete(auto_state.active, sender_key)
        cooldown_until = System.monotonic_time(:millisecond) + @cooldown_duration_ms
        new_cooldowns = Map.put(auto_state.cooldowns, sender_key, cooldown_until)

        new_auto_state = %{active: new_active, cooldowns: new_cooldowns}

        # Reset flood tracker for sender
        new_tracker =
          FloodTracker.reset_sender(socket.assigns.flood_tracker, nick)

        assign(socket,
          auto_ignore_state: new_auto_state,
          flood_tracker: new_tracker
        )
    end
  end
end
