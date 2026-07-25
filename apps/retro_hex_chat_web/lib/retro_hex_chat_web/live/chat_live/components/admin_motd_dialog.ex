defmodule RetroHexChatWeb.ChatLive.Components.AdminMotdDialog do
  @moduledoc """
  Stateful island for the Admin MOTD window.

  Owns the current message and the outcome strip. Mounted inside a
  server-managed window: presence in the DOM means open, so closing unmounts
  the island.

  Every action re-reads `Motd.get/0` afterwards, so the "current" pane always
  reflects the server rather than what the form last submitted.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminMotdDialog

  alias RetroHexChat.Services.Motd
  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  @id "admin-motd-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{content: nil, result: nil, loaded?: false}

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(@initial) |> assign(session: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.loaded? do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded?: true) |> assign_snapshot(nil)}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_motd_refresh", _params, socket) do
    dispatch_and_reload(socket, "motd", [])
  end

  def handle_event("admin_motd_set", %{"motd" => motd}, socket) do
    dispatch_and_reload(socket, "setmotd", args(motd))
  end

  def handle_event("admin_motd_clear", _params, socket) do
    dispatch_and_reload(socket, "clearmotd", [])
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, editable: ChatContext.admin_only?(assigns.session))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_motd_panel
        id={@id}
        target={@myself}
        content={@content}
        result={@result}
        editable={@editable}
        on_set="admin_motd_set"
        on_clear="admin_motd_clear"
        on_refresh="admin_motd_refresh"
      />
    </div>
    """
  end

  defp dispatch_and_reload(socket, command, args) do
    if AdminOps.admin?(socket) do
      result = AdminOps.dispatch(socket, command, args)
      {:noreply, assign_snapshot(socket, AdminOps.result_entry(result))}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  defp assign_snapshot(socket, result) do
    assign(socket, content: Motd.get(), result: result)
  end

  # An empty MOTD is `setmotd` with no argument, not with a blank one.
  defp args(content) do
    case String.trim(content) do
      "" -> []
      trimmed -> [trimmed]
    end
  end
end
