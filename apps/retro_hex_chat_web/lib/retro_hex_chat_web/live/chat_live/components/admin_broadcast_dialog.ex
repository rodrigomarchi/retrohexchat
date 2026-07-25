defmodule RetroHexChatWeb.ChatLive.Components.AdminBroadcastDialog do
  @moduledoc """
  Stateful island for the Admin Broadcast window.

  Owns only the outcome strip — the window is write-only, so there is no
  snapshot to load and nothing to refresh. Mounted inside a server-managed
  window: presence in the DOM means open, so closing unmounts the island and
  clears the last result.

  The two reaches are gated apart: wallops for anyone who can operate the admin
  windows, announce for full admins only.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AdminBroadcastDialog

  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  @id "admin-broadcast-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(result: nil, session: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event(
        "admin_broadcast_send",
        %{"broadcast_type" => type, "message" => message},
        socket
      ) do
    if AdminOps.admin?(socket) do
      result = AdminOps.dispatch(socket, command(type), args(message))
      {:noreply, assign(socket, result: AdminOps.result_entry(result))}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        can_wallops: ChatContext.admin?(assigns.session),
        can_announce: ChatContext.admin_only?(assigns.session)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_broadcast_panel
        id={@id}
        target={@myself}
        result={@result}
        can_wallops={@can_wallops}
        can_announce={@can_announce}
        on_send="admin_broadcast_send"
      />
    </div>
    """
  end

  # Anything that is not an explicit announce is a wallops, so a tampered radio
  # value falls back to the narrower reach.
  defp command("announce"), do: "announce"
  defp command(_type), do: "wallops"

  defp args(message) do
    case String.trim(message) do
      "" -> []
      trimmed -> [trimmed]
    end
  end
end
