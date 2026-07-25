defmodule RetroHexChatWeb.ChatLive.Components.AdminAuditLogDialog do
  @moduledoc """
  Stateful island for the Admin Audit Log window.

  Owns the log text and the two filters. Mounted inside a server-managed window:
  presence in the DOM means open, so closing unmounts the island.

  The outcome strip only appears on failure — a successful read is the pane
  itself, and a green "ok" strip above a log would be noise.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminAuditLogDialog

  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  @id "admin-audit-log-dialog"
  @default_last "20"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    text: nil,
    result: nil,
    last: @default_last,
    user: "",
    loaded?: false
  }

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
      {:ok, socket |> assign(loaded?: true) |> assign_snapshot(%{})}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_audit_log_refresh", params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, assign_snapshot(socket, params)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, can_refresh: ChatContext.admin_only?(assigns.session))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_audit_log_panel
        id={@id}
        target={@myself}
        text={@text}
        last={@last}
        user={@user}
        result={@result}
        can_refresh={@can_refresh}
        on_refresh="admin_audit_log_refresh"
      />
    </div>
    """
  end

  defp assign_snapshot(socket, params) do
    last = normalize_last(Map.get(params, "last", socket.assigns.last))
    user = trim(Map.get(params, "user", socket.assigns.user))

    result = AdminOps.dispatch(socket, "admin", args(last, user))

    assign(socket,
      text: AdminOps.result_message(result),
      last: last,
      user: user,
      result: error_only(result)
    )
  end

  defp args(last, ""), do: ["log", "--last", last]
  defp args(last, user), do: ["log", "--last", last, "--user", user]

  # A blank row count would ask the server for everything.
  defp normalize_last(value) do
    case trim(value) do
      "" -> @default_last
      last -> last
    end
  end

  defp error_only(result) do
    if AdminOps.result_status(result) == :error, do: AdminOps.result_entry(result)
  end

  defp trim(value), do: value |> to_string() |> String.trim()
end
