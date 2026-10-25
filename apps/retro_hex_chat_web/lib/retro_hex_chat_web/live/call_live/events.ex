defmodule RetroHexChatWeb.CallLive.Events do
  @moduledoc """
  Being inside a channel conference.

  Every event here presumes you are in the room, or about to walk into it: the
  media you are sending, the layout you are watching it in, who you are
  moderating, and the recovery a dropped connection goes through. The raw
  Phoenix Channel remains the signalling path for SDP and ICE; the browser hook
  mirrors lightweight state back here so the surface can draw participants and
  controls.

  Knowing that a call *exists* is not here — that is
  `RetroHexChatWeb.ChatLive.GroupCallReadModel`, and the chat reads it without
  any of this. The rule that split the two: if the datum only exists while you
  are in the call, it is in this module.

  A refusal is a sentence on this page's own status bar, and leaving is this
  page saying it is finished — both through `RetroHexChatWeb.Live.Surface`,
  which is what a screen with an address does to itself. There is no host to
  tell any more.

  This module routes the events and runs the joining; the work sits beside it
  under `RetroHexChatWeb.CallLive`: `Moderation`, `Roster` (who and what is in
  the call map), `Layout`, `Recovery` (connection state), `PrejoinPreferences`
  (the antechamber's remembered choices) and `CallAssign` (the assign and the
  layout push).
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.App.GroupCallStats
  alias RetroHexChatWeb.App.GroupCallSummary

  alias RetroHexChatWeb.CallLive.{
    CallAssign,
    Layout,
    Moderation,
    PrejoinPreferences,
    Recovery,
    Roster
  }

  alias RetroHexChatWeb.Live.GroupCallConfirmDialog
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.MediaDevices
  alias RetroHexChatWeb.Params

  @layout_modes Layout.layout_modes()
  # The conference's window on its own page (`CallLive`'s desktop).
  @call_window_id "group-call"

  @type event_result :: {:cont | :halt, Socket.t()}

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  # Backing out of the antechamber is backing out of the surface: there is
  # nothing behind it to return to.
  def handle_event("group_call_prejoin_cancel", _params, socket) do
    {:halt,
     socket
     |> PrejoinPreferences.remember()
     |> assign(group_call_prejoin: nil)
     |> Surface.close()}
  end

  def handle_event(
        "group_call_prejoin_join",
        params,
        %{assigns: %{group_call_prejoin: %{channel_name: channel_name, user_id: user_id}}} =
          socket
      ) do
    preferences =
      params
      |> GroupCallShape.value(:group_call_prejoin)
      |> PrejoinPreferences.normalize()

    {:halt,
     socket
     |> PrejoinPreferences.save(preferences)
     |> assign(group_call_prejoin_preferences: preferences)
     |> assign(group_call_prejoin: nil)
     |> join_channel_call(channel_name, user_id, preferences)}
  end

  def handle_event("group_call_prejoin_join", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_prejoin_devices_listed",
        payload,
        %{assigns: %{group_call_prejoin: %{}}} = socket
      ) do
    {:halt,
     update_prejoin(socket, fn prejoin ->
       Map.put(prejoin, :devices, GroupCallShape.normalize_devices(payload))
     end)}
  end

  def handle_event("group_call_prejoin_devices_listed", _payload, socket), do: {:halt, socket}

  def handle_event(
        "group_call_prejoin_preferences_loaded",
        payload,
        %{assigns: %{group_call_prejoin: %{}}} = socket
      ) do
    preferences = PrejoinPreferences.normalize(payload)

    {:halt,
     socket
     |> assign(group_call_prejoin_preferences: preferences)
     |> update_prejoin(fn prejoin ->
       prejoin
       |> Map.put(:media, preferences.media)
       |> Map.put(:layout, preferences.layout)
       |> Map.put(:device_preferences, preferences.device_preferences)
     end)}
  end

  def handle_event("group_call_prejoin_preferences_loaded", payload, socket) do
    preferences = PrejoinPreferences.normalize(payload)

    {:halt, assign(socket, group_call_prejoin_preferences: preferences)}
  end

  def handle_event("group_call_leave", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, open_confirm(socket)}
  end

  def handle_event("group_call_leave", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_console_select",
        %{"section" => section},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, select_console_section(socket, section)}
  end

  def handle_event("group_call_console_select", _params, socket), do: {:halt, socket}

  def handle_event("group_call_retry", _params, %{assigns: %{group_call: %{}}} = socket) do
    CallEvents.emit_recovery_transition(:group_call, :negotiating, "manual_retry", %{
      manual_retry: false,
      trigger: "manual"
    })

    socket =
      CallAssign.update(socket, fn call ->
        call
        |> Map.put(:status, :negotiating)
        |> Map.put(:warning, dgettext("group_call", "Requesting a fresh media offer."))
        |> Map.put(:error, nil)
        |> Map.put(:recovery, %{
          GroupCallShape.empty_recovery()
          | state: :negotiating,
            reason: "manual_retry",
            trigger: "manual",
            manual_retry: false,
            message: dgettext("group_call", "Requesting a fresh media offer.")
        })
      end)
      |> push_event("group_call_retry_media", %{trigger: "manual"})

    {:halt, socket}
  end

  def handle_event("group_call_retry", _params, socket), do: {:halt, socket}

  def handle_event("group_call_close_room", _params, %{assigns: %{group_call: %{}}} = socket) do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {:open_end_call, socket.assigns.group_call.channel_name}
    )

    {:halt, socket}
  end

  def handle_event("group_call_close_room", _params, socket), do: {:halt, socket}

  def handle_event("group_call_mute_all", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, Moderation.open_bulk_media_confirm(socket, :mute_all)}
  end

  def handle_event("group_call_mute_all", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_camera_off_all",
        _params,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, Moderation.open_bulk_media_confirm(socket, :camera_off_all)}
  end

  def handle_event("group_call_camera_off_all", _params, socket), do: {:halt, socket}

  def handle_event("group_call_toggle_lock", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, Moderation.toggle_lock(socket)}
  end

  def handle_event("group_call_toggle_lock", _params, socket), do: {:halt, socket}

  def handle_event("group_call_confirm_leave", _params, %{assigns: %{group_call: %{}}} = socket) do
    close_confirm()
    {:halt, end_current_call(socket, "left")}
  end

  def handle_event("group_call_confirm_leave", _params, socket) do
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
    {:halt, Moderation.close_room(socket)}
  end

  def handle_event("group_call_confirm_end_call", _params, socket) do
    close_confirm()
    {:halt, socket}
  end

  def handle_event(
        "group_call_confirm_kick_participant",
        _params,
        %{assigns: %{group_call: %{}, group_call_pending: %{action: :kick_participant}}} = socket
      ) do
    close_confirm()
    pending = socket.assigns.group_call_pending

    socket =
      socket
      |> assign(group_call_pending: nil)
      |> Moderation.kick_participant(pending.participant_id)

    {:halt, socket}
  end

  def handle_event("group_call_confirm_kick_participant", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event(
        "group_call_confirm_mute_all",
        _params,
        %{assigns: %{group_call: %{}, group_call_pending: %{action: :mute_all}}} = socket
      ) do
    close_confirm()

    {:halt,
     socket
     |> assign(group_call_pending: nil)
     |> Moderation.moderate_all_media(:mute_all)}
  end

  def handle_event("group_call_confirm_mute_all", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event(
        "group_call_confirm_camera_off_all",
        _params,
        %{assigns: %{group_call: %{}, group_call_pending: %{action: :camera_off_all}}} = socket
      ) do
    close_confirm()

    {:halt,
     socket
     |> assign(group_call_pending: nil)
     |> Moderation.moderate_all_media(:camera_off_all)}
  end

  def handle_event("group_call_confirm_camera_off_all", _params, socket) do
    close_confirm()
    {:halt, assign(socket, group_call_pending: nil)}
  end

  def handle_event("group_call_toggle_audio", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_media(socket, :audio)}
  end

  def handle_event("group_call_toggle_video", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_media(socket, :video)}
  end

  def handle_event("group_call_toggle_hand", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_hand(socket)}
  end

  def handle_event("group_call_toggle_hand", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_layout_mode",
        %{"mode" => mode},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, set_layout_mode(socket, mode)}
  end

  def handle_event("group_call_layout_mode", _params, socket), do: {:halt, socket}

  def handle_event("group_call_layout_next", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, cycle_layout_mode(socket)}
  end

  def handle_event("group_call_layout_next", _params, socket), do: {:halt, socket}

  def handle_event("group_call_focus_next", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, focus_next_participant(socket)}
  end

  def handle_event("group_call_focus_next", _params, socket), do: {:halt, socket}

  def handle_event("group_call_cycle_self_view", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, cycle_self_view(socket)}
  end

  def handle_event("group_call_cycle_self_view", _params, socket), do: {:halt, socket}

  def handle_event("group_call_toggle_mini", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_mini(socket)}
  end

  def handle_event("group_call_toggle_mini", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_focus_participant",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, focus_participant(socket, participant_id)}
  end

  def handle_event("group_call_focus_participant", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_toggle_pin_participant",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, toggle_pin_participant(socket, participant_id)}
  end

  def handle_event("group_call_toggle_pin_participant", _params, socket), do: {:halt, socket}

  def handle_event("group_call_clear_focus", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, clear_focus(socket)}
  end

  def handle_event("group_call_clear_focus", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_moderate_audio",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, Moderation.moderate_audio(socket, participant_id)}
  end

  def handle_event(
        "group_call_moderate_video",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, Moderation.moderate_video(socket, participant_id)}
  end

  def handle_event(
        "group_call_moderate_screen",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, Moderation.moderate_screen(socket, participant_id)}
  end

  def handle_event(
        "group_call_allow_speak",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, Moderation.allow_speak(socket, participant_id)}
  end

  def handle_event(
        "group_call_kick_participant",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, Moderation.open_kick_confirm(socket, participant_id)}
  end

  def handle_event("group_call_webrtc_ready", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, CallAssign.push_layout(socket)}
  end

  def handle_event("group_call_webrtc_ready", _params, socket), do: {:halt, socket}

  def handle_event("group_call_client_joined", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant =
      GroupCallShape.normalize_participant(GroupCallShape.value(payload, :participant))

    call =
      socket.assigns.group_call
      |> Map.put(:status, :connecting)
      |> Map.put(:participant_id, participant.id)
      |> Map.put(:self_role, participant.channel_role_snapshot)
      |> Roster.merge_summary(payload)
      |> Roster.put_participant(participant)

    {:halt, socket |> assign(group_call: call) |> CallAssign.push_layout()}
  end

  def handle_event("group_call_offer_received", _payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, CallAssign.update(socket, &Recovery.put_negotiating_status/1)}
  end

  def handle_event("group_call_peer_joined", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant =
      GroupCallShape.normalize_participant(GroupCallShape.value(payload, :participant))

    call =
      socket.assigns.group_call
      |> Roster.put_participant(participant)
      |> Roster.maybe_mark_connected(participant)

    {:halt, socket |> assign(group_call: call) |> CallAssign.push_layout()}
  end

  def handle_event("group_call_peer_left", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant_id = GroupCallShape.value(payload, :participant_id)
    call = socket.assigns.group_call

    if participant_id == call.participant_id do
      {:halt,
       socket
       |> assign(group_call: nil, group_call_pending: nil)
       |> Surface.close()}
    else
      {:halt,
       socket
       |> CallAssign.update(&Roster.remove_participant(&1, participant_id))
       |> CallAssign.push_layout()}
    end
  end

  def handle_event("group_call_media_state", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant =
      GroupCallShape.normalize_participant(GroupCallShape.value(payload, :participant))

    {:halt,
     socket
     |> CallAssign.update(&Roster.put_participant(&1, participant))
     |> CallAssign.push_layout()}
  end

  def handle_event(
        "group_call_screen_share_state",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    track = GroupCallShape.normalize_track(GroupCallShape.value(payload, :track))
    active? = GroupCallShape.truthy?(GroupCallShape.value(payload, :active))
    call = socket.assigns.group_call

    participant =
      payload
      |> GroupCallShape.value(:participant)
      |> GroupCallShape.normalize_participant()
      |> Roster.merge_existing_participant_media(call)

    participant_id =
      Params.integer(GroupCallShape.value(payload, :participant_id) || participant.id)

    {:halt,
     socket
     |> CallAssign.update(fn call ->
       call
       |> Roster.put_participant(participant)
       |> Roster.put_track(track)
       |> Roster.put_screen_share_media(participant_id, active?)
       |> Layout.maybe_focus_screen_share(participant_id, active?)
     end)
     |> CallAssign.push_layout()}
  end

  def handle_event(
        "group_call_media_state_forced",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    media = GroupCallShape.normalize_media(payload)

    {:halt,
     CallAssign.update(socket, fn call ->
       call
       |> Map.put(:media, media)
       |> update_self_media(media)
     end)
     |> CallAssign.push_layout()}
  end

  # A track that arrives and a track that changes land the same way.
  def handle_event(event, payload, %{assigns: %{group_call: %{}}} = socket)
      when event in ["group_call_track_added", "group_call_track_updated"] do
    track = GroupCallShape.normalize_track(GroupCallShape.value(payload, :track))
    {:halt, socket |> CallAssign.update(&Roster.put_track(&1, track)) |> CallAssign.push_layout()}
  end

  def handle_event("group_call_track_removed", payload, %{assigns: %{group_call: %{}}} = socket) do
    track_id = GroupCallShape.value(payload, :track_id)

    {:halt,
     socket |> CallAssign.update(&Roster.remove_track(&1, track_id)) |> CallAssign.push_layout()}
  end

  # The room ended under this person: the page says so, and who did it, in
  # place of a "you left" they never chose.
  def handle_event("group_call_closed", payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt,
     socket
     |> assign(
       group_call: nil,
       group_call_pending: nil,
       left_reason: "closed",
       left_by: GroupCallShape.value(payload, :ended_by)
     )
     |> Surface.close()}
  end

  def handle_event(
        "group_call_connection_state",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    state = GroupCallShape.value(payload, :state)
    {:halt, Recovery.apply_connection_state(socket, state)}
  end

  def handle_event("group_call_recovery_state", payload, %{assigns: %{group_call: %{}}} = socket) do
    recovery = GroupCallShape.normalize_recovery(payload)
    Recovery.emit_group_call_recovery_transition(recovery)

    {:halt, CallAssign.update(socket, &Recovery.apply_recovery_state(&1, payload))}
  end

  def handle_event("group_call_stats", payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt,
     CallAssign.update(socket, fn call ->
       stats = GroupCallStats.normalize(payload)

       call
       |> Map.put(:stats, stats)
       |> Recovery.apply_stats_connection_state(stats)
       |> refresh_server_stats()
     end)}
  end

  def handle_event(
        "group_call_participant_quality",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    socket = CallAssign.update(socket, &Roster.put_participant_quality(&1, payload))

    {:halt, CallAssign.push_speaker_layout(socket)}
  end

  def handle_event("group_call_reaction", payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, CallAssign.update(socket, &Roster.put_group_call_reaction(&1, payload))}
  end

  def handle_event("group_call_client_warning", payload, %{assigns: %{group_call: %{}}} = socket) do
    message =
      GroupCallShape.value(payload, :message) ||
        dgettext("group_call", "Group call media is degraded.")

    socket =
      CallAssign.update(socket, fn call ->
        call
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)
      end)

    {:halt, Surface.system(socket, message)}
  end

  def handle_event("group_call_client_error", payload, %{assigns: %{group_call: %{}}} = socket) do
    CallEvents.emit_client_error(
      :group_call,
      GroupCallShape.value(payload, :code) || "connection_failed",
      %{
        phase: "liveview_client_error"
      }
    )

    message =
      GroupCallShape.value(payload, :message) ||
        dgettext("group_call", "Group call connection failed.")

    socket =
      CallAssign.update(socket, fn call ->
        call
        |> Map.put(:status, :error)
        |> Map.put(:error, message)
        |> Map.put(:warning, nil)
      end)

    {:halt, Surface.error(socket, message)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  The surface's first state: the antechamber, or straight back inside a call
  you never actually left.

  A reload, a deploy or a reconnect finds you still an active participant in
  the room, because the `RoomServer` owns that fact and the tab does not.
  Dropping such a person at the device picker would be asking them to rejoin
  something they never left.

  Both states are decided here, in the mount, and never by a message sent to
  the surface afterwards: initial data that arrives after the first render is
  invisible to ExUnit and only ever caught in a browser.
  """
  @spec mount_call(Socket.t(), String.t(), integer()) :: Socket.t()
  def mount_call(socket, channel_name, user_id) do
    case rejoinable_participant(channel_name, socket.assigns.nickname) do
      {summary, participant} ->
        reattach_active_participant(socket, channel_name, summary, participant, user_id)

      nil ->
        open_prejoin(socket, channel_name, user_id)
    end
  end

  @doc """
  Leave for good, at the host's request rather than the person's.

  The two reasons are the same in kind: the channel behind the call is gone, or
  it is being swapped for another one's. Neither is a window being closed, so
  neither asks.
  """
  @spec leave(Socket.t(), String.t()) :: Socket.t()
  def leave(%{assigns: %{group_call: call}} = socket, reason) when is_map(call) do
    end_current_call(socket, reason)
  end

  def leave(socket, reason) do
    socket
    |> assign(
      group_call_prejoin: nil,
      left_reason: stronger(socket.assigns[:left_reason], reason)
    )
    |> Surface.close()
  end

  # A ban and the conference removal it causes arrive as two messages, in
  # either order. The page says the strongest of them: being banned from the
  # channel explains being removed from its conference, never the other way.
  @reason_rank %{"channel_ban" => 3, "channel_kick" => 2, "kicked" => 1}

  defp stronger(current, reason) do
    if Map.get(@reason_rank, current, 0) > Map.get(@reason_rank, reason, 0),
      do: current,
      else: reason
  end

  @doc """
  Who is in the room right now, by nickname, for the antechamber's roster.

  Walking into a room without being told who is already in it is the one thing
  a door should not do.
  """
  @spec roster(String.t()) :: [String.t()]
  def roster(channel_name) do
    channel_name
    |> GroupCallSummary.fetch()
    |> GroupCallSummary.normalize(channel_name)
    |> Map.fetch!(:participants)
    |> Enum.map(& &1.nickname)
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
  end

  @spec room_token(String.t()) :: String.t() | nil
  defp room_token(channel_name) do
    channel_name
    |> GroupCallSummary.fetch()
    |> GroupCallSummary.normalize(channel_name)
    |> Map.get(:room, %{})
    |> Map.get(:token)
  end

  @doc """
  Fold a room broadcast into the call, when it is this call's room.

  The roster on screen while you are inside comes from two places that must not
  disagree: the hook, which reports what the browser sees, and the room server,
  which is the authority on who is actually in it. This is the second.
  """
  @spec apply_summary(Socket.t(), String.t(), map() | nil) :: Socket.t()
  def apply_summary(
        %{assigns: %{group_call: %{channel_name: channel_name} = call}} = socket,
        channel_name,
        summary
      )
      when is_map(summary) do
    assign(socket,
      group_call: Roster.merge_summary(call, GroupCallSummary.normalize(summary, channel_name))
    )
  end

  def apply_summary(socket, _channel_name, _summary), do: socket

  @doc "Redraw the antechamber's roster after the room told us it changed."
  @spec refresh_roster(Socket.t()) :: Socket.t()
  def refresh_roster(%{assigns: %{group_call_prejoin: %{channel_name: channel_name}}} = socket) do
    assign(socket, prejoin_roster: roster(channel_name))
  end

  def refresh_roster(socket), do: socket

  defp rejoinable_participant(channel_name, nickname) do
    summary = GroupCallSummary.fetch(channel_name)

    room_id =
      summary
      |> GroupCallShape.value(:room)
      |> GroupCallShape.value(:id)
      |> Params.integer()

    with room_id when is_integer(room_id) <- room_id,
         participant when not is_nil(participant) <-
           GroupCall.active_participant(room_id, nickname) do
      {summary, participant}
    else
      _other -> nil
    end
  end

  defp join_channel_call(socket, channel_name, user_id, preferences) do
    actor = %{user_id: user_id, nickname: socket.assigns.nickname}
    preferences = PrejoinPreferences.normalize(preferences)

    with {:ok, %{token: token}} <- GroupCall.get_or_create_channel_call(channel_name, actor),
         {:ok, _pid} <- GroupCall.ensure_room_server(token),
         {:ok, summary} <- GroupCall.get_summary(token) do
      join_token = JoinToken.sign(token, channel_name, user_id, actor.nickname)

      call =
        summary
        |> new_call(token, channel_name, user_id, actor.nickname, join_token, preferences)
        |> Map.put(:status, :joining)

      assign(socket, group_call: call)
    else
      {:error, message} when is_binary(message) -> Surface.error(socket, message)
      {:error, reason} -> Surface.error(socket, inspect(reason))
    end
  end

  defp open_prejoin(socket, channel_name, user_id) do
    stored = socket.assigns[:group_call_prejoin_preferences] || PrejoinPreferences.load(socket)
    preferences = stored || PrejoinPreferences.default()

    assign(socket,
      group_call_prejoin: %{
        channel_name: channel_name,
        user_id: user_id,
        # The room exists before you walk into it, so its address can be handed
        # out from here. Inviting people and then joining is the order every
        # other surface already has.
        token: room_token(channel_name),
        # Whose antechamber this is, and whether the server had anything to
        # render. A terminal that was never trusted has no record here, and the
        # browser's own copy is then the only memory of the choice there is.
        scope: socket.assigns[:nickname],
        remembered: stored != nil,
        media: preferences.media,
        layout: preferences.layout,
        devices: default_devices(),
        device_preferences: preferences.device_preferences,
        warning: nil
      },
      prejoin_roster: roster(channel_name)
    )
  end

  defp open_confirm(socket) do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {:open_leave, socket.assigns.group_call.channel_name}
    )

    socket
  end

  defp close_confirm do
    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: :close
    )
  end

  defp reattach_active_participant(socket, channel_name, summary, participant, fallback_user_id) do
    room = GroupCallShape.normalize_room(GroupCallShape.value(summary, :room))
    token = GroupCallShape.value(room, :token)
    user_id = GroupCallShape.value(participant, :registered_nick_id)
    nickname = socket.assigns.nickname

    if is_binary(token) and is_integer(user_id) do
      preferences =
        socket.assigns[:group_call_prejoin_preferences] ||
          PrejoinPreferences.load(socket) ||
          PrejoinPreferences.default()

      join_token = JoinToken.sign(token, channel_name, user_id, nickname)
      recovery_message = Recovery.recovery_message(:rejoining)

      recovery = %{
        GroupCallShape.empty_recovery()
        | state: :rejoining,
          reason: "liveview_mount",
          trigger: "rehydrate",
          message: recovery_message
      }

      # Counted once per reattach: the dead render runs this too, and a
      # prefetch is not a rejoin.
      if Phoenix.LiveView.connected?(socket) do
        CallEvents.emit_recovery_transition(:group_call, :rejoining, "liveview_mount", %{
          manual_retry: false,
          trigger: "rehydrate"
        })
      end

      call =
        summary
        |> new_call(token, channel_name, user_id, nickname, join_token, preferences)
        |> Map.put(:participant_id, participant.id)
        |> Map.put(:self_role, participant.channel_role_snapshot)
        |> Map.put(:status, :reconnecting)
        |> Map.put(:warning, recovery_message)
        |> Map.put(:recovery, recovery)
        |> Roster.put_participant(GroupCallShape.normalize_participant(participant))

      assign(socket, group_call: call, group_call_pending: nil, group_call_prejoin: nil)
    else
      open_prejoin(socket, channel_name, fallback_user_id)
    end
  end

  defp select_console_section(socket, "stats"), do: put_console_section(socket, :stats)

  defp select_console_section(socket, "people") do
    socket
    |> CallAssign.update(fn call ->
      layout =
        call
        |> Layout.layout()
        |> Map.put(:console_section, :people)

      %{call | layout: layout}
    end)
    |> CallAssign.push_layout()
  end

  defp select_console_section(socket, "settings"), do: put_console_section(socket, :settings)
  defp select_console_section(socket, "call"), do: put_console_section(socket, :call)
  defp select_console_section(socket, _section), do: put_console_section(socket, :call)

  defp put_console_section(socket, section) when section in [:call, :people, :stats, :settings] do
    CallAssign.update(socket, fn call ->
      layout = call |> Layout.layout() |> Map.put(:console_section, section)
      %{call | layout: layout}
    end)
    |> CallAssign.push_layout()
  end

  defp end_current_call(%{assigns: %{group_call: call}} = socket, reason) when is_map(call) do
    if is_integer(call.participant_id) do
      _ = GroupCall.leave_call(call.token, call.participant_id, reason)
    end

    socket
    |> assign(
      group_call: nil,
      group_call_pending: nil,
      group_call_prejoin: nil,
      left_reason: reason
    )
    |> Surface.close()
  end

  defp new_call(summary, token, channel_name, user_id, nickname, join_token, preferences) do
    %{
      token: token,
      room: GroupCallShape.normalize_room(GroupCallShape.value(summary, :room)),
      channel_name: channel_name,
      user_id: user_id,
      nickname: nickname,
      join_token: join_token,
      participant_id: nil,
      self_role: nil,
      status: :joining,
      connection_state: nil,
      participants:
        GroupCallShape.normalize_participants(GroupCallShape.value(summary, :participants)),
      pending_participants:
        GroupCallShape.normalize_participants(
          GroupCallShape.value(summary, :pending_participants)
        ),
      tracks: GroupCallShape.normalize_tracks(GroupCallShape.value(summary, :tracks)),
      stats: GroupCallStats.empty(),
      server_stats:
        GroupCallShape.normalize_server_stats(GroupCallShape.value(summary, :server_stats)),
      participant_quality: GroupCallShape.empty_participant_quality(),
      reactions: [],
      recovery: GroupCallShape.empty_recovery(),
      media: preferences.media,
      layout: preferences.layout,
      device_preferences: preferences.device_preferences,
      error: nil,
      warning: nil
    }
    |> GroupCallSummary.put_nick_locales()
  end

  defp toggle_media(socket, kind) do
    call = socket.assigns.group_call

    if local_media_blocked?(call, kind) do
      socket
      |> Surface.error(local_media_blocked_message(kind))
      |> push_event("group_call_set_media_state", call.media)
      |> CallAssign.push_layout()
    else
      do_toggle_media(socket, kind)
    end
  end

  defp do_toggle_media(socket, kind) do
    call = socket.assigns.group_call
    media = Map.update(call.media, kind, false, &(!&1))
    call = %{call | media: media} |> update_self_media(media)

    socket
    |> assign(group_call: call)
    |> push_event("group_call_set_media_state", media)
    |> CallAssign.push_layout()
  end

  defp toggle_hand(socket) do
    call = socket.assigns.group_call

    with participant_id when is_integer(participant_id) <- call.participant_id,
         {:ok, actor} <- Moderation.actor(socket),
         {:ok, participant} <-
           GroupCall.set_hand_raised(
             call.token,
             actor,
             participant_id,
             !Roster.self_hand_raised?(call)
           ) do
      participant = GroupCallShape.normalize_participant(participant)

      socket
      |> CallAssign.update(&Roster.put_self_participant(&1, participant))
      |> CallAssign.push_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not update raised hand."))
    end
  end

  defp local_media_blocked?(%{media: %{server_audio_muted: true}}, :audio), do: true
  defp local_media_blocked?(%{media: %{server_video_blocked: true}}, :video), do: true
  defp local_media_blocked?(_call, _kind), do: false

  defp local_media_blocked_message(:audio),
    do: dgettext("group_call", "Your microphone was muted by a moderator.")

  defp local_media_blocked_message(:video),
    do: dgettext("group_call", "Your camera was disabled by a moderator.")

  defp set_layout_mode(socket, mode) when mode in @layout_modes do
    CallAssign.update(socket, fn call ->
      layout =
        call
        |> Layout.layout()
        |> Map.put(:mode, String.to_existing_atom(mode))
        |> Layout.maybe_focus_for_mode(call)

      %{call | layout: layout}
    end)
    |> CallAssign.push_layout()
  end

  defp set_layout_mode(socket, _mode), do: socket

  defp cycle_layout_mode(socket) do
    call = socket.assigns.group_call
    current = call |> Layout.layout() |> Map.get(:mode, :auto) |> Atom.to_string()
    mode = Layout.next_layout_mode(current)

    set_layout_mode(socket, mode)
  end

  defp cycle_self_view(socket) do
    CallAssign.update(socket, fn call ->
      current = Map.get(Layout.layout(call), :self_view, :tile)
      next = Layout.next_self_view(current)

      %{call | layout: Map.put(Layout.layout(call), :self_view, next)}
    end)
    |> CallAssign.push_layout()
  end

  defp toggle_mini(socket) do
    mini? = !Map.get(Layout.layout(socket.assigns.group_call), :mini, false)

    socket
    |> CallAssign.update(fn call ->
      %{call | layout: Map.put(Layout.layout(call), :mini, mini?)}
    end)
    |> CallAssign.push_layout()
    |> push_call_window_geometry(mini?)
  end

  # Compact is a size, and a size is the window manager's: without this the
  # call kept its whole window and squeezed six tiles into strips. The compact
  # window remembers where the call was, maximized included, and expanding
  # puts it back there; the default size is the fallback.
  defp push_call_window_geometry(socket, true) do
    push_event(socket, "window_command", %{
      action: "set_geometry",
      id: @call_window_id,
      width: 320,
      height: 250,
      anchor: "bottom_right",
      margin: 16,
      remember: true
    })
  end

  defp push_call_window_geometry(socket, false) do
    push_event(socket, "window_command", %{
      action: "restore_geometry",
      id: @call_window_id,
      width: 960,
      height: 640
    })
  end

  defp focus_participant(socket, participant_id) do
    with participant_id when is_integer(participant_id) <- Params.integer(participant_id),
         true <- participant_id in Enum.map(socket.assigns.group_call.participants, & &1.id) do
      CallAssign.update(socket, fn call ->
        layout =
          call
          |> Layout.layout()
          |> Map.put(:mode, :focus)
          |> Map.put(:focused_participant_id, participant_id)

        %{call | layout: layout}
      end)
      |> CallAssign.push_layout()
    else
      _error -> socket
    end
  end

  defp focus_next_participant(socket) do
    call = socket.assigns.group_call
    participant_ids = Enum.map(call.participants || [], & &1.id)
    current_id = Layout.layout(call).focused_participant_id

    participant_id =
      if current_id do
        Layout.next_participant_id(participant_ids, current_id)
      else
        Layout.default_focus_participant_id(call) || List.first(participant_ids)
      end

    case participant_id do
      nil -> socket
      participant_id -> focus_participant(socket, participant_id)
    end
  end

  defp toggle_pin_participant(socket, participant_id) do
    with participant_id when is_integer(participant_id) <- Params.integer(participant_id),
         true <- participant_id in Enum.map(socket.assigns.group_call.participants, & &1.id) do
      CallAssign.update(socket, fn call ->
        layout = Layout.layout(call)

        pinned_participant_ids =
          layout
          |> Map.get(:pinned_participant_ids, [])
          |> Layout.toggle_participant_id(participant_id)

        %{call | layout: Map.put(layout, :pinned_participant_ids, pinned_participant_ids)}
      end)
      |> CallAssign.push_layout()
    else
      _error -> socket
    end
  end

  defp clear_focus(socket) do
    CallAssign.update(socket, fn call ->
      layout =
        call
        |> Layout.layout()
        |> Map.put(:mode, :auto)
        |> Map.put(:focused_participant_id, nil)

      %{call | layout: layout}
    end)
    |> CallAssign.push_layout()
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

  defp refresh_server_stats(call) do
    case GroupCall.get_summary(call.token) do
      {:ok, summary} ->
        Map.put(
          call,
          :server_stats,
          GroupCallShape.normalize_server_stats(GroupCallShape.value(summary, :server_stats))
        )

      {:error, _reason} ->
        call
    end
  end

  defp update_prejoin(socket, fun) do
    assign(socket, group_call_prejoin: fun.(socket.assigns.group_call_prejoin))
  end

  defp default_devices, do: MediaDevices.none()
end
