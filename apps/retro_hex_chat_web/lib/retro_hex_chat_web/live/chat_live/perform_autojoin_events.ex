defmodule RetroHexChatWeb.ChatLive.PerformAutojoinEvents do
  @moduledoc """
  Handle events for Perform (auto-execute commands) and AutoJoin dialogs.

  Covers: open/close_perform_dialog, perform_dialog_tab, perform_select,
  perform_dialog_add/edit/remove/move_up/move_down/toggle_enabled,
  autojoin_select, autojoin_dialog_add/edit/remove.

  Attached as `attach_hook(:perform_autojoin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [error_message: 1, maybe_persist_perform_list: 2, maybe_persist_autojoin_list: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{AutoJoinList, PerformList}

  def handle_event("open_perform_dialog", _params, socket) do
    {:halt, assign(socket, show_perform_dialog: true)}
  end

  def handle_event("close_perform_dialog", _params, socket) do
    {:halt, close_perform_dialog(socket)}
  end

  def handle_event("perform_dialog_tab", %{"tab" => tab}, socket) do
    {:halt, assign(socket, perform_dialog_tab: tab)}
  end

  def handle_event("perform_select", %{"position" => pos}, socket) do
    {:halt, assign(socket, perform_selected: String.to_integer(pos))}
  end

  def handle_event("perform_dialog_add", _params, socket) do
    {:halt, assign(socket, show_perform_add_dialog: true)}
  end

  def handle_event("close_perform_add_dialog", _params, socket) do
    {:halt, assign(socket, show_perform_add_dialog: false)}
  end

  def handle_event("perform_dialog_add_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_perform_add_dialog: false)
         |> maybe_persist_perform_list(new_session)}

      {:error, reason} ->
        {:halt,
         stream_insert(
           socket,
           :chat_messages,
           error_message(gettext("Failed to add perform command: %{reason}", reason: reason))
         )}
    end
  end

  def handle_event("perform_dialog_edit", _params, socket) do
    if socket.assigns.perform_selected do
      {:halt, assign(socket, show_perform_edit_dialog: true)}
    else
      {:halt, socket}
    end
  end

  def handle_event("close_perform_edit_dialog", _params, socket) do
    {:halt, assign(socket, show_perform_edit_dialog: false)}
  end

  def handle_event("perform_dialog_edit_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session
    position = socket.assigns.perform_selected

    if position do
      updated_list = PerformList.update_entry(session.perform_list, position, command)
      new_session = Session.set_perform_list(session, updated_list)

      {:halt,
       socket
       |> assign(session: new_session, show_perform_edit_dialog: false)
       |> maybe_persist_perform_list(new_session)}
    else
      {:halt, assign(socket, show_perform_edit_dialog: false)}
    end
  end

  def handle_event("perform_dialog_remove", _params, socket) do
    position = socket.assigns.perform_selected

    if position do
      session = socket.assigns.session

      case PerformList.remove_entry(session.perform_list, position) do
        {:ok, updated_list} ->
          new_session = Session.set_perform_list(session, updated_list)

          {:halt,
           socket
           |> assign(session: new_session, perform_selected: nil)
           |> maybe_persist_perform_list(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("perform_dialog_move_up", _params, socket) do
    position = socket.assigns.perform_selected

    if position && position > 0 do
      session = socket.assigns.session

      case PerformList.move_entry(session.perform_list, position, position - 1) do
        {:ok, updated_list} ->
          new_session = Session.set_perform_list(session, updated_list)

          {:halt,
           socket
           |> assign(session: new_session, perform_selected: position - 1)
           |> maybe_persist_perform_list(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("perform_dialog_move_down", _params, socket) do
    position = socket.assigns.perform_selected
    session = socket.assigns.session
    max_pos = PerformList.count(session.perform_list) - 1

    if position && position < max_pos do
      case PerformList.move_entry(session.perform_list, position, position + 1) do
        {:ok, updated_list} ->
          new_session = Session.set_perform_list(session, updated_list)

          {:halt,
           socket
           |> assign(session: new_session, perform_selected: position + 1)
           |> maybe_persist_perform_list(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("perform_toggle_enabled", _params, socket) do
    session = socket.assigns.session
    current = PerformList.enabled?(session.perform_list)
    updated_list = PerformList.set_enabled(session.perform_list, !current)
    new_session = Session.set_perform_list(session, updated_list)

    {:halt,
     socket
     |> assign(session: new_session)
     |> maybe_persist_perform_list(new_session)}
  end

  def handle_event("autojoin_select", %{"channel" => channel}, socket) do
    {:halt, assign(socket, autojoin_selected: channel)}
  end

  def handle_event("autojoin_dialog_add", _params, socket) do
    {:halt, assign(socket, show_autojoin_add_dialog: true)}
  end

  def handle_event("close_autojoin_add_dialog", _params, socket) do
    {:halt, assign(socket, show_autojoin_add_dialog: false)}
  end

  def handle_event("autojoin_dialog_add_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = params["key"]
    key = if key == "", do: nil, else: key

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_autojoin_add_dialog: false)
         |> maybe_persist_autojoin_list(new_session)}

      {:error, reason} ->
        {:halt,
         stream_insert(
           socket,
           :chat_messages,
           error_message(gettext("Failed to add auto-join channel: %{reason}", reason: reason))
         )}
    end
  end

  def handle_event("autojoin_dialog_edit", _params, socket) do
    if socket.assigns.autojoin_selected do
      {:halt, assign(socket, show_autojoin_edit_dialog: true)}
    else
      {:halt, socket}
    end
  end

  def handle_event("close_autojoin_edit_dialog", _params, socket) do
    {:halt, assign(socket, show_autojoin_edit_dialog: false)}
  end

  def handle_event("autojoin_dialog_edit_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = params["key"]
    key = if key == "", do: nil, else: key

    case AutoJoinList.update_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_autojoin_edit_dialog: false)
         |> maybe_persist_autojoin_list(new_session)}

      {:error, _} ->
        {:halt, assign(socket, show_autojoin_edit_dialog: false)}
    end
  end

  def handle_event("autojoin_dialog_remove", _params, socket) do
    channel = socket.assigns.autojoin_selected

    if channel do
      session = socket.assigns.session

      case AutoJoinList.remove_entry(session.autojoin_list, channel) do
        {:ok, updated_list} ->
          new_session = Session.set_autojoin_list(session, updated_list)

          {:halt,
           socket
           |> assign(session: new_session, autojoin_selected: nil)
           |> maybe_persist_autojoin_list(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  # Catch-all: pass unhandled events to the next hook
  def handle_event(_event, _params, socket), do: {:cont, socket}

  # Private helpers

  defp close_perform_dialog(socket) do
    assign(socket,
      show_perform_dialog: false,
      perform_dialog_tab: "commands",
      perform_selected: nil,
      show_perform_add_dialog: false,
      show_perform_edit_dialog: false,
      autojoin_selected: nil,
      show_autojoin_add_dialog: false,
      show_autojoin_edit_dialog: false
    )
  end
end
