defmodule RetroHexChatWeb.ChatLive.Components.UserContextMenus do
  @moduledoc """
  Stateful island for the two user-target right-click context menus — the chat
  message menu and the nicklist menu — plus the inline nick-color picker they
  share.

  Owns three maps lifted out of the parent `assign_defaults`: `chat_context_menu`
  (the message/url/nick menu), `context_menu` (the nicklist menu), and the
  `show_context_color_picker` flag. Both menus target a user and share one color
  picker, so they live in one island: the picker reuses the nicklist `context_menu`
  state for its target, and "set color" from the chat menu copies the chat menu's
  `x`/`y` into it — a cross-menu coupling that is now internal to this component
  (the `set_color_from_chat` update directive) instead of a parent assign read.

  The action handlers stay parent adapters in `ChatLive.ContextMenuEvents`: open
  (`nick_right_click`/`chat_context_menu`), close, and `*_set_nick_color` drive
  this component via `send_update` (the events module's `put_*_menu`/`open_color_picker`
  helpers); every other `context_*`/`ctx_chat_*` action reads its target from the
  menu item's `phx-value` params and does the privileged session/server work on the
  parent. The read-model the menus derive from — `session`, the canonical
  `conversation_members` list, and `nick_color_fn` — stays parent-owned and arrives here as
  passthrough; the menus derive viewer/target permissions, ignore state, and custom
  items in `render/1` (helpers moved here from the parent). Change-tracking isolates
  both menus from parent hot-path re-renders.
  """
  use RetroHexChatWeb, :live_component

  require Logger

  import RetroHexChatWeb.Components.UI.ChatContextMenu
  import RetroHexChatWeb.Components.UI.NicklistContextMenu

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{CustomMenus, IgnoreList, KeyBindings}

  @id "user-context-menus"

  @spec id() :: String.t()
  def id, do: @id

  @chat_closed %{
    visible: false,
    type: nil,
    x: 0,
    y: 0,
    target_nick: nil,
    target_url: nil,
    target_channel: nil,
    target_message: nil,
    has_selection: false,
    is_target_registered: false
  }

  @nick_closed %{visible: false, x: 0, y: 0, target_nick: nil, is_target_registered: false}

  @spec chat_closed() :: map()
  def chat_closed, do: @chat_closed

  @spec nick_closed() :: map()
  def nick_closed, do: @nick_closed

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(
       chat_context_menu: @chat_closed,
       context_menu: @nick_closed,
       show_context_color_picker: false
     )
     |> assign(session: nil, conversation_members: [], nick_color_fn: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{set_color_from_chat: nick}, socket) do
    chat = socket.assigns.chat_context_menu

    {:ok,
     assign(socket,
       chat_context_menu: @chat_closed,
       context_menu: %{
         visible: true,
         x: chat.x,
         y: chat.y,
         target_nick: nick,
         is_target_registered: false
       },
       show_context_color_picker: true
     )}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    chat = assigns.chat_context_menu
    nick_menu = assigns.context_menu
    session = assigns.session
    users = assigns.conversation_members
    viewer_op = viewer_is_op?(session)

    assigns =
      assign(assigns,
        chat: chat,
        nick_menu: nick_menu,
        viewer_op: viewer_op,
        chat_is_target_ignored: chat_context_target_ignored?(session, chat),
        chat_is_target_self: chat.target_nick == session.nickname,
        chat_is_target_registered: chat[:is_target_registered] || false,
        chat_is_target_op: channel_user_op?(users, chat.target_nick),
        chat_is_target_voiced: channel_user_voiced?(users, chat.target_nick),
        chat_is_target_muted: channel_user_muted?(users, chat.target_nick),
        chat_is_already_joined: chat.target_channel in (session.channels || []),
        chat_custom_items: CustomMenus.entries_for(session.custom_menus, :chat),
        nick_is_target_ignored: context_target_ignored?(session, nick_menu.target_nick),
        nick_is_target_self: nick_menu.target_nick == session.nickname,
        nick_is_target_op: channel_user_op?(users, nick_menu.target_nick),
        nick_is_target_voiced: channel_user_voiced?(users, nick_menu.target_nick),
        nick_is_target_muted: channel_user_muted?(users, nick_menu.target_nick),
        nick_custom_items: CustomMenus.entries_for(session.custom_menus, :nicklist),
        key_bindings: KeyBindings.defaults()
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.chat_context_menu
        visible={@chat.visible}
        x={@chat.x}
        y={@chat.y}
        type={@chat.type || :nick}
        target_nick={@chat.target_nick}
        target_url={@chat.target_url}
        target_channel={@chat.target_channel}
        target_message={@chat.target_message}
        viewer_nick={@session.nickname}
        viewer_is_op={@viewer_op}
        viewer_is_identified={@session.identified}
        is_target_ignored={@chat_is_target_ignored}
        is_target_self={@chat_is_target_self}
        is_target_registered={@chat_is_target_registered}
        is_target_op={@chat_is_target_op}
        is_target_voiced={@chat_is_target_voiced}
        is_target_muted={@chat_is_target_muted}
        is_already_joined={@chat_is_already_joined}
        custom_items={@chat_custom_items}
        key_bindings={@key_bindings}
        on_action="chat_context_action"
      />

      <.nicklist_context_menu
        visible={@nick_menu.visible}
        x={@nick_menu.x}
        y={@nick_menu.y}
        target_nick={@nick_menu.target_nick}
        viewer_nick={@session.nickname}
        viewer_is_op={@viewer_op}
        viewer_is_identified={@session.identified}
        is_target_ignored={@nick_is_target_ignored}
        is_target_self={@nick_is_target_self}
        is_target_op={@nick_is_target_op}
        is_target_voiced={@nick_is_target_voiced}
        is_target_muted={@nick_is_target_muted}
        show_color_picker={@show_context_color_picker}
        nick_color_fn={@nick_color_fn}
        custom_items={@nick_custom_items}
        key_bindings={@key_bindings}
        on_action="nicklist_context_action"
      />
    </div>
    """
  end

  # ── Derivation helpers (moved from the parent) ───────────────────

  @spec viewer_is_op?(map() | nil) :: boolean()
  defp viewer_is_op?(nil), do: false

  defp viewer_is_op?(session) do
    case session.active_channel do
      nil ->
        false

      channel ->
        case Server.get_state(channel) do
          {:ok, state} ->
            session.nickname in state.operators or
              session.nickname in Map.get(state, :owners, [])

          {:error, _} ->
            false
        end
    end
  rescue
    e ->
      Logger.warning("Failed to check operator status: #{inspect(e)}")
      false
  end

  @spec chat_context_target_ignored?(map() | nil, map()) :: boolean()
  defp chat_context_target_ignored?(_session, %{target_nick: nil}), do: false

  defp chat_context_target_ignored?(session, %{target_nick: nick}) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
  end

  @spec context_target_ignored?(map() | nil, String.t() | nil) :: boolean()
  defp context_target_ignored?(_session, nil), do: false

  defp context_target_ignored?(session, nick) do
    IgnoreList.get_entry(session.ignore_list, nick) != nil
  end

  @spec channel_user_op?(list(), String.t() | nil) :: boolean()
  defp channel_user_op?(users, nick), do: channel_user_role?(users, nick, [:operator])

  @spec channel_user_voiced?(list(), String.t() | nil) :: boolean()
  defp channel_user_voiced?(users, nick), do: channel_user_role?(users, nick, [:voiced])

  @spec channel_user_muted?(list(), String.t() | nil) :: boolean()
  defp channel_user_muted?(users, nick) do
    case find_channel_user(users, nick) do
      nil -> false
      user -> Map.get(user, :muted, false)
    end
  end

  @spec channel_user_role?(list(), String.t() | nil, list(atom())) :: boolean()
  defp channel_user_role?(users, nick, roles) do
    case find_channel_user(users, nick) do
      nil -> false
      user -> Map.get(user, :role) in roles
    end
  end

  @spec find_channel_user(list(), String.t() | nil) :: map() | nil
  defp find_channel_user(_users, nil), do: nil

  defp find_channel_user(users, nick) do
    Enum.find(users, &(Map.get(&1, :nickname) == nick))
  end
end
