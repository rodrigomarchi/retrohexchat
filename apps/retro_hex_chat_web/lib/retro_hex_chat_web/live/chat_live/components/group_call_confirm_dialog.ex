defmodule RetroHexChatWeb.ChatLive.Components.GroupCallConfirmDialog do
  @moduledoc """
  Group-call leave/switch confirmation dialog.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.GroupCallConfirmDialog

  @id "group-call-confirm-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, show: false, mode: :leave, channel: nil, new_channel: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open_leave, channel}}, socket) do
    {:ok, assign(socket, show: true, mode: :leave, channel: channel, new_channel: nil)}
  end

  def update(%{action: {:open_close, channel}}, socket) do
    {:ok, assign(socket, show: true, mode: :close, channel: channel, new_channel: nil)}
  end

  def update(%{action: {:open_switch, channel, new_channel}}, socket) do
    {:ok, assign(socket, show: true, mode: :switch, channel: channel, new_channel: new_channel)}
  end

  def update(%{action: {:open_end_call, channel}}, socket) do
    {:ok, assign(socket, show: true, mode: :end_call, channel: channel, new_channel: nil)}
  end

  def update(%{action: :close}, socket), do: {:ok, assign(socket, show: false)}
  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.group_call_confirm_dialog
        id={@id}
        show={@show}
        mode={@mode}
        channel={@channel}
        new_channel={@new_channel}
        on_confirm={
          case @mode do
            :switch -> "group_call_confirm_switch"
            :end_call -> "group_call_confirm_end_call"
            _mode -> "group_call_confirm_leave"
          end
        }
        on_cancel="group_call_confirm_cancel"
      />
    </div>
    """
  end
end
