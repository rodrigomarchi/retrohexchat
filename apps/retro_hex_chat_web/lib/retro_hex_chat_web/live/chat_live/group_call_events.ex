defmodule RetroHexChatWeb.ChatLive.GroupCallEvents do
  @moduledoc """
  Host-side adapter for channel-scoped group calls inside ChatLive.

  ChatLive owns only the UI/session state. The raw Phoenix Channel remains the
  signaling path for SDP/ICE, while the browser hook mirrors lightweight call
  state back here so the desktop window can render participants and controls.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Components.GroupCallConfirmDialog
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Windows

  @window_id "group-call"
  @layout_modes ~w(auto grid focus sidebar)
  @self_view_cycle [:tile, :pip, :hidden]

  @type event_result :: {:cont | :halt, Socket.t()}

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  def handle_event("group_call_open", _params, socket) do
    {:halt, open_or_join(socket)}
  end

  def handle_event("group_call_leave", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, open_confirm(socket, :leave)}
  end

  def handle_event("group_call_leave", _params, socket), do: {:halt, socket}

  def handle_event("group_call_window_close", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, open_confirm(socket, :close)}
  end

  def handle_event("group_call_window_close", _params, socket), do: {:halt, socket}

  def handle_event("group_call_statusbar_click", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, Windows.open(socket, @window_id)}
  end

  def handle_event("group_call_statusbar_click", _params, socket), do: {:halt, socket}

  def handle_event("group_call_statusbar_stop", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, open_confirm(socket, :leave)}
  end

  def handle_event("group_call_statusbar_stop", _params, socket), do: {:halt, socket}

  def handle_event("group_call_close_room", _params, %{assigns: %{group_call: %{}}} = socket) do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {:open_end_call, socket.assigns.group_call.channel_name}
    )

    {:halt, socket}
  end

  def handle_event("group_call_close_room", _params, socket), do: {:halt, socket}

  def handle_event("group_call_confirm_leave", _params, %{assigns: %{group_call: %{}}} = socket) do
    close_confirm()
    {:halt, end_current_call(socket, "left")}
  end

  def handle_event("group_call_confirm_leave", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event(
        "group_call_confirm_switch",
        _params,
        %{assigns: %{group_call: %{}, group_call_pending: %{}}} = socket
      ) do
    close_confirm()
    pending = socket.assigns.group_call_pending

    socket =
      socket
      |> end_current_call("switch")
      |> assign(group_call_pending: nil)

    {:halt, join_channel_call(socket, pending.channel_name, pending.user_id)}
  end

  def handle_event("group_call_confirm_switch", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event("group_call_confirm_cancel", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event(
        "group_call_confirm_end_call",
        _params,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    close_confirm()
    {:halt, close_room(socket)}
  end

  def handle_event("group_call_confirm_end_call", _params, socket) do
    close_confirm()
    {:halt, socket}
  end

  def handle_event("group_call_toggle_audio", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_media(socket, :audio)}
  end

  def handle_event("group_call_toggle_video", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_media(socket, :video)}
  end

  def handle_event(
        "group_call_layout_mode",
        %{"mode" => mode},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, set_layout_mode(socket, mode)}
  end

  def handle_event("group_call_layout_mode", _params, socket), do: {:halt, socket}

  def handle_event("group_call_toggle_sidebar", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_sidebar(socket)}
  end

  def handle_event("group_call_toggle_sidebar", _params, socket), do: {:halt, socket}

  def handle_event("group_call_cycle_self_view", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, cycle_self_view(socket)}
  end

  def handle_event("group_call_cycle_self_view", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_focus_participant",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, focus_participant(socket, participant_id)}
  end

  def handle_event("group_call_focus_participant", _params, socket), do: {:halt, socket}

  def handle_event("group_call_clear_focus", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, clear_focus(socket)}
  end

  def handle_event("group_call_clear_focus", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_moderate_audio",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, moderate_audio(socket, participant_id)}
  end

  def handle_event(
        "group_call_kick_participant",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, kick_participant(socket, participant_id)}
  end

  def handle_event("group_call_webrtc_ready", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, push_group_call_layout(socket)}
  end

  def handle_event("group_call_webrtc_ready", _params, socket), do: {:halt, socket}

  def handle_event("group_call_client_joined", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant = normalize_participant(value(payload, :participant))

    call =
      socket.assigns.group_call
      |> Map.put(:status, :connecting)
      |> Map.put(:participant_id, participant.id)
      |> merge_summary(payload)
      |> put_participant(participant)

    {:halt, socket |> assign(group_call: call) |> push_group_call_layout()}
  end

  def handle_event("group_call_offer_received", _payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, update_call(socket, &Map.put(&1, :status, :negotiating))}
  end

  def handle_event("group_call_peer_joined", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant = normalize_participant(value(payload, :participant))

    call =
      socket.assigns.group_call
      |> put_participant(participant)
      |> maybe_mark_connected(participant)

    {:halt, socket |> assign(group_call: call) |> push_group_call_layout()}
  end

  def handle_event("group_call_peer_left", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant_id = value(payload, :participant_id)
    call = socket.assigns.group_call

    if participant_id == call.participant_id do
      {:halt,
       socket
       |> assign(group_call: nil, group_call_pending: nil)
       |> push_event("window_command", %{action: "close", id: @window_id})}
    else
      {:halt,
       socket |> update_call(&remove_participant(&1, participant_id)) |> push_group_call_layout()}
    end
  end

  def handle_event("group_call_media_state", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant = normalize_participant(value(payload, :participant))
    {:halt, socket |> update_call(&put_participant(&1, participant)) |> push_group_call_layout()}
  end

  def handle_event(
        "group_call_media_state_forced",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    media = normalize_media(payload)

    {:halt,
     update_call(socket, fn call ->
       call
       |> Map.put(:media, media)
       |> update_self_media(media)
     end)
     |> push_group_call_layout()}
  end

  def handle_event("group_call_track_added", payload, %{assigns: %{group_call: %{}}} = socket) do
    track = normalize_track(value(payload, :track))
    {:halt, socket |> update_call(&put_track(&1, track)) |> push_group_call_layout()}
  end

  def handle_event("group_call_track_updated", payload, %{assigns: %{group_call: %{}}} = socket) do
    track = normalize_track(value(payload, :track))
    {:halt, socket |> update_call(&put_track(&1, track)) |> push_group_call_layout()}
  end

  def handle_event("group_call_track_removed", payload, %{assigns: %{group_call: %{}}} = socket) do
    track_id = value(payload, :track_id)
    {:halt, socket |> update_call(&remove_track(&1, track_id)) |> push_group_call_layout()}
  end

  def handle_event("group_call_closed", payload, %{assigns: %{group_call: %{}}} = socket) do
    message =
      case value(payload, :reason) do
        nil -> dgettext("group_call", "Group call ended.")
        reason -> dgettext("group_call", "Group call ended: %{reason}", reason: reason)
      end

    socket =
      socket
      |> assign(group_call: nil, group_call_pending: nil)
      |> push_event("window_command", %{action: "close", id: @window_id})

    {:halt, Messages.system_event(socket, message)}
  end

  def handle_event(
        "group_call_connection_state",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    state = value(payload, :state)
    {:halt, apply_connection_state(socket, state)}
  end

  def handle_event("group_call_client_warning", payload, %{assigns: %{group_call: %{}}} = socket) do
    message = value(payload, :message) || dgettext("group_call", "Group call media is degraded.")

    socket =
      update_call(socket, fn call ->
        call
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)
      end)

    {:halt, Messages.system_event(socket, message)}
  end

  def handle_event("group_call_client_error", payload, %{assigns: %{group_call: %{}}} = socket) do
    message = value(payload, :message) || dgettext("group_call", "Group call connection failed.")

    socket =
      update_call(socket, fn call ->
        call
        |> Map.put(:status, :error)
        |> Map.put(:error, message)
        |> Map.put(:warning, nil)
      end)

    {:halt, Messages.error_event(socket, message)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp open_or_join(socket) do
    with {:ok, channel_name} <- active_channel(socket),
         :ok <- require_identified(socket),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(socket.assigns.session.nickname) do
      call = socket.assigns.group_call

      cond do
        call && call.channel_name == channel_name ->
          Windows.open(socket, @window_id)

        call ->
          open_switch_confirm(socket, call.channel_name, channel_name, user_id)

        true ->
          join_channel_call(socket, channel_name, user_id)
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

  defp join_channel_call(socket, channel_name, user_id) do
    actor = %{user_id: user_id, nickname: socket.assigns.session.nickname}

    with {:ok, %{room: _room, token: token}} <- get_or_create_room(channel_name, actor),
         {:ok, _pid} <- GroupCall.ensure_room_server(token),
         {:ok, summary} <- GroupCall.get_summary(token) do
      join_token = JoinToken.sign(token, channel_name, user_id, actor.nickname)

      call =
        summary
        |> new_call(token, channel_name, user_id, actor.nickname, join_token)
        |> Map.put(:status, :joining)

      socket
      |> assign(group_call: call)
      |> Windows.open(@window_id)
    else
      {:error, message} when is_binary(message) -> Messages.error_event(socket, message)
      {:error, reason} -> Messages.error_event(socket, inspect(reason))
    end
  end

  defp open_switch_confirm(socket, current_channel, target_channel, user_id) do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {:open_switch, current_channel, target_channel}
    )

    assign(socket,
      group_call_pending: %{channel_name: target_channel, user_id: user_id}
    )
  end

  defp open_confirm(socket, mode) when mode in [:leave, :close] do
    action =
      case mode do
        :leave -> :open_leave
        :close -> :open_close
      end

    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {action, socket.assigns.group_call.channel_name}
    )

    socket
  end

  defp close_confirm do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: :close
    )
  end

  defp end_current_call(%{assigns: %{group_call: call}} = socket, reason) when is_map(call) do
    if is_integer(call.participant_id) do
      _ = GroupCall.leave_call(call.token, call.participant_id, reason)
    end

    socket
    |> assign(group_call: nil, group_call_pending: nil)
    |> push_event("window_command", %{action: "close", id: @window_id})
  end

  defp get_or_create_room(channel_name, actor) do
    case GroupCall.active_room_for_channel(channel_name) do
      nil -> GroupCall.create_channel_call(channel_name, actor)
      room -> {:ok, %{room: room, token: room.token}}
    end
  end

  defp new_call(summary, token, channel_name, user_id, nickname, join_token) do
    %{
      token: token,
      room: normalize_room(value(summary, :room)),
      channel_name: channel_name,
      user_id: user_id,
      nickname: nickname,
      join_token: join_token,
      participant_id: nil,
      status: :joining,
      connection_state: nil,
      participants: normalize_participants(value(summary, :participants)),
      pending_participants: normalize_participants(value(summary, :pending_participants)),
      tracks: normalize_tracks(value(summary, :tracks)),
      media: %{audio: true, video: true},
      layout: default_layout(),
      error: nil,
      warning: nil
    }
  end

  defp apply_connection_state(socket, state) do
    case to_string(state) do
      "connected" ->
        update_call(socket, fn call ->
          call
          |> Map.put(:connection_state, state)
          |> Map.put(:status, :connected)
          |> Map.put(:warning, nil)
          |> Map.put(:error, nil)
        end)

      "disconnected" ->
        message =
          dgettext("group_call", "Group call media connection interrupted. Trying to recover.")

        update_call(socket, fn call ->
          call
          |> Map.put(:connection_state, state)
          |> Map.put(:warning, message)
        end)

      "failed" ->
        message =
          dgettext(
            "group_call",
            "Group call media connection failed. Leave and rejoin the call to retry."
          )

        socket =
          update_call(socket, fn call ->
            call
            |> Map.put(:connection_state, state)
            |> Map.put(:status, :error)
            |> Map.put(:error, message)
            |> Map.put(:warning, nil)
          end)

        Messages.error_event(socket, message)

      _other ->
        update_call(socket, &Map.put(&1, :connection_state, state))
    end
  end

  defp toggle_media(socket, kind) do
    call = socket.assigns.group_call
    media = Map.update(call.media, kind, false, &(!&1))
    call = %{call | media: media} |> update_self_media(media)

    socket
    |> assign(group_call: call)
    |> push_event("group_call_set_media_state", media)
    |> push_group_call_layout()
  end

  defp set_layout_mode(socket, mode) when mode in @layout_modes do
    update_call(socket, fn call ->
      layout =
        call
        |> layout()
        |> Map.put(:mode, String.to_existing_atom(mode))
        |> maybe_open_sidebar_for_mode()
        |> maybe_focus_for_mode(call)

      %{call | layout: layout}
    end)
    |> push_group_call_layout()
  end

  defp set_layout_mode(socket, _mode), do: socket

  defp toggle_sidebar(socket) do
    update_call(socket, fn call ->
      layout = layout(call)
      sidebar_open = !Map.get(layout, :sidebar_open, true)

      layout =
        layout
        |> Map.put(:sidebar_open, sidebar_open)
        |> then(fn layout ->
          if sidebar_open do
            layout
          else
            Map.put(layout, :mode, :auto)
          end
        end)

      %{call | layout: layout}
    end)
    |> push_group_call_layout()
  end

  defp cycle_self_view(socket) do
    update_call(socket, fn call ->
      current = Map.get(layout(call), :self_view, :tile)
      next = next_self_view(current)

      %{call | layout: Map.put(layout(call), :self_view, next)}
    end)
    |> push_group_call_layout()
  end

  defp focus_participant(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         true <- participant_id in Enum.map(socket.assigns.group_call.participants, & &1.id) do
      update_call(socket, fn call ->
        layout =
          call
          |> layout()
          |> Map.put(:mode, :focus)
          |> Map.put(:focused_participant_id, participant_id)

        %{call | layout: layout}
      end)
      |> push_group_call_layout()
    else
      _error -> socket
    end
  end

  defp clear_focus(socket) do
    update_call(socket, fn call ->
      layout =
        call
        |> layout()
        |> Map.put(:mode, :auto)
        |> Map.put(:focused_participant_id, nil)

      %{call | layout: layout}
    end)
    |> push_group_call_layout()
  end

  defp update_self_media(%{participant_id: nil} = call, _media), do: call

  defp update_self_media(call, media) do
    update_in(call.participants, fn participants ->
      Enum.map(participants, fn
        %{id: id} = participant when id == call.participant_id ->
          %{participant | media_state: media}

        participant ->
          participant
      end)
    end)
  end

  defp update_call(socket, fun) do
    assign(socket, group_call: fun.(socket.assigns.group_call))
  end

  defp push_group_call_layout(%{assigns: %{group_call: call}} = socket) when is_map(call) do
    push_event(socket, "group_call_layout_state", group_call_layout_payload(call))
  end

  defp push_group_call_layout(socket), do: socket

  defp moderate_audio(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         {:ok, participant} <- set_target_audio(socket.assigns.group_call, actor, target) do
      update_call(socket, &put_participant(&1, normalize_participant(participant)))
    else
      {:error, message} when is_binary(message) ->
        Messages.error_event(socket, message)

      _error ->
        Messages.error_event(
          socket,
          dgettext("group_call", "Could not update participant media.")
        )
    end
  end

  defp kick_participant(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, _target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         :ok <- GroupCall.kick_participant(socket.assigns.group_call.token, actor, participant_id) do
      update_call(socket, &remove_participant(&1, participant_id))
    else
      {:error, message} when is_binary(message) ->
        Messages.error_event(socket, message)

      _error ->
        Messages.error_event(socket, dgettext("group_call", "Could not remove participant."))
    end
  end

  defp close_room(socket) do
    with {:ok, actor} <- actor(socket),
         :ok <- GroupCall.close_call(socket.assigns.group_call.token, actor, "moderation") do
      socket
      |> assign(group_call: nil, group_call_pending: nil)
      |> push_event("window_command", %{action: "close", id: @window_id})
    else
      {:error, message} when is_binary(message) -> Messages.error_event(socket, message)
      _error -> Messages.error_event(socket, dgettext("group_call", "Could not end group call."))
    end
  end

  defp set_target_audio(call, actor, target) do
    if participant_media?(target, :audio) do
      GroupCall.mute_participant(call.token, actor, target.id)
    else
      GroupCall.unmute_participant(call.token, actor, target.id)
    end
  end

  defp find_participant(call, participant_id) do
    case Enum.find(call.participants, &(&1.id == participant_id)) do
      nil -> {:error, dgettext("group_call", "Participant is no longer in the group call.")}
      participant -> {:ok, participant}
    end
  end

  defp participant_media?(%{media_state: media}, key) when is_map(media) do
    case Map.get(media, key) do
      nil -> true
      value -> value == true
    end
  end

  defp participant_media?(_participant, _key), do: true

  defp actor(socket) do
    case SessionHelpers.resolve_user_id(socket.assigns.session.nickname) do
      {:ok, user_id} ->
        {:ok, %{user_id: user_id, nickname: socket.assigns.session.nickname}}

      {:redirect, nil} ->
        {:error, dgettext("group_call", "You must be registered to moderate group calls.")}
    end
  end

  defp merge_summary(call, payload) do
    call
    |> Map.put(:room, normalize_room(value(payload, :room) || call.room))
    |> Map.put(:participants, normalize_participants(value(payload, :participants)))
  end

  defp maybe_mark_connected(call, %{id: id}) when id == call.participant_id do
    %{call | status: :connected}
  end

  defp maybe_mark_connected(call, _participant), do: call

  defp put_participant(call, %{id: nil}), do: call

  defp put_participant(call, participant) do
    participants =
      call.participants
      |> Enum.reject(&(&1.id == participant.id))
      |> Kernel.++([participant])
      |> Enum.sort_by(& &1.id)

    %{call | participants: participants}
  end

  defp remove_participant(call, participant_id) do
    call = %{call | participants: Enum.reject(call.participants, &(&1.id == participant_id))}

    if layout(call).focused_participant_id == participant_id do
      %{call | layout: %{layout(call) | focused_participant_id: nil, mode: :auto}}
    else
      call
    end
  end

  defp remove_track(call, track_id) do
    %{call | tracks: Enum.reject(call.tracks, &(&1.id == track_id))}
  end

  defp put_track(call, %{id: nil}), do: call

  defp put_track(call, track) do
    tracks =
      call.tracks
      |> Enum.reject(&(&1.id == track.id))
      |> Kernel.++([track])
      |> Enum.sort_by(& &1.id)

    %{call | tracks: tracks}
  end

  defp normalize_room(nil), do: nil

  defp normalize_room(room) when is_map(room) do
    %{
      id: value(room, :id),
      token: value(room, :token),
      channel_name: value(room, :channel_name),
      status: value(room, :status),
      max_participants: value(room, :max_participants)
    }
  end

  defp normalize_participants(nil), do: []
  defp normalize_participants(participants), do: Enum.map(participants, &normalize_participant/1)

  defp normalize_participant(nil) do
    %{id: nil, nickname: nil, status: nil, media_state: %{}, channel_role_snapshot: nil}
  end

  defp normalize_participant(participant) when is_map(participant) do
    %{
      id: value(participant, :id),
      nickname: value(participant, :nickname),
      status: value(participant, :status),
      media_state: normalize_media(value(participant, :media_state)),
      channel_role_snapshot: value(participant, :channel_role_snapshot)
    }
  end

  defp normalize_tracks(nil), do: []
  defp normalize_tracks(tracks), do: Enum.map(tracks, &normalize_track/1)

  defp normalize_track(nil) do
    %{id: nil, participant_id: nil, kind: nil, source: nil, status: nil}
  end

  defp normalize_track(track) when is_map(track) do
    %{
      id: value(track, :id),
      participant_id: value(track, :participant_id),
      kind: value(track, :kind),
      source: value(track, :source),
      status: value(track, :status),
      webrtc_track_id: value(track, :webrtc_track_id),
      stream_id: value(track, :stream_id)
    }
  end

  defp normalize_media(nil), do: %{}

  defp normalize_media(media) when is_map(media) do
    %{
      audio: media_value(media, :audio),
      video: media_value(media, :video)
    }
  end

  defp normalize_media(_media), do: %{}

  defp default_layout do
    %{
      mode: :auto,
      focused_participant_id: nil,
      sidebar_open: true,
      self_view: :tile
    }
  end

  defp layout(%{layout: layout}) when is_map(layout), do: Map.merge(default_layout(), layout)
  defp layout(_call), do: default_layout()

  defp maybe_open_sidebar_for_mode(%{mode: :sidebar} = layout), do: %{layout | sidebar_open: true}
  defp maybe_open_sidebar_for_mode(layout), do: layout

  defp maybe_focus_for_mode(%{mode: mode, focused_participant_id: nil} = layout, call)
       when mode in [:focus, :sidebar] do
    %{layout | focused_participant_id: default_focus_participant_id(call)}
  end

  defp maybe_focus_for_mode(layout, _call), do: layout

  defp default_focus_participant_id(call) do
    remote =
      call.participants
      |> Enum.reject(&(&1.id == call.participant_id))
      |> Enum.find(&participant_media?(&1, :video))

    (remote || List.first(call.participants) || %{})[:id]
  end

  defp next_self_view(current) do
    current_index = Enum.find_index(@self_view_cycle, &(&1 == current)) || 0
    Enum.at(@self_view_cycle, rem(current_index + 1, length(@self_view_cycle)))
  end

  defp group_call_layout_payload(call) do
    layout = layout(call)

    %{
      mode: Atom.to_string(layout.mode),
      focused_participant_id: layout.focused_participant_id,
      sidebar_open: layout.sidebar_open,
      self_view: Atom.to_string(layout.self_view),
      self_participant_id: call.participant_id,
      participants: Enum.map(call.participants || [], &participant_payload/1),
      tracks: Enum.map(call.tracks || [], &track_payload/1)
    }
  end

  defp participant_payload(participant) do
    %{
      id: participant.id,
      nickname: participant.nickname,
      status: participant.status,
      media_state: participant.media_state || %{},
      channel_role_snapshot: participant.channel_role_snapshot
    }
  end

  defp track_payload(track) do
    %{
      id: track.id,
      participant_id: track.participant_id,
      kind: track.kind,
      source: track.source,
      status: track.status,
      webrtc_track_id: track[:webrtc_track_id],
      stream_id: track[:stream_id]
    }
  end

  defp media_value(media, key) do
    case value(media, key) do
      nil -> nil
      "true" -> true
      "false" -> false
      value -> value
    end
  end

  defp value(nil, _key), do: nil

  defp value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end
end
