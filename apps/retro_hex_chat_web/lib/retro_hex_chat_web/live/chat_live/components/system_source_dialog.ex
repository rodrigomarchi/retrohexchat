defmodule RetroHexChatWeb.ChatLive.Components.SystemSourceDialog do
  @moduledoc """
  Stateful island behind each of the five runtime listing windows.

  One module, five mounts. The window passes a `source` — `:processes`,
  `:ports`, `:sockets`, `:ets` or `:applications` — and everything else follows
  from what that source declares: its columns, its default ordering, the icon
  and title above it. A sixth listing would be a row in a table here, not a
  sixth copy of this file.

  Nothing is read at mount beyond the first page. The listing walks every
  entity of its kind on the node, so it is refreshed when the reader asks and
  when they change the query — never on a timer. A window left open on a busy
  node must not be a load the operator forgot they were applying.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.SourceBrowser

  alias RetroHexChat.SystemInfo
  alias RetroHexChat.SystemInfo.Query
  alias RetroHexChatWeb.ChatLive.AdminOps

  @spec id(atom()) :: String.t()
  def id(source), do: "system-#{source}-dialog"

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, table: nil, query: nil, source: nil, module: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.table do
      {:ok, socket}
    else
      {:ok, load(socket, %{})}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_source_search", params, socket) do
    guarded(socket, fn -> load(socket, params) end)
  end

  def handle_event("system_source_refresh", _params, socket) do
    guarded(socket, fn -> reload(socket) end)
  end

  @doc """
  Reorders the listing by the clicked column.

  The toggle lives in the query rather than here, so clicking the active column
  flips it and clicking another starts it descending — the behaviour every
  table on every desktop has, expressed once.
  """
  def handle_event("system_source_sort", %{"column" => column}, socket) do
    guarded(socket, fn ->
      case resolve_column(socket, column) do
        nil -> socket
        key -> socket |> update_query(&Query.toggle_sort(&1, key)) |> reload()
      end
    end)
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, presentation: presentation(assigns.source))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.source_browser
        id={@id}
        icon={@presentation.icon}
        title={@presentation.title}
        empty_title={@presentation.empty}
        table={@table}
        search={@query && @query.search}
        sort_by={@query && @query.sort_by}
        sort_dir={(@query && @query.sort_dir) || :desc}
        limit={(@query && @query.limit) || 50}
        target={@myself}
        on_search="system_source_search"
        on_sort="system_source_sort"
        on_refresh="system_source_refresh"
        testid={"system-#{@source}"}
      />
    </div>
    """
  end

  # Every listing walks the whole node, so a caller without the role must not
  # be able to trigger one by forging an event at the island.
  defp guarded(socket, fun) do
    if AdminOps.admin?(socket) do
      {:noreply, fun.()}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  defp load(socket, params) do
    {:ok, module} = SystemInfo.fetch_source(socket.assigns.source)
    query = SystemInfo.query(module, merge_params(socket, params))

    socket
    |> assign(module: module, query: query)
    |> assign(table: SystemInfo.list(module, query))
  end

  defp reload(%{assigns: %{module: module, query: query}} = socket) do
    assign(socket, table: SystemInfo.list(module, query))
  end

  # A submitted form carries only the controls it owns; the ordering it does
  # not mention has to survive, or every keystroke would reset the sort.
  defp merge_params(%{assigns: %{query: nil}}, params), do: params

  defp merge_params(%{assigns: %{query: query}}, params) do
    Map.merge(
      %{"sort_by" => query.sort_by, "sort_dir" => query.sort_dir, "limit" => query.limit},
      params
    )
  end

  defp update_query(socket, fun), do: assign(socket, query: fun.(socket.assigns.query))

  # The clicked column arrives as a string from the DOM and is resolved against
  # what the source declares, so no name from the client becomes an atom.
  defp resolve_column(%{assigns: %{module: module}}, column) do
    module.columns()
    |> Enum.map(& &1.key)
    |> Enum.find(&(Atom.to_string(&1) == column))
  end

  defp presentation(:processes) do
    %{
      icon: :icon_cpu,
      title: dgettext("dialogs", "Processes"),
      empty: dgettext("dialogs", "No processes matched")
    }
  end

  defp presentation(:ports) do
    %{
      icon: :icon_plug,
      title: dgettext("dialogs", "Ports"),
      empty: dgettext("dialogs", "No ports matched")
    }
  end

  defp presentation(:sockets) do
    %{
      icon: :icon_websocket,
      title: dgettext("dialogs", "Sockets"),
      empty: dgettext("dialogs", "No sockets matched")
    }
  end

  defp presentation(:ets) do
    %{
      icon: :icon_table_grid,
      title: dgettext("dialogs", "ETS tables"),
      empty: dgettext("dialogs", "No ETS tables matched")
    }
  end

  defp presentation(:applications) do
    %{
      icon: :icon_app_stack,
      title: dgettext("dialogs", "Applications"),
      empty: dgettext("dialogs", "No applications matched")
    }
  end

  defp presentation(:allocators) do
    %{
      icon: :icon_memory,
      title: dgettext("dialogs", "Memory allocators"),
      empty: dgettext("dialogs", "No allocators matched")
    }
  end
end
