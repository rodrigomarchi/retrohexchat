defmodule RetroHexChatWeb.ChatLive.Components.SystemHomeDialog do
  @moduledoc """
  Stateful island behind the System Home window.

  Holds two readings with different lifetimes. The node's description is taken
  once at mount, because a running node cannot change its emulator or its
  loaded versions. The vitals are re-read on demand, and only on demand: they
  are cheap, but a window that polls by itself is a load nobody chose to apply.

  The versions reported are named here rather than in the domain, which is what
  keeps `SystemInfo` from having to know that a web framework exists.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.HomePanel

  alias RetroHexChat.SystemInfo
  alias RetroHexChatWeb.ChatLive.AdminOps

  @id "system-home-dialog"

  # The stack a reader is placing the node in: language, framework, product.
  # Each carries how it should be named and drawn, because `:phoenix_live_view`
  # is an application key, not a thing anyone calls it — and a column of
  # identical icons distinguishes nothing.
  @reported_apps [
    %{app: :elixir, label: "Elixir", icon: :icon_elixir},
    %{app: :phoenix, label: "Phoenix", icon: :icon_globe},
    %{app: :phoenix_live_view, label: "LiveView", icon: :icon_websocket},
    %{app: :retro_hex_chat, label: "RetroHexChat", icon: :icon_hex_stone}
  ]

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(info: nil, usage: nil, versions: [])}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.info do
      {:ok, socket}
    else
      info = SystemInfo.info(Enum.map(@reported_apps, & &1.app))

      {:ok,
       socket
       |> assign(info: info, usage: SystemInfo.usage())
       |> assign(versions: versions(info))}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_home_refresh", _params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, assign(socket, usage: SystemInfo.usage())}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.home_panel
        id={@id}
        info={@info}
        usage={@usage}
        versions={@versions}
        target={@myself}
        on_refresh="system_home_refresh"
      />
    </div>
    """
  end

  # Joins each measured version to how it is presented. The reading stays the
  # domain's — this only decides what the application is called on screen and
  # which icon stands for it.
  defp versions(info) do
    measured = Map.new(info.versions, &{&1.app, &1.version})

    Enum.map(@reported_apps, fn entry ->
      Map.put(entry, :version, Map.get(measured, entry.app))
    end)
  end
end
