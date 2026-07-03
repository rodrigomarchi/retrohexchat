defmodule RetroHexChatWeb.ChatLive.ChannelListEvents do
  @moduledoc """
  Handle events for the Channel List dialog.

  Covers: channel_list / toggle_channel_list (open/focus the window),
  channel_list_filter, channel_list_select, channel_list_join, and the
  knock-request modal flow.

  Attached as `attach_hook(:channel_list_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChatWeb.ChatLive.Components.ChannelListDialog
  alias RetroHexChatWeb.ChatLive.Components.KnockRequestDialog
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.UiActions.Core
  alias RetroHexChatWeb.ChatLive.Windows

  @max_knock_message_length 200

  @doc """
  Opens/focuses the Channel List window: loads the visible channels into the
  parent passthrough assign and resets the island's selection. Shared by the
  menu/toolbar event, the conversations "browse all" button, and the `/list`
  command.
  """
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    channels = Autocomplete.list_visible_channels(socket.assigns.session.channels)
    send_update(ChannelListDialog, id: ChannelListDialog.id(), action: :open)

    socket
    |> assign(channel_list_channels: channels, channel_list_loading: false)
    |> Windows.open("channel-list")
  end

  @doc "Closes the Channel List window client-side (e.g. after joining)."
  @spec close(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def close(socket) do
    Phoenix.LiveView.push_event(socket, "window_command", %{action: "close", id: "channel-list"})
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("channel_list", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("toggle_channel_list", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("channel_list_filter", %{"search" => search}, socket) do
    send_update(ChannelListDialog, id: ChannelListDialog.id(), action: {:filter, search})
    {:halt, socket}
  end

  def handle_event("channel_list_select", %{"channel" => channel_name}, socket) do
    send_update(ChannelListDialog, id: ChannelListDialog.id(), action: {:select, channel_name})
    {:halt, socket}
  end

  def handle_event("channel_list_join", %{"channel" => channel_name}, socket) do
    socket =
      socket
      |> close()
      |> ChannelHelpers.join_channel(channel_name, socket.assigns.session)

    {:halt, socket}
  end

  def handle_event("channel_list_knock", %{"channel" => channel_name}, socket) do
    {:halt,
     socket
     |> close()
     |> open_knock_request_dialog(channel_name)}
  end

  def handle_event("knock_request_change", params, socket) do
    # A change only tracks the draft while the dialog is already open — it must
    # never OPEN the dialog. On a deploy reconnect LiveView re-fires phx-change
    # for every form still in the (persisted) DOM to recover in-flight input; the
    # hidden knock form is one of them, and force-opening here surfaced a spurious
    # "Request Channel Access" window with no channel on every reconnect.
    if socket.assigns.show_knock_request_dialog do
      send_update(KnockRequestDialog,
        id: KnockRequestDialog.id(),
        action: {:change, message_of(params)}
      )
    end

    {:halt, socket}
  end

  def handle_event("knock_request_submit", params, socket) do
    channel = Map.get(params, "channel")
    message = message_of(params)

    if String.length(message) > @max_knock_message_length do
      knock_error(socket, message, dgettext("chat", "Message must be 200 characters or less"))
    else
      case Core.knock_channel(socket, channel, message) do
        {:ok, socket} -> {:halt, close_knock_request_dialog(socket)}
        {:error, socket, error} -> knock_error(socket, message, error)
      end
    end
  end

  def handle_event("knock_request_cancel", _params, socket) do
    {:halt, close_knock_request_dialog(socket)}
  end

  # Catch-all — pass through all non-channel-list events
  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp message_of(params), do: Map.get(params, "message", "")

  defp knock_error(socket, message, error) do
    send_update(KnockRequestDialog,
      id: KnockRequestDialog.id(),
      action: {:error, message, error}
    )

    {:halt, assign(socket, show_knock_request_dialog: true)}
  end

  defp open_knock_request_dialog(socket, channel_name) do
    send_update(KnockRequestDialog,
      id: KnockRequestDialog.id(),
      action: {:open, channel_name}
    )

    assign(socket, show_knock_request_dialog: true)
  end

  defp close_knock_request_dialog(socket) do
    send_update(KnockRequestDialog, id: KnockRequestDialog.id(), action: :close)
    assign(socket, show_knock_request_dialog: false)
  end
end
