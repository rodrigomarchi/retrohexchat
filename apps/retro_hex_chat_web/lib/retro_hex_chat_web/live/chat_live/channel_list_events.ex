defmodule RetroHexChatWeb.ChatLive.ChannelListEvents do
  @moduledoc """
  Handle events for the Channel List dialog.

  Covers: channel_list / toggle_channel_list (open/focus the window),
  channel_list_filter (a search term and a subject), channel_list_join, and the
  knock-request modal flow.

  Attached as `attach_hook(:channel_list_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Channels.Categories
  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChatWeb.ChatLive.Components.KnockRequestDialog
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.UiActions.Core
  alias RetroHexChatWeb.ChatLive.Windows

  @max_knock_message_length 200

  @no_filter %{search: "", category: nil}

  @doc """
  Opens/focuses the Channel List window and loads the visible channels into the
  parent passthrough assign. Shared by the menu/toolbar event, the conversations
  "browse all" button, and the `/list` command, which keep whatever filter the
  reader left; `category:` — a featured section's "see more" — opens on every
  room about that subject instead, with no search term.
  """
  @spec open(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  def open(socket, opts \\ []) do
    filter =
      case Keyword.fetch(opts, :category) do
        {:ok, category} -> %{search: "", category: Categories.normalize(category)}
        :error -> Map.get(socket.assigns, :channel_list_filter, @no_filter)
      end

    socket
    |> apply_filter(filter)
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

  # The filter re-reads the directory with the term and the subject applied at
  # the source rather than handing the island the whole list to sift through.
  def handle_event("channel_list_filter", params, socket) do
    filter = %{
      search: Map.get(params, "search", ""),
      category: Categories.normalize(Map.get(params, "category"))
    }

    {:halt, apply_filter(socket, filter)}
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

  # The filter is kept here rather than in the island, so reopening the window
  # lists what the filter it still shows says.
  defp apply_filter(socket, filter) do
    channels =
      Autocomplete.list_visible_channels(socket.assigns.session.channels,
        search: blank_to_nil(filter.search),
        category: filter.category
      )

    assign(socket,
      channel_list_channels: channels,
      channel_list_filter: filter,
      channel_list_loading: false
    )
  end

  defp blank_to_nil(text) when is_binary(text) do
    if String.trim(text) == "", do: nil, else: text
  end

  defp blank_to_nil(_text), do: nil

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
