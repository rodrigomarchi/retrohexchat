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
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Calls.Events, as: CallEvents
  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Policy, as: ChannelPolicy
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.App.GroupCallStats
  alias RetroHexChatWeb.App.GroupCallSummary
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.Live.GroupCallConfirmDialog
  alias RetroHexChatWeb.Live.Surface
  alias RetroHexChatWeb.MediaDevices

  @prejoin_preference_namespace "group_call_prejoin"
  @layout_modes ~w(auto grid focus sidebar speaker)
  @self_view_cycle [:tile, :pip, :hidden]

  @type event_result :: {:cont | :halt, Socket.t()}

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  # Backing out of the antechamber is backing out of the surface: there is
  # nothing behind it to return to.
  def handle_event("group_call_prejoin_cancel", _params, socket) do
    {:halt,
     socket
     |> remember_prejoin_preferences()
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
      |> normalize_prejoin_preferences()

    {:halt,
     socket
     |> maybe_save_prejoin_preferences(preferences)
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
    preferences = normalize_prejoin_preferences(payload)

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
    preferences = normalize_prejoin_preferences(payload)

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
      update_call(socket, fn call ->
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
    {:halt, open_bulk_media_confirm(socket, :mute_all)}
  end

  def handle_event("group_call_mute_all", _params, socket), do: {:halt, socket}

  def handle_event(
        "group_call_camera_off_all",
        _params,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, open_bulk_media_confirm(socket, :camera_off_all)}
  end

  def handle_event("group_call_camera_off_all", _params, socket), do: {:halt, socket}

  def handle_event("group_call_toggle_lock", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, toggle_lock(socket)}
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
    {:halt, close_room(socket)}
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
      |> kick_participant(pending.participant_id)

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
     |> moderate_all_media(:mute_all)}
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
     |> moderate_all_media(:camera_off_all)}
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
    {:halt, moderate_audio(socket, participant_id)}
  end

  def handle_event(
        "group_call_moderate_video",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, moderate_video(socket, participant_id)}
  end

  def handle_event(
        "group_call_moderate_screen",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, moderate_screen(socket, participant_id)}
  end

  def handle_event(
        "group_call_allow_speak",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, allow_speak(socket, participant_id)}
  end

  def handle_event(
        "group_call_kick_participant",
        %{"participant-id" => participant_id},
        %{assigns: %{group_call: %{}}} = socket
      ) do
    {:halt, open_kick_confirm(socket, participant_id)}
  end

  def handle_event("group_call_webrtc_ready", _params, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, push_group_call_layout(socket)}
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
      |> merge_summary(payload)
      |> put_participant(participant)

    {:halt, socket |> assign(group_call: call) |> push_group_call_layout()}
  end

  def handle_event("group_call_offer_received", _payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, update_call(socket, &put_negotiating_status/1)}
  end

  def handle_event("group_call_peer_joined", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant =
      GroupCallShape.normalize_participant(GroupCallShape.value(payload, :participant))

    call =
      socket.assigns.group_call
      |> put_participant(participant)
      |> maybe_mark_connected(participant)

    {:halt, socket |> assign(group_call: call) |> push_group_call_layout()}
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
       socket |> update_call(&remove_participant(&1, participant_id)) |> push_group_call_layout()}
    end
  end

  def handle_event("group_call_media_state", payload, %{assigns: %{group_call: %{}}} = socket) do
    participant =
      GroupCallShape.normalize_participant(GroupCallShape.value(payload, :participant))

    {:halt, socket |> update_call(&put_participant(&1, participant)) |> push_group_call_layout()}
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
      |> merge_existing_participant_media(call)

    participant_id =
      GroupCallShape.normalize_id(
        GroupCallShape.value(payload, :participant_id) || participant.id
      )

    {:halt,
     socket
     |> update_call(fn call ->
       call
       |> put_participant(participant)
       |> maybe_put_track(track)
       |> put_screen_share_media(participant_id, active?)
       |> maybe_focus_screen_share(participant_id, active?)
     end)
     |> push_group_call_layout()}
  end

  def handle_event(
        "group_call_media_state_forced",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    media = GroupCallShape.normalize_media(payload)

    {:halt,
     update_call(socket, fn call ->
       call
       |> Map.put(:media, media)
       |> update_self_media(media)
     end)
     |> push_group_call_layout()}
  end

  def handle_event("group_call_track_added", payload, %{assigns: %{group_call: %{}}} = socket) do
    track = GroupCallShape.normalize_track(GroupCallShape.value(payload, :track))
    {:halt, socket |> update_call(&put_track(&1, track)) |> push_group_call_layout()}
  end

  def handle_event("group_call_track_updated", payload, %{assigns: %{group_call: %{}}} = socket) do
    track = GroupCallShape.normalize_track(GroupCallShape.value(payload, :track))
    {:halt, socket |> update_call(&put_track(&1, track)) |> push_group_call_layout()}
  end

  def handle_event("group_call_track_removed", payload, %{assigns: %{group_call: %{}}} = socket) do
    track_id = GroupCallShape.value(payload, :track_id)
    {:halt, socket |> update_call(&remove_track(&1, track_id)) |> push_group_call_layout()}
  end

  def handle_event("group_call_closed", payload, %{assigns: %{group_call: %{}}} = socket) do
    message =
      case GroupCallShape.value(payload, :reason) do
        nil -> dgettext("group_call", "Group call ended.")
        reason -> dgettext("group_call", "Group call ended: %{reason}", reason: reason)
      end

    socket =
      socket
      |> assign(group_call: nil, group_call_pending: nil)
      |> Surface.close()

    {:halt, Surface.system(socket, message)}
  end

  def handle_event(
        "group_call_connection_state",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    state = GroupCallShape.value(payload, :state)
    {:halt, apply_connection_state(socket, state)}
  end

  def handle_event("group_call_recovery_state", payload, %{assigns: %{group_call: %{}}} = socket) do
    recovery = GroupCallShape.normalize_recovery(payload)
    emit_group_call_recovery_transition(recovery)

    {:halt, update_call(socket, &apply_recovery_state(&1, payload))}
  end

  def handle_event("group_call_stats", payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt,
     update_call(socket, fn call ->
       stats = GroupCallStats.normalize(payload)

       call
       |> Map.put(:stats, stats)
       |> apply_stats_connection_state(stats)
       |> refresh_server_stats()
     end)}
  end

  def handle_event(
        "group_call_participant_quality",
        payload,
        %{assigns: %{group_call: %{}}} = socket
      ) do
    socket = update_call(socket, &put_participant_quality(&1, payload))

    {:halt, maybe_push_speaker_layout(socket)}
  end

  def handle_event("group_call_reaction", payload, %{assigns: %{group_call: %{}}} = socket) do
    {:halt, update_call(socket, &put_group_call_reaction(&1, payload))}
  end

  def handle_event("group_call_client_warning", payload, %{assigns: %{group_call: %{}}} = socket) do
    message =
      GroupCallShape.value(payload, :message) ||
        dgettext("group_call", "Group call media is degraded.")

    socket =
      update_call(socket, fn call ->
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
      update_call(socket, fn call ->
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

  def leave(socket, _reason) do
    socket
    |> assign(group_call_prejoin: nil)
    |> Surface.close()
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
      group_call: merge_summary(call, GroupCallSummary.normalize(summary, channel_name))
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
      |> GroupCallShape.normalize_id()

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
    preferences = normalize_prejoin_preferences(preferences)

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
    stored = socket.assigns[:group_call_prejoin_preferences] || load_prejoin_preferences(socket)
    preferences = stored || default_prejoin_preferences()

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
          load_prejoin_preferences(socket) ||
          default_prejoin_preferences()

      join_token = JoinToken.sign(token, channel_name, user_id, nickname)
      recovery_message = recovery_message(:rejoining)

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
        |> put_participant(GroupCallShape.normalize_participant(participant))

      assign(socket, group_call: call, group_call_pending: nil, group_call_prejoin: nil)
    else
      open_prejoin(socket, channel_name, fallback_user_id)
    end
  end

  defp select_console_section(socket, "stats"), do: put_console_section(socket, :stats)

  defp select_console_section(socket, "people") do
    socket
    |> update_call(fn call ->
      layout =
        call
        |> layout()
        |> Map.put(:console_section, :people)

      %{call | layout: layout}
    end)
    |> push_group_call_layout()
  end

  defp select_console_section(socket, "settings"), do: put_console_section(socket, :settings)
  defp select_console_section(socket, "call"), do: put_console_section(socket, :call)
  defp select_console_section(socket, _section), do: put_console_section(socket, :call)

  defp put_console_section(socket, section) when section in [:call, :people, :stats, :settings] do
    update_call(socket, fn call ->
      layout = call |> layout() |> Map.put(:console_section, section)
      %{call | layout: layout}
    end)
    |> push_group_call_layout()
  end

  defp end_current_call(%{assigns: %{group_call: call}} = socket, reason) when is_map(call) do
    if is_integer(call.participant_id) do
      _ = GroupCall.leave_call(call.token, call.participant_id, reason)
    end

    socket
    |> assign(group_call: nil, group_call_pending: nil, group_call_prejoin: nil)
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
  end

  defp apply_connection_state(socket, state) do
    case to_string(state) do
      "connected" ->
        CallEvents.emit_recovery_transition(:group_call, :connected, "connection_state", %{
          manual_retry: false,
          trigger: "connection_state"
        })

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

        CallEvents.emit_recovery_transition(
          :group_call,
          :reconnecting,
          "connection_disconnected",
          %{
            manual_retry: false,
            trigger: "connection_state"
          }
        )

        update_call(socket, fn call ->
          call
          |> Map.put(:connection_state, state)
          |> Map.put(:status, :reconnecting)
          |> Map.put(:warning, message)
          |> Map.put(:error, nil)
        end)

      "failed" ->
        message =
          dgettext(
            "group_call",
            "Group call media connection failed. Retry the media connection."
          )

        CallEvents.emit_recovery_transition(:group_call, :failed, "connection_failed", %{
          manual_retry: true,
          trigger: "connection_state"
        })

        CallEvents.emit_client_error(:group_call, "connection_failed", %{
          phase: "connection_state"
        })

        socket =
          update_call(socket, fn call ->
            call
            |> Map.put(:connection_state, state)
            |> Map.put(:status, :error)
            |> Map.put(:error, message)
            |> Map.put(:warning, nil)
            |> Map.put(:recovery, %{
              GroupCallShape.empty_recovery()
              | state: :failed,
                manual_retry: true,
                message: message
            })
          end)

        Surface.error(socket, message)

      _other ->
        update_call(socket, &Map.put(&1, :connection_state, state))
    end
  end

  defp put_negotiating_status(%{connection_state: "connected"} = call), do: call
  defp put_negotiating_status(call), do: Map.put(call, :status, :negotiating)

  defp apply_stats_connection_state(call, %{summary: %{connection_state: "connected"}}) do
    call
    |> Map.put(:connection_state, "connected")
    |> Map.put(:status, :connected)
    |> Map.put(:warning, nil)
    |> Map.put(:error, nil)
  end

  defp apply_stats_connection_state(call, _stats), do: call

  defp toggle_media(socket, kind) do
    call = socket.assigns.group_call

    if local_media_blocked?(call, kind) do
      socket
      |> Surface.error(local_media_blocked_message(kind))
      |> push_event("group_call_set_media_state", call.media)
      |> push_group_call_layout()
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
    |> push_group_call_layout()
  end

  defp toggle_hand(socket) do
    call = socket.assigns.group_call

    with participant_id when is_integer(participant_id) <- call.participant_id,
         {:ok, actor} <- actor(socket),
         {:ok, participant} <-
           GroupCall.set_hand_raised(call.token, actor, participant_id, !self_hand_raised?(call)) do
      participant = GroupCallShape.normalize_participant(participant)

      socket
      |> update_call(&put_self_participant(&1, participant))
      |> push_group_call_layout()
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
    update_call(socket, fn call ->
      layout =
        call
        |> layout()
        |> Map.put(:mode, String.to_existing_atom(mode))
        |> maybe_focus_for_mode(call)

      %{call | layout: layout}
    end)
    |> push_group_call_layout()
  end

  defp set_layout_mode(socket, _mode), do: socket

  defp cycle_layout_mode(socket) do
    call = socket.assigns.group_call
    current = call |> layout() |> Map.get(:mode, :auto) |> Atom.to_string()
    mode = next_layout_mode(current)

    set_layout_mode(socket, mode)
  end

  defp cycle_self_view(socket) do
    update_call(socket, fn call ->
      current = Map.get(layout(call), :self_view, :tile)
      next = next_self_view(current)

      %{call | layout: Map.put(layout(call), :self_view, next)}
    end)
    |> push_group_call_layout()
  end

  defp toggle_mini(socket) do
    update_call(socket, fn call ->
      layout = layout(call)
      %{call | layout: Map.put(layout, :mini, !Map.get(layout, :mini, false))}
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

  defp focus_next_participant(socket) do
    call = socket.assigns.group_call
    participant_ids = Enum.map(call.participants || [], & &1.id)
    current_id = layout(call).focused_participant_id

    participant_id =
      if current_id do
        next_participant_id(participant_ids, current_id)
      else
        default_focus_participant_id(call) || List.first(participant_ids)
      end

    case participant_id do
      nil -> socket
      participant_id -> focus_participant(socket, participant_id)
    end
  end

  defp toggle_pin_participant(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         true <- participant_id in Enum.map(socket.assigns.group_call.participants, & &1.id) do
      update_call(socket, fn call ->
        layout = layout(call)

        pinned_participant_ids =
          layout
          |> Map.get(:pinned_participant_ids, [])
          |> toggle_participant_id(participant_id)

        %{call | layout: Map.put(layout, :pinned_participant_ids, pinned_participant_ids)}
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

  defp put_self_participant(call, %{id: id, media_state: media} = participant)
       when id == call.participant_id do
    call
    |> put_participant(participant)
    |> Map.put(:media, media)
    |> Map.put(:self_role, participant.channel_role_snapshot || call[:self_role])
  end

  defp put_self_participant(call, participant), do: put_participant(call, participant)

  defp self_hand_raised?(call) do
    case self_participant(call) do
      nil -> Map.get(call.media || %{}, :hand_raised) == true
      participant -> participant_hand_raised?(participant)
    end
  end

  defp self_participant(%{participant_id: participant_id, participants: participants}) do
    Enum.find(participants || [], &(&1.id == participant_id))
  end

  defp self_participant(_call), do: nil

  defp participant_hand_raised?(%{media_state: media}) when is_map(media),
    do: Map.get(media, :hand_raised) == true

  defp participant_hand_raised?(_participant), do: false

  defp update_call(socket, fun) do
    assign(socket, group_call: fun.(socket.assigns.group_call))
  end

  defp push_group_call_layout(%{assigns: %{group_call: call}} = socket) when is_map(call) do
    push_event(socket, "group_call_layout_state", group_call_layout_payload(call))
  end

  defp push_group_call_layout(socket), do: socket

  defp maybe_push_speaker_layout(
         %{assigns: %{group_call: %{layout: %{mode: :speaker}}}} = socket
       ),
       do: push_group_call_layout(socket)

  defp maybe_push_speaker_layout(socket), do: socket

  defp moderate_audio(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         {:ok, participant} <- set_target_audio(socket.assigns.group_call, actor, target) do
      update_call(socket, &put_participant(&1, GroupCallShape.normalize_participant(participant)))
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(
          socket,
          dgettext("group_call", "Could not update participant media.")
        )
    end
  end

  defp moderate_video(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         {:ok, participant} <- set_target_video(socket.assigns.group_call, actor, target) do
      update_call(socket, &put_participant(&1, GroupCallShape.normalize_participant(participant)))
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(
          socket,
          dgettext("group_call", "Could not update participant camera.")
        )
    end
  end

  defp moderate_screen(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         {:ok, participant} <- set_target_screen_share(socket.assigns.group_call, actor, target) do
      socket
      |> update_call(&put_participant(&1, GroupCallShape.normalize_participant(participant)))
      |> push_group_call_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(
          socket,
          dgettext("group_call", "Could not update participant screen sharing.")
        )
    end
  end

  defp allow_speak(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, _target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         {:ok, participant} <-
           GroupCall.allow_participant_speak(
             socket.assigns.group_call.token,
             actor,
             participant_id
           ) do
      socket
      |> update_call(&put_participant(&1, GroupCallShape.normalize_participant(participant)))
      |> push_group_call_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(
          socket,
          dgettext("group_call", "Could not allow participant to speak.")
        )
    end
  end

  defp open_bulk_media_confirm(socket, action) when action in [:mute_all, :camera_off_all] do
    dialog_action =
      case action do
        :mute_all -> :open_mute_all
        :camera_off_all -> :open_camera_off_all
      end

    Phoenix.LiveView.send_update(GroupCallConfirmDialog,
      id: GroupCallConfirmDialog.id(),
      action: {dialog_action, socket.assigns.group_call.channel_name}
    )

    assign(socket, group_call_pending: %{action: action})
  end

  defp moderate_all_media(socket, action) when action in [:mute_all, :camera_off_all] do
    with {:ok, actor} <- actor(socket),
         {:ok, summary} <- apply_bulk_media_action(socket.assigns.group_call, actor, action) do
      socket
      |> update_call(&put_bulk_media_participants(&1, summary))
      |> maybe_empty_bulk_media_message(summary)
      |> push_group_call_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not update participants."))
    end
  end

  defp apply_bulk_media_action(call, actor, :mute_all),
    do: GroupCall.mute_all_participants(call.token, actor)

  defp apply_bulk_media_action(call, actor, :camera_off_all),
    do: GroupCall.block_all_participant_videos(call.token, actor)

  defp put_bulk_media_participants(call, %{participants: participants})
       when is_list(participants) do
    Enum.reduce(participants, call, fn participant, call ->
      put_participant(call, GroupCallShape.normalize_participant(participant))
    end)
  end

  defp put_bulk_media_participants(call, _summary), do: call

  defp maybe_empty_bulk_media_message(socket, %{changed_count: count}) when count > 0, do: socket

  defp maybe_empty_bulk_media_message(socket, _summary) do
    Surface.system(
      socket,
      dgettext("group_call", "No lower-ranked conference participants were affected.")
    )
  end

  defp toggle_lock(socket) do
    call = socket.assigns.group_call

    with {:ok, actor} <- actor(socket),
         {:ok, result} <- apply_lock_action(call, actor) do
      socket
      |> update_call(fn call ->
        %{
          call
          | room: GroupCallShape.normalize_room(GroupCallShape.value(result, :room) || call.room)
        }
      end)
      |> push_group_call_layout()
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not update conference lock."))
    end
  end

  defp apply_lock_action(call, actor) do
    if locked?(call) do
      GroupCall.unlock_call(call.token, actor)
    else
      GroupCall.lock_call(call.token, actor)
    end
  end

  defp locked?(%{room: %{metadata: metadata}}) when is_map(metadata) do
    GroupCallShape.value(metadata, :locked) == true or
      GroupCallShape.value(metadata, :admission_locked) == true
  end

  defp locked?(_call), do: false

  defp open_kick_confirm(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         :ok <- authorize_channel_ban(socket.assigns.group_call, actor, target) do
      Phoenix.LiveView.send_update(GroupCallConfirmDialog,
        id: GroupCallConfirmDialog.id(),
        action:
          {:open_kick_participant, socket.assigns.group_call.channel_name, participant_id,
           target.nickname}
      )

      assign(socket,
        group_call_pending: %{
          action: :kick_participant,
          participant_id: participant_id,
          target_nickname: target.nickname
        }
      )
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not remove participant."))
    end
  end

  defp kick_participant(socket, participant_id) do
    with {participant_id, ""} <- Integer.parse(to_string(participant_id)),
         {:ok, target} <- find_participant(socket.assigns.group_call, participant_id),
         {:ok, actor} <- actor(socket),
         :ok <- remove_participant_from_channel_call(socket.assigns.group_call, actor, target) do
      socket
      |> update_call(&remove_participant(&1, participant_id))
      |> Surface.system(
        dgettext(
          "group_call",
          "%{target} was removed from the conference and banned from %{channel}.",
          target: target.nickname,
          channel: socket.assigns.group_call.channel_name
        )
      )
    else
      {:error, message} when is_binary(message) ->
        Surface.error(socket, message)

      _error ->
        Surface.error(socket, dgettext("group_call", "Could not remove participant."))
    end
  end

  defp remove_participant_from_channel_call(call, actor, target) do
    reason = dgettext("group_call", "Removed from channel conference")

    with :ok <- authorize_channel_ban(call, actor, target),
         :ok <- Server.ban(call.channel_name, actor.nickname, target.nickname, reason),
         :ok <- kick_group_call_participant(call, actor, target) do
      :ok
    end
  end

  defp kick_group_call_participant(call, actor, target) do
    GroupCall.force_kick_participant(call.token, actor, target.id, "channel_kick")
  end

  defp authorize_channel_ban(call, actor, target) do
    with {:ok, channel_state} <- Server.get_state(call.channel_name) do
      channel_state
      |> membership_from_channel_state()
      |> ChannelPolicy.can_ban?(actor.nickname, target.nickname)
    end
  end

  defp membership_from_channel_state(%{members: members}) do
    Enum.reduce(members, Membership.new(), fn {nickname, role}, membership ->
      Membership.add(membership, nickname, role)
    end)
  end

  defp close_room(socket) do
    with {:ok, actor} <- actor(socket),
         :ok <- GroupCall.close_call(socket.assigns.group_call.token, actor, "moderation") do
      socket
      |> assign(group_call: nil, group_call_pending: nil)
      |> Surface.close()
    else
      {:error, message} when is_binary(message) -> Surface.error(socket, message)
      _error -> Surface.error(socket, dgettext("group_call", "Could not end group call."))
    end
  end

  defp set_target_audio(call, actor, target) do
    if participant_media?(target, :audio) do
      GroupCall.mute_participant(call.token, actor, target.id)
    else
      GroupCall.unmute_participant(call.token, actor, target.id)
    end
  end

  defp set_target_video(call, actor, target) do
    if participant_media_moderated?(target, :video) do
      GroupCall.unblock_participant_video(call.token, actor, target.id)
    else
      GroupCall.block_participant_video(call.token, actor, target.id)
    end
  end

  defp set_target_screen_share(call, actor, target) do
    if participant_media_moderated?(target, :screen) do
      GroupCall.unblock_participant_screen_share(call.token, actor, target.id)
    else
      GroupCall.block_participant_screen_share(call.token, actor, target.id)
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

  defp participant_media_moderated?(%{media_state: media}, :video) when is_map(media),
    do: Map.get(media, :server_video_blocked) == true

  defp participant_media_moderated?(%{media_state: media}, :screen) when is_map(media),
    do: Map.get(media, :server_screen_blocked) == true

  defp participant_media_moderated?(_participant, _key), do: false

  defp actor(socket) do
    case SessionHelpers.resolve_user_id(socket.assigns.nickname) do
      {:ok, user_id} ->
        {:ok, %{user_id: user_id, nickname: socket.assigns.nickname}}

      {:redirect, nil} ->
        {:error, dgettext("group_call", "You must be registered to moderate group calls.")}
    end
  end

  defp merge_summary(call, payload) do
    call
    |> Map.put(
      :room,
      GroupCallShape.normalize_room(GroupCallShape.value(payload, :room) || call.room)
    )
    |> Map.put(
      :participants,
      GroupCallShape.normalize_participants(GroupCallShape.value(payload, :participants))
    )
    |> Map.put(
      :pending_participants,
      GroupCallShape.normalize_participants(GroupCallShape.value(payload, :pending_participants))
    )
    |> Map.put(
      :tracks,
      GroupCallShape.normalize_tracks(GroupCallShape.value(payload, :tracks) || call.tracks)
    )
    |> Map.put(
      :server_stats,
      GroupCallShape.normalize_server_stats(
        GroupCallShape.value(payload, :server_stats) || call.server_stats
      )
    )
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

  defp merge_existing_participant_media(%{id: nil} = participant, _call), do: participant

  defp merge_existing_participant_media(
         %{id: participant_id, media_state: media} = participant,
         call
       ) do
    existing =
      Enum.find(call.participants || [], &(&1.id == participant_id))

    existing_media =
      case existing do
        %{media_state: existing_media} when is_map(existing_media) -> existing_media
        _missing -> %{}
      end

    %{participant | media_state: Map.merge(existing_media, media)}
  end

  defp remove_participant(call, participant_id) do
    call = %{call | participants: Enum.reject(call.participants, &(&1.id == participant_id))}
    call = remove_participant_quality(call, participant_id)
    call = remove_participant_reactions(call, participant_id)
    layout = remove_pinned_participant(layout(call), participant_id)

    if layout.focused_participant_id == participant_id do
      %{call | layout: %{layout | focused_participant_id: nil, mode: :auto}}
    else
      %{call | layout: layout}
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

  defp maybe_put_track(call, %{id: nil}), do: call
  defp maybe_put_track(call, track), do: put_track(call, track)

  defp apply_recovery_state(call, payload) do
    recovery = GroupCallShape.normalize_recovery(payload)
    message = recovery.message || recovery_message(recovery.state)

    call = Map.put(call, :recovery, %{recovery | message: message})

    case recovery.state do
      :connected ->
        call
        |> Map.put(:status, :connected)
        |> Map.put(:warning, nil)
        |> Map.put(:error, nil)

      :connecting ->
        call
        |> Map.put(:status, :connecting)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :reconnecting ->
        call
        |> Map.put(:status, :reconnecting)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :rejoining ->
        call
        |> Map.put(:status, :reconnecting)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :negotiating ->
        call
        |> Map.put(:status, :negotiating)
        |> Map.put(:warning, message)
        |> Map.put(:error, nil)

      :failed ->
        call
        |> Map.put(:status, :error)
        |> Map.put(:error, message)
        |> Map.put(:warning, nil)

      _state ->
        call
    end
  end

  defp recovery_message(:connecting),
    do: dgettext("group_call", "Group call media is connecting.")

  defp recovery_message(:reconnecting),
    do: dgettext("group_call", "Group call media connection interrupted. Trying to recover.")

  defp recovery_message(:rejoining),
    do: dgettext("group_call", "Rejoining the media session.")

  defp recovery_message(:negotiating),
    do: dgettext("group_call", "Requesting a fresh media offer.")

  defp recovery_message(:failed),
    do: dgettext("group_call", "Media recovery failed. Retry the media connection.")

  defp recovery_message(_state), do: nil

  defp emit_group_call_recovery_transition(recovery) do
    CallEvents.emit_recovery_transition(:group_call, recovery.state, recovery.reason, %{
      attempt: recovery.attempt,
      max_attempts: recovery.max_attempts,
      next_retry_ms: recovery.next_retry_ms,
      manual_retry: recovery.manual_retry,
      trigger: recovery.trigger
    })
  end

  defp put_participant_quality(call, payload) do
    valid_ids =
      call.participants
      |> Enum.map(& &1.id)
      |> MapSet.new()

    incoming =
      payload
      |> GroupCallShape.value(:participants)
      |> List.wrap()
      |> Enum.map(&GroupCallShape.normalize_participant_quality/1)
      |> Enum.reject(&is_nil(&1.participant_id))
      |> Enum.map(&{&1.participant_id, &1})
      |> Map.new()

    existing = Map.get(call, :participant_quality) || GroupCallShape.empty_participant_quality()

    by_participant =
      existing.by_participant
      |> Map.merge(incoming)
      |> Map.filter(fn {participant_id, _quality} ->
        MapSet.member?(valid_ids, participant_id)
      end)

    active_speaker_id =
      GroupCallShape.normalize_id(GroupCallShape.value(payload, :active_speaker_participant_id))

    active_speaker_id =
      if MapSet.member?(valid_ids, active_speaker_id), do: active_speaker_id, else: nil

    call =
      Map.put(call, :participant_quality, %{
        active_speaker_participant_id: active_speaker_id,
        by_participant: by_participant
      })

    maybe_sync_speaker_focus(call)
  end

  defp remove_participant_quality(call, participant_id) do
    quality = Map.get(call, :participant_quality) || GroupCallShape.empty_participant_quality()
    by_participant = Map.delete(quality.by_participant, participant_id)

    active_speaker_id =
      if quality.active_speaker_participant_id == participant_id,
        do: nil,
        else: quality.active_speaker_participant_id

    Map.put(call, :participant_quality, %{
      active_speaker_participant_id: active_speaker_id,
      by_participant: by_participant
    })
  end

  defp remove_participant_reactions(call, participant_id) do
    Map.update(call, :reactions, [], fn reactions ->
      Enum.reject(reactions || [], &(&1.participant_id == participant_id))
    end)
  end

  defp put_group_call_reaction(call, payload) do
    reaction = GroupCallShape.normalize_group_call_reaction(call, payload)

    if is_nil(reaction.participant_id) do
      call
    else
      reactions =
        call
        |> Map.get(:reactions, [])
        |> Enum.reject(&(&1.participant_id == reaction.participant_id))

      Map.put(call, :reactions, Enum.take([reaction | reactions], 8))
    end
  end

  defp default_prejoin_preferences do
    %{
      media: %{audio: true, video: true},
      layout: default_layout(),
      device_preferences: MediaDevices.no_preference()
    }
  end

  defp normalize_prejoin_preferences(nil), do: default_prejoin_preferences()

  defp normalize_prejoin_preferences(preferences) when is_map(preferences) do
    defaults = default_prejoin_preferences()

    %{
      media:
        defaults.media
        |> Map.merge(normalize_prejoin_media(preferences))
        |> Map.take([:audio, :video]),
      layout:
        defaults.layout
        |> Map.merge(normalize_prejoin_layout(preferences))
        |> Map.take([:mode, :focused_participant_id, :self_view, :mini]),
      device_preferences:
        defaults.device_preferences
        |> Map.merge(MediaDevices.preferences(preferences))
        |> Map.take([:audio_input_id, :video_input_id, :audio_output_id])
    }
  end

  defp normalize_prejoin_preferences(_preferences), do: default_prejoin_preferences()

  defp normalize_prejoin_media(preferences) do
    media = GroupCallShape.value(preferences, :media)

    %{
      audio:
        boolean_preference(
          preference_value(
            GroupCallShape.value(preferences, :audio),
            GroupCallShape.value(media, :audio)
          ),
          true
        ),
      video:
        boolean_preference(
          preference_value(
            GroupCallShape.value(preferences, :video),
            GroupCallShape.value(media, :video)
          ),
          true
        )
    }
  end

  defp normalize_prejoin_layout(preferences) do
    layout = GroupCallShape.value(preferences, :layout)

    mode =
      preference_value(
        GroupCallShape.value(preferences, :layout_mode),
        GroupCallShape.value(layout, :mode)
      )

    self_view =
      preference_value(
        GroupCallShape.value(preferences, :self_view),
        GroupCallShape.value(layout, :self_view)
      )

    %{
      mode: layout_mode(mode),
      focused_participant_id: nil,
      self_view: self_view_mode(self_view),
      mini: false
    }
  end

  defp preference_value(nil, fallback), do: fallback
  defp preference_value(value, _fallback), do: value

  defp load_prejoin_preferences(%{assigns: %{nickname: nickname}} = socket) do
    with persisted when is_map(persisted) <-
           TrustedDevices.get_device_preference(
             socket.assigns[:trusted_device_id],
             nickname,
             @prejoin_preference_namespace
           ) do
      normalize_prejoin_preferences(persisted)
    else
      _missing -> nil
    end
  end

  defp load_prejoin_preferences(_socket), do: nil

  defp maybe_save_prejoin_preferences(
         %{assigns: %{nickname: nickname}} = socket,
         preferences
       ) do
    safe_preferences = persistable_prejoin_preferences(preferences)

    _ =
      TrustedDevices.put_device_preference(
        socket.assigns[:trusted_device_id],
        nickname,
        @prejoin_preference_namespace,
        safe_preferences
      )

    socket
  end

  defp maybe_save_prejoin_preferences(socket, _preferences), do: socket

  # The media defaults belong to the person, not to the door they leave by.
  # Closing the antechamber unmounts this LiveView, so a choice that only lives
  # in `group_call_prejoin_preferences` is gone by the time the antechamber
  # opens again; only the trusted-device record survives that.
  defp remember_prejoin_preferences(
         %{assigns: %{group_call_prejoin: %{}, group_call_prejoin_preferences: preferences}} =
           socket
       )
       when is_map(preferences) do
    maybe_save_prejoin_preferences(socket, preferences)
  end

  defp remember_prejoin_preferences(socket), do: socket

  defp persistable_prejoin_preferences(preferences) do
    preferences = normalize_prejoin_preferences(preferences)

    %{
      "media" => %{
        "audio" => preferences.media.audio,
        "video" => preferences.media.video
      },
      "layout" => %{
        "mode" => Atom.to_string(preferences.layout.mode),
        "self_view" => Atom.to_string(preferences.layout.self_view)
      },
      "device_preferences" => %{
        "audio_input_id" => preferences.device_preferences.audio_input_id,
        "video_input_id" => preferences.device_preferences.video_input_id,
        "audio_output_id" => preferences.device_preferences.audio_output_id
      }
    }
  end

  defp update_prejoin(socket, fun) do
    assign(socket, group_call_prejoin: fun.(socket.assigns.group_call_prejoin))
  end

  defp default_devices, do: MediaDevices.none()

  defp boolean_preference(value, _default) when value in [true, "true", "on", "1", 1], do: true

  defp boolean_preference(value, _default) when value in [false, "false", "off", "0", 0],
    do: false

  defp boolean_preference(_value, default), do: default

  defp layout_mode(mode) when mode in [:auto, :grid, :focus, :sidebar, :speaker], do: mode

  defp layout_mode(mode) when is_binary(mode) and mode in @layout_modes,
    do: String.to_existing_atom(mode)

  defp layout_mode(_mode), do: :auto

  defp self_view_mode(mode) when mode in [:tile, :pip, :hidden], do: mode

  defp self_view_mode(mode) when is_binary(mode) and mode in ~w(tile pip hidden),
    do: String.to_existing_atom(mode)

  defp self_view_mode(_mode), do: :tile

  defp default_layout do
    %{
      mode: :auto,
      focused_participant_id: nil,
      self_view: :tile,
      console_section: :call,
      mini: false,
      pinned_participant_ids: []
    }
  end

  defp layout(%{layout: layout}) when is_map(layout) do
    default_layout()
    |> Map.merge(layout)
    |> Map.update!(:console_section, &GroupCallShape.normalize_console_section/1)
    |> Map.update!(:pinned_participant_ids, &GroupCallShape.normalize_pinned_participant_ids/1)
  end

  defp layout(_call), do: default_layout()

  defp maybe_focus_for_mode(%{mode: :speaker} = layout, call) do
    %{
      layout
      | focused_participant_id:
          active_speaker_participant_id(call) || default_focus_participant_id(call)
    }
  end

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

  defp active_speaker_participant_id(%{
         participant_quality: %{active_speaker_participant_id: id}
       }),
       do: id

  defp active_speaker_participant_id(_call), do: nil

  defp maybe_sync_speaker_focus(%{layout: %{mode: :speaker}} = call) do
    case active_speaker_participant_id(call) do
      participant_id when is_integer(participant_id) ->
        %{call | layout: %{layout(call) | focused_participant_id: participant_id}}

      _missing ->
        call
    end
  end

  defp maybe_sync_speaker_focus(call), do: call

  defp toggle_participant_id(participant_ids, participant_id) do
    participant_ids = GroupCallShape.normalize_pinned_participant_ids(participant_ids)

    if participant_id in participant_ids do
      Enum.reject(participant_ids, &(&1 == participant_id))
    else
      (participant_ids ++ [participant_id])
      |> Enum.uniq()
      |> Enum.take(4)
    end
  end

  defp remove_pinned_participant(layout, participant_id) do
    Map.put(
      layout,
      :pinned_participant_ids,
      layout
      |> Map.get(:pinned_participant_ids, [])
      |> GroupCallShape.normalize_pinned_participant_ids()
      |> Enum.reject(&(&1 == participant_id))
    )
  end

  defp next_layout_mode(current) do
    current_index = Enum.find_index(@layout_modes, &(&1 == current)) || 0
    Enum.at(@layout_modes, rem(current_index + 1, length(@layout_modes)))
  end

  defp next_self_view(current) do
    current_index = Enum.find_index(@self_view_cycle, &(&1 == current)) || 0
    Enum.at(@self_view_cycle, rem(current_index + 1, length(@self_view_cycle)))
  end

  defp next_participant_id([], _current_id), do: nil

  defp next_participant_id(participant_ids, current_id) do
    current_index = Enum.find_index(participant_ids, &(&1 == current_id))
    next_index = rem((current_index || -1) + 1, length(participant_ids))
    Enum.at(participant_ids, next_index)
  end

  defp group_call_layout_payload(call) do
    layout = layout(call)

    %{
      mode: Atom.to_string(layout.mode),
      focused_participant_id: layout.focused_participant_id,
      self_view: Atom.to_string(layout.self_view),
      mini: Map.get(layout, :mini, false),
      pinned_participant_ids: layout.pinned_participant_ids,
      self_participant_id: call.participant_id,
      participants: Enum.map(call.participants || [], &GroupCallShape.participant_payload/1),
      tracks: Enum.map(call.tracks || [], &GroupCallShape.track_payload/1)
    }
  end

  defp put_screen_share_media(call, participant_id, active?) do
    call =
      if call.participant_id == participant_id do
        Map.update(call, :media, %{screen: active?}, &Map.put(&1, :screen, active?))
      else
        call
      end

    update_in(call.participants, fn participants ->
      Enum.map(participants || [], fn
        %{id: id, media_state: media_state} = participant when id == participant_id ->
          %{participant | media_state: Map.put(media_state || %{}, :screen, active?)}

        participant ->
          participant
      end)
    end)
  end

  defp maybe_focus_screen_share(call, participant_id, true) when is_integer(participant_id) do
    %{call | layout: %{layout(call) | mode: :focus, focused_participant_id: participant_id}}
  end

  defp maybe_focus_screen_share(call, _participant_id, _active?), do: call
end
