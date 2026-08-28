defmodule RetroHexChatWeb.ChatLive.GroupCallEvents do
  @moduledoc """
  The chat's side of a conference it no longer hosts.

  Being in a call moved out — `RetroHexChatWeb.App.CallLive` owns the media,
  the layout, the moderation and the recovery, whether it is rendered in the
  chat's Group Call window or in a tab of its own. What is left here is
  everything the chat itself is responsible for and the call cannot be:

    * **which channel.** "Call" is a button on a conversation, so the chat is
      what knows which conversation you are looking at, and what refuses when
      it is a private one.
    * **the window.** The chat's window manager owns opening, focusing and the
      X, so the controls that mean those still arrive here and are handed on.
    * **swapping one call for another.** Only the chat can be in the position
      of already having a call open and being asked for a different channel's.
    * **saying what happened.** A refusal belongs in the conversation, which is
      where every other refusal in this product appears. The surface sends the
      sentence; this puts it where the person is reading.

  What the chat keeps about the call itself is only what its own chrome draws —
  which channel, what state, who is in it — and the surface hands it over as it
  changes. The taskbar button and the status-bar zone are read-models of a call
  this process does not own.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.GroupCall
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.GroupCallReadModel
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Windows
  alias RetroHexChatWeb.Live.GroupCallConfirmDialog

  @window_id "group-call"
  @confirm_id "group-call-switch-dialog"

  @type event_result :: {:cont | :halt, Socket.t()}

  @doc """
  The id the chat renders its confirmation under.

  Distinct from the call surface's on purpose: both are in the document at the
  same time whenever the call is embedded, and the only question the chat ever
  asks is the one the call cannot — whether to swap it for another channel's.
  """
  @spec confirm_dialog_id() :: String.t()
  def confirm_dialog_id, do: @confirm_id

  @doc """
  Rebuild what the chat knows about calls, after a mount or a reconnect.

  Two readers, in this order: every channel gets its badge back, and then — if
  this person is still an active participant in one of those rooms — the call
  surface reopens onto it. The room server owns that fact, so a reload does not
  end a call and must not look like it did.
  """
  @spec rehydrate(Socket.t()) :: Socket.t()
  def rehydrate(
        %{assigns: %{session: %{nickname: nickname, channels: channels, identified: true}}} =
          socket
      )
      when is_binary(nickname) and is_list(channels) do
    socket
    |> GroupCallReadModel.refresh_all()
    |> maybe_reopen_surface(nickname)
  end

  def rehydrate(socket), do: socket

  @doc """
  End the call surface when the channel behind it leaves the session.

  A kick or a `/part` is not a window being closed: the call has lost the
  membership it stood on, so it ends rather than lingering.
  """
  @spec leave_channel_call(Socket.t(), String.t(), String.t()) :: Socket.t()
  def leave_channel_call(
        %{assigns: %{group_call: %{channel_name: channel_name}}} = socket,
        channel_name,
        reason
      ) do
    command(socket, {:leave, reason})
  end

  def leave_channel_call(socket, _channel_name, _reason), do: socket

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  def handle_event("group_call_open", _params, socket) do
    {:halt, open_or_switch(socket)}
  end

  def handle_event("group_call_statusbar_click", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, Windows.open(socket, @window_id)}
  end

  def handle_event("group_call_statusbar_click", _params, socket), do: {:halt, socket}

  # The stop button and the window's X belong to the chat's chrome; what they
  # mean belongs to the call, which is the only process that knows whether the
  # answer is a confirmation or simply closing an antechamber nobody entered.
  def handle_event("group_call_statusbar_stop", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, command(socket, {:event, "group_call_leave"})}
  end

  def handle_event("group_call_statusbar_stop", _params, socket), do: {:halt, socket}

  def handle_event("group_call_window_close", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, command(socket, {:event, "group_call_window_close"})}
  end

  def handle_event("group_call_window_close", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_confirm_switch",
        _params,
        %{assigns: %{group_call: %{}, group_call_pending: %{channel_name: _, user_id: _}}} =
          socket
      ) do
    close_confirm()
    {:halt, command(socket, {:leave, "switch"})}
  end

  def handle_event("group_call_confirm_switch", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event("group_call_confirm_cancel", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Hand a chat-owned control to the call it means.

  The conference keyboard shortcuts are bound on the chat's window, because
  that is where the keystroke lands, and the call is what they act on.
  """
  @spec forward(Socket.t(), String.t()) :: Socket.t()
  def forward(socket, event), do: command(socket, {:event, event})

  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_info({:call_surface_state, pid, snapshot}, socket) when is_map(snapshot) do
    call =
      (socket.assigns[:group_call] || %{})
      |> Map.merge(snapshot)
      |> Map.put(:pid, pid)

    {:halt, assign(socket, group_call: call)}
  end

  def handle_info({:call_surface_state, _pid, nil}, socket), do: {:halt, socket}

  def handle_info({:call_surface_notice, :error, message}, socket) do
    {:halt, Messages.error_event(socket, message)}
  end

  def handle_info({:call_surface_notice, :system, message}, socket) do
    {:halt, Messages.system_event(socket, message)}
  end

  def handle_info(:call_surface_focus, socket) do
    {:halt, Windows.open(socket, @window_id)}
  end

  # The surface is gone. If the reason it went was a swap, the channel that was
  # waiting for it is opened now and not a moment earlier — opening before the
  # old call had actually left would race the two.
  def handle_info(:call_surface_closed, socket) do
    socket =
      socket
      |> assign(group_call: nil)
      |> Phoenix.LiveView.push_event("window_command", %{action: "close", id: @window_id})

    case socket.assigns[:group_call_pending] do
      %{channel_name: channel_name, user_id: user_id} ->
        {:halt,
         socket
         |> assign(group_call_pending: nil)
         |> open_surface(channel_name, user_id)}

      _none ->
        {:halt, socket}
    end
  end

  def handle_info(_message, socket), do: {:cont, socket}

  defp open_or_switch(socket) do
    with {:ok, channel_name} <- active_channel(socket),
         :ok <- require_identified(socket),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(socket.assigns.session.nickname) do
      case socket.assigns[:group_call] do
        %{channel_name: ^channel_name} -> Windows.open(socket, @window_id)
        %{channel_name: current} -> open_switch_confirm(socket, current, channel_name, user_id)
        _none -> open_surface(socket, channel_name, user_id)
      end
    else
      {:redirect, nil} ->
        Messages.error_event(
          socket,
          dgettext("group_call", "You must be registered with NickServ to use group calls.")
        )

      {:error, message} ->
        Messages.error_event(socket, message)
    end
  end

  # The surface starts in its antechamber, which is why the snapshot the chat's
  # chrome reads exists before anyone has joined anything.
  defp open_surface(socket, channel_name, user_id) do
    socket
    |> assign(
      group_call: %{
        channel_name: channel_name,
        user_id: user_id,
        status: :prejoin,
        participants: [],
        tracks: [],
        pid: nil
      }
    )
    |> Windows.open(@window_id)
  end

  defp open_switch_confirm(socket, current_channel, target_channel, user_id) do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: @confirm_id,
      action: {:open_switch, current_channel, target_channel}
    )

    assign(socket, group_call_pending: %{channel_name: target_channel, user_id: user_id})
  end

  defp close_confirm do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: @confirm_id,
      action: :close
    )
  end

  defp command(%{assigns: %{group_call: %{pid: pid}}} = socket, message) when is_pid(pid) do
    send(pid, {:call_surface_command, message})
    socket
  end

  defp command(socket, _message), do: socket

  defp maybe_reopen_surface(%{assigns: %{group_call: %{}}} = socket, _nickname), do: socket

  defp maybe_reopen_surface(socket, nickname) do
    case rejoinable_channel(socket, nickname) do
      {channel_name, user_id} -> open_surface(socket, channel_name, user_id)
      nil -> socket
    end
  end

  defp rejoinable_channel(socket, nickname) do
    socket
    |> GroupCallReadModel.live_summaries()
    |> Enum.find_value(fn {channel_name, summary} ->
      with room_id when is_integer(room_id) <- summary.room.id,
           %{registered_nick_id: user_id} when is_integer(user_id) <-
             GroupCall.active_participant(room_id, nickname) do
        {channel_name, user_id}
      else
        _other -> nil
      end
    end)
  end

  defp active_channel(%{assigns: %{show_status_tab: true}}),
    do: {:error, dgettext("group_call", "Open a channel before starting a group call.")}

  defp active_channel(%{assigns: %{session: %{active_pm: pm}}}) when is_binary(pm),
    do: {:error, dgettext("group_call", "Group calls are available in channels only.")}

  defp active_channel(%{assigns: %{session: %{active_channel: channel}}})
       when is_binary(channel) and channel != "",
       do: {:ok, channel}

  defp active_channel(_socket),
    do: {:error, dgettext("group_call", "Open a channel before starting a group call.")}

  defp require_identified(%{assigns: %{session: %{identified: true}}}), do: :ok

  defp require_identified(_socket),
    do:
      {:error, dgettext("group_call", "You must be identified with NickServ to use group calls.")}
end
