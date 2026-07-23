defmodule RetroHexChat.GroupCall do
  @moduledoc """
  Public API for the channel-scoped group call bounded context.
  """
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Channels
  alias RetroHexChat.Channels.Membership

  alias RetroHexChat.GroupCall.{
    Audit,
    Config,
    Policy,
    Queries,
    RateLimiter,
    Registry,
    RoomServer,
    RoomSupervisor
  }

  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}

  @pubsub RetroHexChat.PubSub

  @type actor :: %{
          required(:user_id) => integer(),
          required(:nickname) => String.t()
        }

  @spec create_channel_call(String.t(), actor(), keyword()) ::
          {:ok, %{room: Room.t(), token: String.t()}} | {:error, String.t()}
  def create_channel_call(channel_name, actor, opts \\ []) do
    config = Config.from_application_env()

    with :ok <- check_enabled(config),
         :ok <- RateLimiter.check_create_rate(actor.user_id),
         {:ok, channel_state} <- Channels.Server.get_state(channel_name),
         membership = membership_from_channel_state(channel_state),
         :ok <-
           Policy.can_create_channel_call?(
             actor.user_id,
             actor.nickname,
             channel_name,
             membership
           ),
         {:ok, room} <- insert_channel_room(channel_name, actor, config, opts),
         {:ok, _pid} <- ensure_room_server(room) do
      broadcast_channel_call_started(room)
      {:ok, %{room: room, token: room.token}}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("Group call room insert failed: #{inspect(changeset.errors)}")
        {:error, dgettext("group_call", "Could not create group call")}

      {:error, {:already_started, _pid}} ->
        case active_room_for_channel(channel_name) do
          nil -> {:error, dgettext("group_call", "Could not start group call")}
          room -> {:ok, %{room: room, token: room.token}}
        end

      {:error, :not_found} ->
        {:error, dgettext("group_call", "Channel not found")}

      {:error, {:rate_limited, seconds}} ->
        {:error,
         dngettext(
           "group_call",
           "Group call rate limit reached. Try again in %{count} second.",
           "Group call rate limit reached. Try again in %{count} seconds.",
           seconds
         )}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @spec ensure_room_server(Room.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_room_server(%Room{} = room) do
    case Registry.lookup_room({:room, room.token}) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        case RoomSupervisor.start_child(room.token) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  @spec ensure_room_server(String.t()) :: {:ok, pid()} | {:error, :not_found | term()}
  def ensure_room_server(token) do
    case Queries.get_room_by_token(token) do
      nil -> {:error, :not_found}
      room -> ensure_room_server(room)
    end
  end

  @spec join_call(String.t(), actor(), pid(), map(), map()) ::
          {:ok, map()} | {:error, term()}
  def join_call(token, actor, signal_pid, client_info \\ %{}, media_constraints \\ %{}) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.join(token, actor, signal_pid, client_info, media_constraints)
    end
  end

  @spec leave_call(String.t(), integer(), String.t()) :: :ok | {:error, term()}
  def leave_call(token, participant_id, reason \\ "left") do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.leave(token, participant_id, reason)
    end
  end

  @spec answer(String.t(), integer(), String.t()) :: :ok | {:error, term()}
  def answer(token, participant_id, sdp_answer) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.apply_answer(token, participant_id, sdp_answer)
    end
  end

  @spec add_ice_candidate(String.t(), integer(), map()) :: :ok | {:error, term()}
  def add_ice_candidate(token, participant_id, candidate) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.add_ice_candidate(token, participant_id, candidate)
    end
  end

  @spec request_offer(String.t(), integer()) :: :ok | {:error, term()}
  def request_offer(token, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.request_offer(token, participant_id)
    end
  end

  @spec set_media_state(String.t(), integer(), map()) :: :ok | {:error, term()}
  def set_media_state(token, participant_id, media_state) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_media_state(token, participant_id, media_state)
    end
  end

  @spec set_screen_share_state(String.t(), integer(), boolean(), map()) ::
          {:ok, map()} | {:error, term()}
  def set_screen_share_state(token, participant_id, active?, screen_info \\ %{}) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_screen_share_state(token, participant_id, active?, screen_info)
    end
  end

  @spec close_call(String.t(), actor(), String.t()) :: :ok | {:error, term()}
  def close_call(token, actor, reason \\ "moderation") do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.close(token, actor, reason)
    end
  end

  @spec kick_participant(String.t(), actor(), integer()) :: :ok | {:error, term()}
  def kick_participant(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.kick_participant(token, actor, participant_id)
    end
  end

  @spec force_kick_participant(String.t(), actor(), integer(), String.t()) ::
          :ok | {:error, term()}
  def force_kick_participant(token, actor, participant_id, reason \\ "kicked") do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.force_kick_participant(token, actor, participant_id, reason)
    end
  end

  @spec mute_participant(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def mute_participant(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_participant_audio(token, actor, participant_id, false)
    end
  end

  @spec unmute_participant(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def unmute_participant(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_participant_audio(token, actor, participant_id, true)
    end
  end

  @spec block_participant_video(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def block_participant_video(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_participant_video(token, actor, participant_id, false)
    end
  end

  @spec unblock_participant_video(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def unblock_participant_video(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_participant_video(token, actor, participant_id, true)
    end
  end

  @spec block_participant_screen_share(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def block_participant_screen_share(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_participant_screen_share(token, actor, participant_id, false)
    end
  end

  @spec unblock_participant_screen_share(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def unblock_participant_screen_share(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_participant_screen_share(token, actor, participant_id, true)
    end
  end

  @spec mute_all_participants(String.t(), actor()) :: {:ok, map()} | {:error, term()}
  def mute_all_participants(token, actor) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_all_participants_media(token, actor, :audio, false)
    end
  end

  @spec block_all_participant_videos(String.t(), actor()) :: {:ok, map()} | {:error, term()}
  def block_all_participant_videos(token, actor) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_all_participants_media(token, actor, :video, false)
    end
  end

  @spec lock_call(String.t(), actor()) :: {:ok, map()} | {:error, term()}
  def lock_call(token, actor) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_locked(token, actor, true)
    end
  end

  @spec unlock_call(String.t(), actor()) :: {:ok, map()} | {:error, term()}
  def unlock_call(token, actor) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_locked(token, actor, false)
    end
  end

  @spec set_hand_raised(String.t(), actor(), integer(), boolean()) ::
          {:ok, Participant.t()} | {:error, term()}
  def set_hand_raised(token, actor, participant_id, raised?) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.set_hand_raised(token, actor, participant_id, raised?)
    end
  end

  @spec allow_participant_speak(String.t(), actor(), integer()) ::
          {:ok, Participant.t()} | {:error, term()}
  def allow_participant_speak(token, actor, participant_id) do
    with {:ok, _pid} <- ensure_room_server(token) do
      RoomServer.allow_participant_speak(token, actor, participant_id)
    end
  end

  @spec send_reaction(String.t(), actor(), integer(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def send_reaction(token, actor, participant_id, reaction) do
    with {:ok, _pid} <- ensure_room_server(token),
         :ok <- RateLimiter.check_reaction_rate(token, actor.user_id) do
      RoomServer.send_reaction(token, actor, participant_id, reaction)
    end
  end

  @spec get_summary(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_summary(token) do
    case RoomServer.summary(token) do
      {:ok, _summary} = ok ->
        ok

      {:error, :not_found} ->
        with {:ok, room} <- get_room(token) do
          participants = Queries.list_active_participants(room.id)
          tracks = Queries.list_active_tracks(room.id)

          {:ok,
           %{
             room: %{
               id: room.id,
               token: room.token,
               channel_name: room.channel_name,
               status: room.status,
               max_participants: room.max_participants,
               metadata: room.metadata,
               inserted_at: room.inserted_at,
               opened_at: room.opened_at,
               activated_at: room.activated_at
             },
             participants: participants,
             pending_participants: [],
             tracks: tracks,
             server_stats: persisted_server_stats(room, participants, tracks)
           }}
        end
    end
  end

  @spec create_room(map()) :: {:ok, Room.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_room(attrs), to: Queries, as: :insert_room

  @spec get_room(String.t()) :: {:ok, Room.t()} | {:error, :not_found}
  def get_room(token) do
    case Queries.get_room_by_token(token) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  @spec active_room_for_channel(String.t()) :: Room.t() | nil
  defdelegate active_room_for_channel(channel_name), to: Queries, as: :get_active_room_for_channel

  @spec active_room_exists?(String.t()) :: boolean()
  defdelegate active_room_exists?(channel_name), to: Queries

  @spec update_room_status(Room.t(), String.t(), map()) ::
          {:ok, Room.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_room_status(room, new_status, extra_attrs \\ %{}), to: Queries

  @spec add_participant(map()) :: {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  defdelegate add_participant(attrs), to: Queries, as: :insert_participant

  @spec active_participant(integer(), String.t()) :: Participant.t() | nil
  defdelegate active_participant(room_id, nickname), to: Queries, as: :get_active_participant

  @spec list_active_participants(integer()) :: [Participant.t()]
  defdelegate list_active_participants(room_id), to: Queries

  @spec update_participant_status(Participant.t(), String.t(), map()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_participant_status(participant, new_status, extra_attrs \\ %{}), to: Queries

  @spec add_track(map()) :: {:ok, Track.t()} | {:error, Ecto.Changeset.t()}
  defdelegate add_track(attrs), to: Queries, as: :insert_track

  @spec list_active_tracks(integer()) :: [Track.t()]
  defdelegate list_active_tracks(room_id), to: Queries

  @spec update_track_status(Track.t(), String.t(), map()) ::
          {:ok, Track.t()} | {:error, Ecto.Changeset.t()}
  defdelegate update_track_status(track, new_status, extra_attrs \\ %{}), to: Queries

  defp persisted_server_stats(room, participants, tracks) do
    %{
      updated_at_ms: System.os_time(:millisecond),
      room: %{
        status: room.status,
        max_participants: room.max_participants,
        participant_count: length(participants),
        pending_count: 0,
        track_count: length(tracks),
        audio_track_count: Enum.count(tracks, &(&1.kind == "audio")),
        video_track_count: Enum.count(tracks, &(&1.kind == "video")),
        screen_track_count: Enum.count(tracks, &(&1.kind == "video" and &1.source == "screen"))
      },
      peers: [],
      totals: %{
        peer_count: 0,
        connected_peer_count: 0,
        connecting_peer_count: 0,
        failed_peer_count: 0,
        inbound_track_count: 0,
        outbound_peer_count: 0,
        subscriber_count: 0,
        inbound_packets: 0,
        inbound_bytes: 0,
        outbound_packets: 0,
        outbound_bytes: 0,
        nack_count: 0,
        pli_count: 0,
        candidate_pair_count: 0,
        nominated_pair_count: 0,
        valid_pair_count: 0,
        ice_packets_sent: 0,
        ice_packets_received: 0,
        ice_bytes_sent: 0,
        ice_bytes_received: 0
      }
    }
  end

  defp check_enabled(%{enabled?: true}), do: :ok
  defp check_enabled(_config), do: {:error, dgettext("group_call", "Group calls are disabled")}

  defp insert_channel_room(channel_name, actor, config, opts) do
    token = Keyword.get_lazy(opts, :token, &generate_token/0)
    title = Keyword.get(opts, :title)
    now = DateTime.utc_now()

    Queries.insert_room(%{
      token: token,
      channel_name: channel_name,
      creator_id: actor.user_id,
      creator_nick: actor.nickname,
      title: title,
      status: "open",
      max_participants: config.max_participants,
      media_policy: %{"audio" => true, "video" => true},
      codec_policy: %{"audio" => "opus", "video" => "vp8"},
      ice_policy: %{"transport_policy" => Atom.to_string(config.ice_transport_policy)},
      metadata:
        Audit.append(%{}, :conference_started, %{
          actor: actor.nickname,
          channel: channel_name
        }),
      opened_at: now,
      last_activity_at: now
    })
  end

  defp generate_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp broadcast_channel_call_started(room) do
    Phoenix.PubSub.broadcast(@pubsub, "channel:#{room.channel_name}", {
      :group_call_started,
      %{
        channel: room.channel_name,
        token: room.token,
        event: Audit.last_event(room.metadata)
      }
    })
  end

  defp membership_from_channel_state(%{members: members}) do
    Enum.reduce(members, Membership.new(), fn {nickname, role}, membership ->
      Membership.add(membership, nickname, role)
    end)
  end
end
