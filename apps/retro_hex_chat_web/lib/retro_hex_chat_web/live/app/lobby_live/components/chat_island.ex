defmodule RetroHexChatWeb.App.LobbyLive.Components.ChatIsland do
  @moduledoc """
  Chat island — owner of the lobby's `messages` list and the body of the "Chat"
  window.

  Besides the chat the user sends and receives, this list is the shared
  system-message sink: every other lobby feature (media, file transfer, games,
  the connection itself) records its notices here. Those producers append a line
  via `send_update(__MODULE__, id: id(), system_message: text)`; peer/own chat
  lines arrive from the host's `lobby_message` PubSub adapter as
  `send_update(__MODULE__, id: id(), append_message: msg)`.

  The list is short and churny, so it is held and rendered as a plain assign
  (passthrough + append), not a stream. The send form stays an adapter on the
  host — it needs the `Lobby` context and the session — and its message echoes
  back into this island through PubSub.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Lobby.ChatPanel

  @id "lobby-chat"

  @doc "Stable DOM/component id used by the host for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, messages: [])}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{system_message: text}, socket), do: {:ok, append(socket, system_message(text))}

  def update(%{append_message: msg}, socket), do: {:ok, append(socket, msg)}

  def update(assigns, socket) do
    {:ok, assign(socket, id: Map.get(assigns, :id, socket.assigns.id))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full">
      <.chat_panel messages={@messages} />
    </div>
    """
  end

  @spec append(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp append(socket, msg) do
    assign(socket, :messages, socket.assigns.messages ++ [msg])
  end

  @spec system_message(String.t()) :: map()
  defp system_message(content) do
    %{
      id: System.unique_integer([:positive]),
      sender_nick: dgettext("lobby", "System"),
      content: content,
      type: "system",
      timestamp: DateTime.utc_now()
    }
  end
end
