defmodule RetroHexChat.VirtualSpace.SessionServer do
  @moduledoc """
  GenServer managing a single virtual space session.

  Holds the hot state of the world: participants (position, direction, pose,
  online flag), the map definition and the expiry timers. The database keeps
  only audit and macro status; movement and presence never touch it.

  Participants are keyed by a stable `participant_key`
  (`"registered:<user_id>"`), so a reconnect of the same user takes over the
  existing entry and keeps its position. Offline participants stay in the hot
  state until the session ends, which lets a reload land on the same tile.
  """
  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Policy
  alias RetroHexChat.VirtualSpace.Queries
  alias RetroHexChat.VirtualSpace.Registry
  alias RetroHexChat.VirtualSpace.Schema.Session

  @pending_timeout :timer.minutes(5)

  @pubsub RetroHexChat.PubSub

  @type participant :: %{
          key: String.t(),
          user_id: integer(),
          nickname: String.t(),
          role: :creator | :participant,
          x: integer(),
          y: integer(),
          dir: String.t(),
          pose: String.t(),
          seat_id: String.t() | nil,
          zone_id: String.t() | nil,
          online?: boolean(),
          muted?: boolean(),
          input_seq: integer(),
          joined_at: DateTime.t(),
          last_seen_at: DateTime.t()
        }

  # --- Public API ---

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(token) do
    GenServer.start_link(__MODULE__, token, name: Registry.via_tuple(token))
  end

  @spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_state(token) do
    call(token, :get_state)
  end

  @spec join(String.t(), %{user_id: integer(), nickname: String.t()}) ::
          {:ok, %{participant: participant(), snapshot: map()}} | {:error, atom()}
  def join(token, participant_context) do
    call(token, {:join, participant_context})
  end

  @type input_payload :: %{
          required(:seq) => integer(),
          required(:dx) => integer(),
          required(:dy) => integer(),
          optional(:client_time) => integer()
        }

  @type input_error ::
          :not_found
          | :not_participant
          | :terminal
          | :invalid_step
          | :cooldown
          | :out_of_bounds
          | :blocked

  @spec input(String.t(), String.t(), input_payload()) :: :ok | {:error, input_error()}
  def input(token, participant_key, payload) do
    call(token, {:input, participant_key, payload})
  end

  @spec leave(String.t(), String.t()) :: :ok
  def leave(token, participant_key) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.cast(pid, {:leave, participant_key})
      {:error, :not_found} -> :ok
    end
  end

  @spec close(String.t(), String.t()) :: :ok | {:error, :not_found}
  def close(token, reason) do
    case Registry.lookup(token) do
      {:ok, pid} -> call_close(pid, reason)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec session_summary(String.t()) :: {:ok, map()} | {:error, :not_found}
  def session_summary(token) do
    call(token, :session_summary)
  end

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  def snapshot(token) do
    call(token, :snapshot)
  end

  # The Registry entry outlives the process for a moment (monitor-based
  # cleanup), so a call can still hit a dead pid — treat it as not_found.
  defp call(token, message) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.call(pid, message)
      {:error, :not_found} -> {:error, :not_found}
    end
  catch
    :exit, {:noproc, _call} -> {:error, :not_found}
    :exit, {:normal, _call} -> {:error, :not_found}
  end

  defp call_close(pid, reason) do
    GenServer.call(pid, {:close, reason})
  catch
    :exit, :normal -> {:error, :not_found}
    :exit, {:normal, _call} -> {:error, :not_found}
    :exit, {:noproc, _call} -> {:error, :not_found}
  end

  # --- GenServer callbacks ---

  @impl true
  def init(token) do
    case Queries.get_session_by_token(token) do
      nil ->
        {:stop, :session_not_found}

      session ->
        if Session.terminal?(session.status) do
          :ignore
        else
          init_state(token, session)
        end
    end
  end

  defp init_state(token, session) do
    case SpaceMap.get(session.map_id) do
      {:error, :unknown_map} ->
        {:stop, :unknown_map}

      {:ok, map_definition} ->
        state = %{
          token: token,
          session: session,
          map: map_definition,
          blocked: SpaceMap.collision_set(map_definition),
          participants: %{},
          seats: %{},
          timers: %{}
        }

        state =
          if session.status == "pending" do
            schedule_timeout(state, :pending_expiry, pending_timeout())
          else
            state
          end

        state = schedule_session_expiry(state)

        Logger.info("VirtualSpace SessionServer started: token=#{token}")
        {:ok, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:join, context}, _from, state) do
    key = participant_key(context)
    returning = Map.get(state.participants, key)
    active_count = online_count(state)

    case Policy.check_capacity(state.session, active_count, returning != nil) do
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      :ok ->
        {participant, state} = do_join(state, key, context, returning)

        reply = %{participant: participant, snapshot: build_snapshot(state), map: state.map}
        {:reply, {:ok, reply}, state}
    end
  end

  def handle_call(:session_summary, _from, state) do
    {:reply, {:ok, build_summary(state)}, state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, build_snapshot(state)}, state}
  end

  def handle_call({:input, key, payload}, _from, state) do
    case apply_input(state, key, payload) do
      {:ok, state} -> {:reply, :ok, state}
      {:error, reason, state} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:close, reason}, _from, state) do
    state = do_end(state, "closed", reason)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_cast({:leave, participant_key}, state) do
    case Map.get(state.participants, participant_key) do
      nil ->
        {:noreply, state}

      participant ->
        updated = %{participant | online?: false, last_seen_at: DateTime.utc_now()}
        state = put_in(state.participants[participant_key], updated)

        broadcast(state.token, "space_participant_left", %{
          key: participant_key,
          nickname: participant.nickname
        })

        update_participant_counts(state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:timeout, :pending_expiry}, state) do
    if state.session.status == "pending" do
      {:stop, :normal, do_end(state, "expired", "pending_timeout")}
    else
      {:noreply, state}
    end
  end

  def handle_info({:timeout, :session_expiry}, state) do
    if Session.terminal?(state.session.status) do
      {:noreply, state}
    else
      {:stop, :normal, do_end(state, "expired", "expired")}
    end
  end

  # --- Private helpers ---

  defp participant_key(%{user_id: user_id}), do: "registered:#{user_id}"

  defp do_join(state, key, context, nil) do
    {x, y, dir} = pick_spawn(state)

    participant = %{
      key: key,
      user_id: context.user_id,
      nickname: context.nickname,
      role: role_for(state.session, context.user_id),
      avatar: avatar_for(state, key),
      x: x,
      y: y,
      dir: dir,
      pose: "standing",
      seat_id: nil,
      zone_id: nil,
      moving?: false,
      online?: true,
      muted?: false,
      input_seq: 0,
      last_input_at: nil,
      joined_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    }

    state = put_in(state.participants[key], participant)
    state = maybe_activate(state)

    broadcast(state.token, "space_participant_joined", %{
      key: key,
      nickname: participant.nickname
    })

    update_participant_counts(state)
    {participant, state}
  end

  defp do_join(state, key, context, returning) do
    participant = %{
      returning
      | nickname: context.nickname,
        online?: true,
        last_seen_at: DateTime.utc_now()
    }

    state = put_in(state.participants[key], participant)
    state = maybe_activate(state)

    broadcast(state.token, "space_participant_joined", %{
      key: key,
      nickname: participant.nickname
    })

    update_participant_counts(state)
    {participant, state}
  end

  defp maybe_activate(%{session: %{status: "pending"}} = state) do
    state = cancel_timer(state, :pending_expiry)

    {:ok, session} =
      Queries.update_status(state.session, "active", %{
        activated_at: DateTime.utc_now(),
        last_activity_at: DateTime.utc_now()
      })

    %{state | session: session}
  end

  defp maybe_activate(state), do: state

  # Authoritative movement: validate a single cardinal step and either apply it
  # (broadcast a delta) or reject it. Bounds/collision rejections still publish a
  # correction delta so the client can reconcile its local prediction; malformed
  # or cooled-down inputs are dropped silently.
  defp apply_input(state, key, payload) do
    participant = Map.get(state.participants, key)

    cond do
      Session.terminal?(state.session.status) ->
        {:error, :terminal, state}

      participant == nil or not participant.online? ->
        {:error, :not_participant, state}

      not valid_step?(payload) ->
        {:error, :invalid_step, state}

      not cooldown_elapsed?(participant) ->
        {:error, :cooldown, state}

      true ->
        resolve_step(state, key, participant, payload)
    end
  end

  defp resolve_step(state, key, participant, payload) do
    target_x = participant.x + payload.dx
    target_y = participant.y + payload.dy
    dir = step_dir(payload.dx, payload.dy)

    cond do
      not in_bounds?(state.map, target_x, target_y) ->
        state = broadcast_correction(state, key, participant, payload.seq)
        {:error, :out_of_bounds, state}

      MapSet.member?(state.blocked, {target_x, target_y}) ->
        state = broadcast_correction(state, key, participant, payload.seq)
        {:error, :blocked, state}

      true ->
        moved = %{
          participant
          | x: target_x,
            y: target_y,
            dir: dir,
            zone_id: zone_at(state.map, target_x, target_y),
            last_input_at: mono_ms(),
            input_seq: payload.seq
        }

        state = put_in(state.participants[key], moved)
        state = broadcast_delta(state, key, moved, payload.seq)
        {:ok, state}
    end
  end

  # A rejected step keeps the official position; echo it back so the client snaps
  # its mispredicted avatar to truth.
  defp broadcast_correction(state, key, participant, seq) do
    broadcast_delta(state, key, %{participant | dir: participant.dir}, seq)
  end

  defp broadcast_delta(state, key, participant, seq) do
    payload = %{
      server_time: System.system_time(:millisecond),
      seq_ack: %{key => seq},
      updates: %{key => participant_view(participant)},
      joined: %{},
      left: []
    }

    broadcast(state.token, "space_delta", payload)
    state
  end

  defp valid_step?(%{dx: dx, dy: dy})
       when dx in [-1, 0, 1] and dy in [-1, 0, 1],
       do: abs(dx) + abs(dy) == 1

  defp valid_step?(_), do: false

  defp step_dir(1, 0), do: "right"
  defp step_dir(-1, 0), do: "left"
  defp step_dir(0, 1), do: "down"
  defp step_dir(0, -1), do: "up"

  defp in_bounds?(map, x, y) do
    x >= 0 and y >= 0 and x < map.width and y < map.height
  end

  defp zone_at(map, x, y) do
    Enum.find_value(map.zones, fn zone ->
      if x >= zone.x and x < zone.x + zone.w and y >= zone.y and y < zone.y + zone.h,
        do: zone.id
    end)
  end

  defp cooldown_elapsed?(participant) do
    case participant.last_input_at do
      nil -> true
      last -> mono_ms() - last >= step_ms()
    end
  end

  defp mono_ms, do: System.monotonic_time(:millisecond)

  defp step_ms, do: Application.get_env(:retro_hex_chat, :virtual_space_step_ms, 150)

  defp pick_spawn(state) do
    occupied =
      state.participants
      |> Map.values()
      |> MapSet.new(&{&1.x, &1.y})

    free =
      Enum.find(state.map.spawn, fn spawn ->
        not MapSet.member?(occupied, {spawn.x, spawn.y})
      end)

    spawn = free || List.first(state.map.spawn)
    {spawn.x, spawn.y, spawn.dir}
  end

  defp role_for(session, user_id) do
    if session.creator_id == user_id, do: :creator, else: :participant
  end

  # Deterministic avatar assignment so a reconnect keeps the same look and two
  # people rarely clash. Must stay in sync with `AVATAR_IDS` in the JS atlas.
  @avatars ~w(mage_blue mage_green rogue_red bard_gold)
  defp avatar_for(state, key) do
    index = rem(:erlang.phash2(key), length(@avatars))

    taken =
      state.participants
      |> Map.values()
      |> MapSet.new(&Map.get(&1, :avatar))

    @avatars
    |> Stream.drop(index)
    |> Stream.concat(@avatars)
    |> Enum.find(@avatars |> List.first(), &(&1 not in taken))
  end

  defp online_count(state) do
    state.participants |> Map.values() |> Enum.count(& &1.online?)
  end

  # Wire-protocol snapshot (see `js/lib/space/protocol.js`): a server timestamp
  # plus participants keyed by participant key, each in the public view shape.
  defp build_snapshot(state) do
    participants =
      Map.new(state.participants, fn {key, participant} ->
        {key, participant_view(participant)}
      end)

    %{server_time: System.system_time(:millisecond), participants: participants}
  end

  # Internal participant → public view: clean JSON keys, no bang atoms, no
  # server-only fields (channel_pid, input_seq, timestamps).
  defp participant_view(participant) do
    %{
      key: participant.key,
      nickname: participant.nickname,
      avatar: Map.get(participant, :avatar, "default"),
      x: participant.x,
      y: participant.y,
      dir: participant.dir,
      moving: Map.get(participant, :moving?, false),
      pose: participant.pose,
      seat_id: participant.seat_id,
      zone_id: participant.zone_id,
      muted: participant.muted?,
      online: participant.online?
    }
  end

  defp build_summary(state) do
    %{
      kind: :space,
      token: state.token,
      status: state.session.status,
      terminal?: Session.terminal?(state.session.status),
      title: state.session.title,
      map_id: state.session.map_id,
      channel_name: state.session.channel_name,
      creator_nick: state.session.creator_nick,
      participant_count: online_count(state),
      max_participants: state.session.max_participants,
      created_at: state.session.inserted_at,
      expires_at: state.session.expires_at,
      closed_at: state.session.closed_at,
      closed_reason: state.session.closed_reason
    }
  end

  defp update_participant_counts(state) do
    count = online_count(state)
    peak = max(state.session.peak_participants, count)

    {:ok, _} =
      Queries.update_status(state.session, state.session.status, %{
        last_participant_count: count,
        peak_participants: peak,
        last_activity_at: DateTime.utc_now()
      })

    :ok
  end

  defp do_end(state, status, reason) do
    Logger.info("VirtualSpace #{status}: token=#{state.token}, reason=#{reason}")
    state = cancel_all_timers(state)

    {:ok, session} =
      Queries.update_status(state.session, status, %{
        closed_at: DateTime.utc_now(),
        closed_reason: reason,
        last_participant_count: online_count(state)
      })

    broadcast(state.token, "space_closed", %{reason: reason, status: status})
    %{state | session: session}
  end

  defp schedule_session_expiry(%{session: %{expires_at: nil}} = state), do: state

  defp schedule_session_expiry(state) do
    delay = max(DateTime.diff(state.session.expires_at, DateTime.utc_now(), :millisecond), 0)
    schedule_timeout(state, :session_expiry, delay)
  end

  defp schedule_timeout(state, name, delay) do
    ref = Process.send_after(self(), {:timeout, name}, delay)
    put_in(state.timers[name], ref)
  end

  defp cancel_timer(state, name) do
    case Map.get(state.timers, name) do
      nil ->
        state

      ref ->
        Process.cancel_timer(ref)
        put_in(state.timers[name], nil)
    end
  end

  defp cancel_all_timers(state) do
    Enum.reduce(Map.keys(state.timers), state, &cancel_timer(&2, &1))
  end

  defp broadcast(token, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "space:#{token}", %{event: event, payload: payload})
  end

  defp pending_timeout,
    do: Application.get_env(:retro_hex_chat, :virtual_space_pending_timeout, @pending_timeout)
end
