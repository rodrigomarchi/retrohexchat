defmodule RetroHexChatWeb.ChatLive.Components.InviteChannelPickerDialog do
  @moduledoc """
  The invite-channel-picker dialog. Owns the draft — target nick, selected
  channel and error. The parent keeps `show_invite_channel_picker` (read by the
  Escape-dismissal map) and passes it in as `visible`; the joined `channels` list
  is supplied by the parent.

  `ContextMenuEvents` drives it via `send_update/2`:

  - `{:open, target, selected}`        — open for `target`, default selection
  - `{:error, target, selected, err}`  — re-show with an error
  - `:close`                           — clear the draft

  The form submit is handled on the parent, where `Invite.send_invite` is
  reachable.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.InviteChannelPickerDialog

  @id "invite-channel-picker-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       visible: false,
       channels: [],
       target_nick: nil,
       selected_channel: nil,
       error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: action} = assigns, socket) do
    {:ok, socket |> assign_passthrough(assigns) |> dispatch(action)}
  end

  def update(assigns, socket), do: {:ok, assign_passthrough(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.invite_channel_picker_dialog
        id={@id}
        show={@visible}
        target_nick={@target_nick}
        channels={@channels}
        selected_channel={@selected_channel}
        error={@error}
        on_submit="invite_channel_picker_submit"
        on_cancel="invite_channel_picker_cancel"
      />
    </div>
    """
  end

  @spec assign_passthrough(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_passthrough(socket, assigns) do
    assign(socket,
      visible: Map.get(assigns, :visible, socket.assigns.visible),
      channels: Map.get(assigns, :channels, socket.assigns.channels)
    )
  end

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, {:open, target, selected}),
    do: assign(socket, target_nick: target, selected_channel: selected, error: nil)

  defp dispatch(socket, {:error, target, selected, error}),
    do: assign(socket, target_nick: target, selected_channel: selected, error: error)

  defp dispatch(socket, :close),
    do: assign(socket, target_nick: nil, selected_channel: nil, error: nil)

  defp dispatch(socket, _unknown), do: socket
end
