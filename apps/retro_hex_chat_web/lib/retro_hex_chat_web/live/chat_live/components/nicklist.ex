defmodule RetroHexChatWeb.ChatLive.Components.Nicklist do
  @moduledoc """
  The channel nicklist sidebar. Owns the `:users` stream and renders one row per
  member, so the list updates per-row and re-renders only on membership/role/away/
  mute deltas — not on every chat re-render of the parent LiveView.

  The parent stays the canonical owner of `channel_users`: the tab-complete
  (`MenuToolbarEvents`), the nicklist context menu and several PubSub handlers read
  the materialized list. The parent keeps that list and feeds this component the
  matching delta via `send_update/2`:

    * `{:reset, users}` — channel switch or bulk change (mode, away, rename)
    * `{:upsert, user}` — a single user joined or changed
    * `{:remove, nick}` — a single user left or was kicked

  `show_nicklist` stays on the parent (toggled from the menu/toolbar and read by
  the sidebar visibility gate); it arrives here as `visible`. The container is kept
  mounted while hidden (via a CSS class, not `:if`) so the stream is never torn
  down and rebuilt on toggle. The right-click/double-click `NicklistHook` pushes to
  the parent, which owns the context menu and reads `channel_users` there.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Nicklist

  @id "nicklist"

  @doc "Stable component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Stable DOM id for a user's stream row, keyed by the normalized nick."
  @spec dom_id(String.t()) :: String.t()
  def dom_id(nick), do: "nick-" <> String.downcase(nick)

  @doc "Replaces the whole list (channel switch or bulk change). Returns the socket."
  @spec reset(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  def reset(socket, users) do
    send_update(__MODULE__, id: @id, action: {:reset, users})
    socket
  end

  @doc "Inserts or updates a single user row. Returns the socket."
  @spec upsert(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def upsert(socket, user) do
    send_update(__MODULE__, id: @id, action: {:upsert, user})
    socket
  end

  @doc "Removes a single user row by nick. Returns the socket."
  @spec remove(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def remove(socket, nick) do
    send_update(__MODULE__, id: @id, action: {:remove, nick})
    socket
  end

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(id: @id, visible: false, nick_color_fn: fn _nick -> nil end)
     |> stream(:users, [], dom_id: &row_dom_id/1)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:reset, users}}, socket) do
    {:ok, stream(socket, :users, users, reset: true, dom_id: &row_dom_id/1)}
  end

  def update(%{action: {:upsert, user}}, socket) do
    {:ok, stream_insert(socket, :users, user)}
  end

  def update(%{action: {:remove, nick}}, socket) do
    {:ok, stream_delete_by_dom_id(socket, :users, dom_id(nick))}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       visible: Map.get(assigns, :visible, socket.assigns.visible),
       nick_color_fn: Map.get(assigns, :nick_color_fn, socket.assigns.nick_color_fn)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.nicklist_sidebar
        visible={@visible}
        on_backdrop="toggle_nicklist"
        id="nicklist-users"
        phx-hook="NicklistHook"
        phx-update="stream"
      >
        <.nicklist_item
          :for={{dom_id, user} <- @streams.users}
          id={dom_id}
          nick={user.nickname}
          role={Map.get(user, :role, :normal)}
          status={if Map.get(user, :away), do: "away", else: "online"}
          nick_color={@nick_color_fn.(user.nickname)}
          data-nick={user.nickname}
        />
      </.nicklist_sidebar>
    </div>
    """
  end

  @spec row_dom_id(map()) :: String.t()
  defp row_dom_id(user), do: dom_id(user.nickname)
end
