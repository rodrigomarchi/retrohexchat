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

  @id "group-call-confirm-dialog"

  @doc """
  The id the call surface renders it under, and addresses `send_update/2` to.

  Anything rendering a second copy in the same document passes an id of its
  own: two elements with the same id is undefined behaviour.
  """
  @spec id() :: String.t()
  def id, do: @id

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
  def update(%{action: {:open_leave, channel}}, socket) do
    {:ok,
     assign(socket,
       show: true,
       mode: :leave,
       channel: channel,
       target_nickname: nil
     )}
  end

  def update(%{action: {:open_close, channel}}, socket) do
    {:ok,
     assign(socket,
       show: true,
       mode: :close,
       channel: channel,
       target_nickname: nil
     )}
  end

  def update(%{action: {:open_end_call, channel}}, socket) do
    {:ok,
     assign(socket,
       show: true,
       mode: :end_call,
       channel: channel,
       target_nickname: nil
     )}
  end

  def update(
        %{action: {:open_kick_participant, channel, _participant_id, target_nickname}},
        socket
      ) do
    {:ok,
     assign(socket,
       show: true,
       mode: :kick_participant,
       channel: channel,
       target_nickname: target_nickname
     )}
  end

  def update(%{action: {:open_mute_all, channel}}, socket) do
    {:ok,
     assign(socket,
       show: true,
       mode: :mute_all,
       channel: channel,
       target_nickname: nil
     )}
  end

  def update(%{action: {:open_camera_off_all, channel}}, socket) do
    {:ok,
     assign(socket,
       show: true,
       mode: :camera_off_all,
       channel: channel,
       target_nickname: nil
     )}
  end

  def update(%{action: :close}, socket), do: {:ok, assign(socket, show: false)}

  # The host declares, on every render, whether the dialog blocks the whole
  # viewport or just the window it lives in. `send_update/2` carries actions;
  # this carries the shape of the host.
  def update(%{scope: scope} = assigns, socket) when scope in [:viewport, :window] do
    {:ok, assign(socket, id: assigns.id, scope: scope)}
  end

  def update(_assigns, socket), do: {:ok, socket}

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
