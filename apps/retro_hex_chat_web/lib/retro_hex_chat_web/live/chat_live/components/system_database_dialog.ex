defmodule RetroHexChatWeb.ChatLive.Components.SystemDatabaseDialog do
  @moduledoc """
  Stateful island behind the Database Stats window.

  The catalogue of reports is read at mount — it is a property of the repo's
  extensions, not of any one run — but no report is executed until one is
  chosen. Which reports exist at all is the domain's decision: destructive
  entries never reach this list.

  A failing report is reported in place rather than raised. These queries run
  against a live database and can fail for reasons entirely outside the node —
  a missing extension, a lock, a permission the role lacks — and none of them
  should take down the window, let alone the chat behind it.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.DatabasePanel

  alias RetroHexChat.{Repo, SystemInfo}
  alias RetroHexChatWeb.ChatLive.AdminOps

  @id "system-database-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(reports: nil, selected: nil, table: nil, error: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.reports do
      {:ok, socket}
    else
      {:ok, assign(socket, reports: SystemInfo.database_reports(Repo))}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_database_select", %{"report" => ""}, socket) do
    {:noreply, assign(socket, selected: nil, table: nil, error: nil)}
  end

  def handle_event("system_database_select", %{"report" => report}, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, run(socket, report)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.database_panel
        id={@id}
        reports={@reports || []}
        selected={@selected}
        table={@table}
        error={@error}
        target={@myself}
        on_select="system_database_select"
      />
    </div>
    """
  end

  defp run(socket, report) do
    case SystemInfo.run_database_report(Repo, report) do
      {:ok, table} ->
        assign(socket, selected: report, table: table, error: nil)

      {:error, :unknown_report} ->
        assign(socket,
          selected: nil,
          table: nil,
          error: dgettext("dialogs", "That report is not available on this server.")
        )

      {:error, :query_failed} ->
        assign(socket,
          selected: report,
          table: nil,
          error:
            dgettext(
              "dialogs",
              "The report could not be run — the database refused the query or an extension it needs is missing."
            )
        )
    end
  end
end
