defmodule RetroHexChatWeb.ChatLive.Components.SystemLogDialog do
  @moduledoc """
  Stateful island behind the Live Log window.

  Streaming is off until asked for. Installing the log handler makes every
  process that logs anything pay a little, so it happens on a deliberate press
  and is undone the moment the window stops streaming or closes.

  The buffer is bounded and counts what it drops. A window that quietly kept
  the last two hundred lines would let an operator watch a burst scroll past
  and believe they had seen all of it.

  Entries arrive as PubSub broadcasts, which reach the host LiveView; the host
  forwards them here, because a LiveComponent owns no process of its own.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.LogPanel

  alias RetroHexChatWeb.ChatLive.AdminOps
  alias RetroHexChatWeb.SystemLog.Handler

  @id "system-log-dialog"
  @buffer 200
  @levels [:debug, :info, :warning, :error]

  @spec id() :: String.t()
  def id, do: @id

  @spec levels() :: [atom()]
  def levels, do: @levels

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(entries: [], streaming: false, level: :info, dropped: 0)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{log_entry: entry}, socket) do
    {:ok, append(socket, entry)}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("system_log_toggle", _params, socket) do
    if AdminOps.admin?(socket) do
      {:noreply, toggle(socket)}
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  def handle_event("system_log_clear", _params, socket) do
    {:noreply, assign(socket, entries: [], dropped: 0)}
  end

  def handle_event("system_log_level", %{"level" => level}, socket) do
    {:noreply, assign(socket, level: parse_level(level, socket.assigns.level))}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.log_panel
        id={@id}
        entries={@entries}
        streaming={@streaming}
        level={@level}
        levels={levels()}
        dropped={@dropped}
        primary_level={Handler.primary_level()}
        reachable={Handler.reachable?(@level)}
        target={@myself}
        on_toggle="system_log_toggle"
        on_clear="system_log_clear"
        on_level="system_log_level"
      />
    </div>
    """
  end

  defp toggle(%{assigns: %{streaming: true}} = socket) do
    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, Handler.topic())
    Handler.remove()

    assign(socket, streaming: false)
  end

  defp toggle(socket) do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Handler.topic())
    Handler.install(socket.assigns.level)

    assign(socket, streaming: true)
  end

  # Entries below the chosen level still arrive while the handler is installed
  # at a lower one, so the level is enforced on the way in as well.
  defp append(socket, entry) do
    if Logger.compare_levels(entry.level, socket.assigns.level) == :lt do
      socket
    else
      keep(socket, entry)
    end
  end

  defp keep(socket, entry) do
    entries = socket.assigns.entries ++ [entry]
    overflow = length(entries) - @buffer

    if overflow > 0 do
      assign(socket,
        entries: Enum.drop(entries, overflow),
        dropped: socket.assigns.dropped + overflow
      )
    else
      assign(socket, entries: entries)
    end
  end

  # The level arrives from a select in the DOM and is matched against the known
  # set rather than converted, so no string from the client becomes an atom.
  defp parse_level(value, fallback) do
    Enum.find(@levels, fallback, &(Atom.to_string(&1) == value))
  end
end
