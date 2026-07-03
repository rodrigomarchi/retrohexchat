defmodule RetroHexChatWeb.App.LobbyLive.Components.ChatIsland do
  @moduledoc """
  Chat island — owner of the lobby's `messages` list and the body of the "Chat"
  window.

  The window body is the same IRC surface as the main chat: a scrollable
  `chat_message`/`chat_message_list` history rendered from the ephemeral lobby
  messages, plus the shared `Composer` LiveComponent driven with a lobby
  capability set (formatting + nick autocomplete + `/me`, but no channels,
  emoji, reply, edit or paste). Message content runs through the same
  `ChatHelpers.format_content/2` (mIRC codes, links), timestamps through
  `format_time/3`, and nicks are colored by the deterministic hash.

  Besides the chat the user sends and receives, this list is the shared
  system-message sink: every other lobby feature (media, file transfer, games,
  the connection itself) records its notices here. Those producers append a line
  via `send_update(__MODULE__, id: id(), system_message: text)`; peer/own chat
  lines arrive from the host's `lobby_message` PubSub adapter as
  `send_update(__MODULE__, id: id(), append_message: msg)`.

  The list is short and churny, so it is held and rendered as a plain assign
  (passthrough + append), not a stream. The composer submits to the host (it
  needs the `Lobby` context and the session); its message echoes back into this
  island through PubSub.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChatMessage

  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.ChatLive.Components.Composer

  @id "lobby-chat"

  @lobby_capabilities %{
    action_mode: true,
    nick_autocomplete: true,
    channel_autocomplete: false,
    command_autocomplete: false,
    formatting_toolbar: true,
    emoji: false,
    typing_indicator: false,
    paste: false
  }

  @doc "Stable DOM/component id used by the host for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       messages: [],
       nickname: "",
       peer_nick: nil,
       strip_formatting: false,
       timezone: "Etc/UTC",
       capabilities: @lobby_capabilities
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{system_message: text}, socket), do: {:ok, append(socket, system_message(text))}

  def update(%{append_message: msg}, socket), do: {:ok, append(socket, msg)}

  def update(%{clear: true}, socket), do: {:ok, assign(socket, :messages, [])}

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex h-full flex-col gap-1">
      <.chat_message_list id="lobby-messages" testid="lobby-chat" fill class="space-y-0.5">
        <.chat_message
          :for={msg <- @messages}
          id={"lobby-msg-#{msg.id}"}
          timestamp={ChatHelpers.format_time(msg.timestamp, :dd_mm_hh_mm, @timezone)}
          nick={line_nick(msg)}
          nick_color={ChatHelpers.default_nick_color(msg.sender_nick)}
          type={line_type(msg)}
        >
          {action_prefix(msg)}{Phoenix.HTML.raw(
            ChatHelpers.format_content(msg.content, @strip_formatting)
          )}
        </.chat_message>
      </.chat_message_list>

      <.live_component
        module={Composer}
        id={Composer.id()}
        nickname={@nickname}
        channel_users={autocomplete_users(@nickname, @peer_nick)}
        channels={[]}
        strip_formatting={@strip_formatting}
        placeholder={dgettext("lobby", "Message — / for commands")}
        capabilities={@capabilities}
        show_emoji_picker={false}
        pm_typing_from={nil}
        edit_mode_message_id={nil}
      />
    </div>
    """
  end

  # System messages have no author; chat/action lines carry the sender nick.
  @spec line_nick(map()) :: String.t() | nil
  defp line_nick(%{type: "system"}), do: nil
  defp line_nick(%{sender_nick: nick}), do: nick

  @spec line_type(map()) :: String.t()
  defp line_type(%{type: "system"}), do: "system"
  defp line_type(%{type: "action"}), do: "action"
  defp line_type(_msg), do: "normal"

  # The nick moves to the meta column, so the action affordance ("* ") is
  # prepended to the body — mirroring the main chat's MessageRow.
  @spec action_prefix(map()) :: String.t()
  defp action_prefix(%{type: "action"}), do: "* "
  defp action_prefix(_msg), do: ""

  # Two-peer nick pool for the composer's nick autocomplete. `search_nicks`
  # filters out the caller's own nick, so including it is harmless.
  @spec autocomplete_users(String.t(), String.t() | nil) :: [map()]
  defp autocomplete_users(nickname, peer_nick) do
    [nickname, peer_nick]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(&%{nickname: &1, away: false})
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
