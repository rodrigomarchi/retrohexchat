defmodule RetroHexChatWeb.ChatLive.Components.PasteConfirmDialog do
  @moduledoc """
  The multi-line paste confirmation dialog. Not Escape-managed — the component
  owns the pasted `lines` and derives its own visibility (shown while `lines` is
  present).

  The clipboard JS hook pushes `paste_lines` to the parent (a global hook), so the
  parent forwards the filtered lines via `send_update` ({:set, lines, flood,
  disabled}). Send/Cancel are component-local: Cancel clears the lines; Send
  schedules the paced replay with `Process.send_after(self(), {:paste_next, lines})`
  (self() is the parent LiveView, whose `TimerHandlers` drives `:paste_next`) and
  then clears.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.PasteConfirmDialog

  @id "paste-confirm-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, lines: nil, flood_warning: false, send_disabled: false)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:set, lines, flood_warning, send_disabled}}, socket) do
    {:ok,
     assign(socket, lines: lines, flood_warning: flood_warning, send_disabled: send_disabled)}
  end

  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("paste_send", _params, socket) do
    Process.send_after(self(), {:paste_next, socket.assigns.lines || []}, 0)
    {:noreply, clear(socket)}
  end

  def handle_event("paste_cancel", _params, socket) do
    {:noreply, socket |> clear() |> push_event("focus_input", %{})}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.paste_confirm_dialog
        id={@id}
        show={@lines != nil}
        line_count={if @lines, do: length(@lines), else: 0}
        flood_warning={@flood_warning}
        send_disabled={@send_disabled}
        on_send={JS.push("paste_send", target: @myself)}
        on_cancel={JS.push("paste_cancel", target: @myself)}
      />
    </div>
    """
  end

  @spec clear(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp clear(socket), do: assign(socket, lines: nil, flood_warning: false, send_disabled: false)
end
