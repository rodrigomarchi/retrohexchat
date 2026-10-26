defmodule RetroHexChatWeb.Live.GroupCallConfirmDialog do
  @moduledoc """
  The confirmation in front of every irreversible thing a conference can do.

  The call surface renders it, and it asks before you leave, end the room,
  remove someone or mute everybody. `send_update/2` reaches the process that
  rendered it, so a second renderer elsewhere would work the same way.

  It is scoped to the window it is rendered inside, so a confirmation blocks
  the call and nothing else.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.GroupCallConfirmDialog

  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  use RetroHexChatWeb.ChatLive.Components.DialogIsland, id: "group-call-confirm-dialog"

  @open_modes %{
    open_leave: :leave,
    open_end_call: :end_call,
    open_mute_all: :mute_all,
    open_camera_off_all: :camera_off_all
  }

  @doc """
  The id the call surface renders it under, and addresses `send_update/2` to.

  Anything rendering a second copy in the same document passes an id of its
  own: two elements with the same id is undefined behaviour.
  """
  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       scope: :viewport,
       show: false,
       mode: :leave,
       channel: nil,
       target_nickname: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {action, channel}}, socket)
      when action in [:open_leave, :open_end_call, :open_mute_all, :open_camera_off_all] do
    {:ok, open(socket, @open_modes[action], channel)}
  end

  def update(
        %{action: {:open_kick_participant, channel, _participant_id, target_nickname}},
        socket
      ) do
    {:ok, open(socket, :kick_participant, channel, target_nickname)}
  end

  def update(assigns, socket), do: DialogIsland.scoped_update(assigns, socket)

  defp open(socket, mode, channel, target_nickname \\ nil) do
    assign(socket, show: true, mode: mode, channel: channel, target_nickname: target_nickname)
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.group_call_confirm_dialog
        id={@id}
        scope={@scope}
        show={@show}
        mode={@mode}
        channel={@channel}
        target_nickname={@target_nickname}
        on_confirm={
          case @mode do
            :end_call -> "group_call_confirm_end_call"
            :kick_participant -> "group_call_confirm_kick_participant"
            :mute_all -> "group_call_confirm_mute_all"
            :camera_off_all -> "group_call_confirm_camera_off_all"
            _mode -> "group_call_confirm_leave"
          end
        }
        on_cancel="group_call_confirm_cancel"
      />
    </div>
    """
  end
end
