defmodule RetroHexChatWeb.ChatLive.ReadMarkers do
  @moduledoc """
  Where the reader had got to in each conversation.

  One rule decides everything here: **the marker does not move while you are
  reading.** It moves when you look away — the conversation loses focus, or the
  tab is focused again with the conversation already open — and never when a
  message arrives. Advancing on arrival is the classic way to build this
  feature and end up with a line that never appears: by the time you look, the
  marker is already past everything new.

  So the marker is the id of the last message that was on screen when you
  stopped looking, and the divider is drawn above the message after it.

  A conversation with no marker draws no divider. A first visit has no "new".
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Chat.ReconnectState
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @type markers :: %{String.t() => pos_integer()}

  @doc "The marker for the conversation on screen, or `nil` if there is none."
  @spec current(Phoenix.LiveView.Socket.t()) :: pos_integer() | nil
  def current(socket) do
    Map.get(markers(socket), Messages.conversation_key(socket.assigns.session))
  end

  @doc """
  Move the marker for the conversation on screen up to the newest line in it.

  Called when the reader looks away, not when something arrives. Takes the
  newest id from the stream's own record of what it is showing, because that is
  the only place that knows what was actually on screen.
  """
  @spec advance(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def advance(socket) do
    advance(socket, Messages.conversation_key(socket.assigns.session))
  end

  @doc "The same, for a conversation the reader is leaving."
  @spec advance(Phoenix.LiveView.Socket.t(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def advance(socket, nil), do: socket

  def advance(socket, key) do
    case socket.assigns[:newest_message_id] do
      nil -> socket
      id -> put(socket, key, id)
    end
  end

  @doc "Remember the newest line the viewport has shown, whichever conversation."
  @spec seen(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  def seen(socket, id) when is_integer(id), do: assign(socket, newest_message_id: id)
  def seen(socket, _id), do: socket

  @doc """
  Work out which row the divider belongs above, from the page just loaded.

  The first line newer than the marker, in the page the reader is about to see.
  Computed from the page rather than queried, because the page is already in
  hand and a conversation whose new messages are older than the loaded window
  has nothing to draw a rule above anyway.
  """
  @spec put_boundary(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  def put_boundary(socket, items) do
    assign(socket, unread_boundary_id: boundary(current(socket), items))
  end

  @doc "Forget the divider, because there is nothing new to separate."
  @spec clear_boundary(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def clear_boundary(socket), do: assign(socket, unread_boundary_id: nil)

  @spec boundary(pos_integer() | nil, [map()]) :: pos_integer() | nil
  defp boundary(nil, _items), do: nil

  defp boundary(marker, items) do
    items
    |> Enum.map(&Map.get(&1, :id))
    |> Enum.filter(&(is_integer(&1) and &1 > marker))
    |> Enum.min(fn -> nil end)
  end

  @doc """
  Replace the newest line outright, because the conversation was replaced.

  Unlike `seen/2` this accepts `nil`: a conversation with nothing in it has no
  newest line, and keeping the previous one would move the wrong marker the
  next time the reader looks away.
  """
  @spec replace_seen(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  def replace_seen(socket, id) when is_integer(id) or is_nil(id),
    do: assign(socket, newest_message_id: id)

  def replace_seen(socket, _id), do: assign(socket, newest_message_id: nil)

  @doc "Forget the newest line, because the conversation changed under it."
  @spec reset_seen(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def reset_seen(socket), do: assign(socket, newest_message_id: nil)

  @spec put(Phoenix.LiveView.Socket.t(), String.t(), pos_integer()) ::
          Phoenix.LiveView.Socket.t()
  defp put(socket, key, id) do
    markers = Map.put(markers(socket), key, id)

    assign(socket,
      read_markers: ReconnectState.normalize(%{read_markers: markers}).read_markers
    )
  end

  @spec markers(Phoenix.LiveView.Socket.t()) :: markers()
  defp markers(socket), do: socket.assigns[:read_markers] || %{}
end
