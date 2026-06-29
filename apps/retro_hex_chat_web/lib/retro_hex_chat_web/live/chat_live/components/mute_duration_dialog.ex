defmodule RetroHexChatWeb.ChatLive.Components.MuteDurationDialog do
  @moduledoc """
  The mute-duration dialog. Owns its open state and target nick.

  `ContextMenuEvents` drives it via `send_update/2`:

  - `{:open, nick}` — show the dialog for `nick`
  - `:close`        — hide and clear the target

  The submit/cancel events (`mute_duration_submit`/`mute_duration_cancel`) are
  handled on the parent (`ContextMenuEvents`), where the session and the `Server`
  mute call are reachable; the parent forwards a `:close` back here when done.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.MuteDurationDialog

  @id "mute-duration-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    # `id` is constant for this singleton dialog; assign it here so action-only
    # `send_update`s (which match the first update clause) never drop it.
    {:ok, assign(socket, id: @id, show: false, target_nick: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: action}, socket), do: {:ok, dispatch(socket, action)}
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.mute_duration_dialog
        id={@id}
        show={@show}
        target_nick={@target_nick}
        on_submit="mute_duration_submit"
        on_cancel="mute_duration_cancel"
      />
    </div>
    """
  end

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, {:open, nick}), do: assign(socket, show: true, target_nick: nick)
  defp dispatch(socket, :close), do: assign(socket, show: false, target_nick: nil)
  defp dispatch(socket, _unknown), do: socket
end
