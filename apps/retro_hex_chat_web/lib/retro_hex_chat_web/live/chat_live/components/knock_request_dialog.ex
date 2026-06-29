defmodule RetroHexChatWeb.ChatLive.Components.KnockRequestDialog do
  @moduledoc """
  The knock-request dialog. Owns the draft — channel, message and error. The
  parent keeps `show_knock_request_dialog` because the Escape-dismissal map reads
  it; this component receives that as `visible`.

  `ChannelListEvents` drives it via `send_update/2`:

  - `{:open, channel}`        — open for `channel`, clear the draft
  - `{:change, message}`      — track the typed message
  - `{:error, message, err}`  — re-show with the typed message + error
  - `:close`                  — clear the draft

  Submit is handled on the parent, where the session and the `Server` knock call
  are reachable.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.KnockRequestDialog

  @id "knock-request-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, visible: false, channel: nil, message: "", error: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: action} = assigns, socket) do
    {:ok, socket |> assign_visible(assigns) |> dispatch(action)}
  end

  def update(assigns, socket), do: {:ok, assign_visible(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.knock_request_dialog
        id={@id}
        show={@visible}
        channel={@channel}
        message={@message}
        error={@error}
        on_change="knock_request_change"
        on_submit="knock_request_submit"
        on_cancel="knock_request_cancel"
      />
    </div>
    """
  end

  @spec assign_visible(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_visible(socket, assigns) do
    assign(socket, visible: Map.get(assigns, :visible, socket.assigns.visible))
  end

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, {:open, channel}),
    do: assign(socket, channel: channel, message: "", error: nil)

  defp dispatch(socket, {:change, message}), do: assign(socket, message: message, error: nil)

  defp dispatch(socket, {:error, message, error}),
    do: assign(socket, message: message, error: error)

  defp dispatch(socket, :close), do: assign(socket, channel: nil, message: "", error: nil)
  defp dispatch(socket, _unknown), do: socket
end
