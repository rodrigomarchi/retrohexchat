defmodule RetroHexChat.VirtualSpace.SessionServer do
  @moduledoc """
  GenServer managing one channel-backed virtual space runtime.

  Holds the hot state of the world: participants (position, direction, pose,
  online flag) and the map definition. The runtime is ephemeral and mirrors
  membership from `RetroHexChat.Channels.Server`.

  Participants are keyed by a stable `participant_key`
  (`"nick:<nickname>"`) so channel events and socket joins address the same
  avatar.
  """
  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Registry

  @pubsub RetroHexChat.PubSub

  @type participant :: %{
          key: String.t(),
          user_id: integer() | nil,
          nickname: String.t(),
          role: :participant | :bot,
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

  @spec start_link({:channel, String.t()}) :: GenServer.on_start()
  def start_link({:channel, channel_name} = arg) do
    GenServer.start_link(__MODULE__, arg,
      name: Registry.via_tuple({:channel_space, channel_name})
    )
  end

  @spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_state(channel_name) do
    call(channel_name, :get_state)
  end

  @spec join(String.t(), %{user_id: integer() | nil, nickname: String.t()}) ::
          {:ok, %{participant: participant(), snapshot: map(), map: map()}} | {:error, atom()}
  def join(channel_name, participant_context) do
    call(channel_name, {:join, participant_context})
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
          | :invalid_step
          | :cooldown
          | :out_of_bounds
          | :blocked

  @spec input(String.t(), String.t(), input_payload()) :: :ok | {:error, input_error()}
  def input(channel_name, participant_key, payload) do
    call(channel_name, {:input, participant_key, payload})
  end

  @type interact_payload :: %{
          optional(:seq) => integer(),
          required(:kind) => String.t(),
          required(:target_id) => String.t()
        }

  @spec interact(String.t(), String.t(), interact_payload()) ::
          :ok
          | {:ok, %{modal: map()}}
          | {:error, :not_found | :not_participant | :invalid_target | :too_far | :seat_taken}
  def interact(channel_name, participant_key, payload) do
    call(channel_name, {:interact, participant_key, payload})
  end

  @spec chat_bubble(String.t(), String.t(), String.t()) :: :ok | {:error, :not_found}
  def chat_bubble(channel_name, participant_key, text) do
    call(channel_name, {:chat_bubble, participant_key, text})
  end

  @type actor :: %{
          required(:user_id) => integer(),
          optional(:nickname) => String.t(),
          optional(:is_admin) => boolean(),
          optional(:is_server_operator) => boolean()
        }

  @spec admin_action(String.t(), actor(), map()) :: {:error, :not_found | :forbidden}
  def admin_action(channel_name, _actor, _action) do
    call(channel_name, :admin_action)
  end

  @spec leave(String.t(), String.t()) :: :ok
  def leave(channel_name, participant_key) do
    case Registry.lookup({:channel_space, channel_name}) do
      {:ok, pid} -> GenServer.cast(pid, {:leave, participant_key})
      {:error, :not_found} -> :ok
    end
  end

  @spec leave_channel_viewer(String.t()) :: :ok
  def leave_channel_viewer(channel_name) do
    case Registry.lookup({:channel_space, channel_name}) do
      {:ok, pid} -> GenServer.cast(pid, :viewer_left)
      {:error, :not_found} -> :ok
    end
  end

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  def snapshot(channel_name) do
    call(channel_name, :snapshot)
  end

  # The Registry entry outlives the process for a moment (monitor-based
  # cleanup), so a call can still hit a dead pid — treat it as not_found.
  defp call(channel_name, message) do
    case Registry.lookup({:channel_space, channel_name}) do
      {:ok, pid} -> GenServer.call(pid, message)
      {:error, :not_found} -> {:error, :not_found}
    end
  catch
    :exit, {:noproc, _call} -> {:error, :not_found}
    :exit, {:normal, _call} -> {:error, :not_found}
  end

  # --- GenServer callbacks ---

  @impl true
  def init({:channel, channel_name}) do
    init_channel_state(channel_name)
  end

  defp init_channel_state(channel_name) do
    case SpaceMap.get("elfic_forest") do
      {:error, :unknown_map} ->
        {:stop, :unknown_map}

      {:ok, map_definition} ->
        Phoenix.PubSub.subscribe(@pubsub, "channel:#{channel_name}")

        state = %{
          kind: :channel,
          channel_name: channel_name,
          session: channel_session(channel_name),
          map: map_definition,
          blocked: SpaceMap.collision_set(map_definition),
          participants: %{},
          seats: %{},
          viewer_count: 0
        }

        state = sync_channel_members(state)

        Logger.info("VirtualSpace channel runtime started: channel=#{channel_name}")
        {:ok, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:join, context}, _from, state) do
    state = sync_channel_members(state)
    key = channel_participant_key(context.nickname)

    case Map.get(state.participants, key) do
      nil ->
        {:reply, {:error, :not_in_channel}, state}

      participant ->
        state = %{state | viewer_count: state.viewer_count + 1}
        reply = %{participant: participant, snapshot: build_snapshot(state), map: state.map}
        {:reply, {:ok, reply}, state}
    end
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

  def handle_call({:interact, key, payload}, _from, state) do
    do_interact(state, key, payload)
  end

  def handle_call({:chat_bubble, _key, _text}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(:admin_action, _from, state) do
    {:reply, {:error, :forbidden}, state}
  end

  @impl true
  def handle_cast(:viewer_left, state) do
    viewer_count = max(state.viewer_count - 1, 0)
    state = %{state | viewer_count: viewer_count}

    if viewer_count == 0 do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:leave, participant_key}, state) do
    case Map.get(state.participants, participant_key) do
      nil ->
        {:noreply, state}

      participant ->
        state = free_seat(state, participant)
        updated = %{participant | online?: false, seat_id: nil, last_seen_at: DateTime.utc_now()}
        state = put_in(state.participants[participant_key], updated)

        broadcast(state.channel_name, "space_participant_left", %{
          key: participant_key,
          nickname: participant.nickname
        })

        broadcast_presence_left(state, participant_key)
        state = update_participant_counts(state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:user_joined, %{nickname: nickname, role: role}}, state) do
    {:noreply, add_channel_member(state, nickname, role)}
  end

  def handle_info({:user_left, %{nickname: nickname}}, state) do
    {:noreply, remove_channel_member(state, nickname)}
  end

  def handle_info({:user_kicked, %{target: nickname}}, state) do
    {:noreply, remove_channel_member(state, nickname)}
  end

  def handle_info(
        {:nick_changed, %{old_nick: old_nick, new_nick: new_nick}},
        state
      ) do
    old_key = channel_participant_key(old_nick)
    old = Map.get(state.participants, old_key)
    state = remove_channel_member(state, old_nick)
    state = add_channel_member(state, new_nick, :participant, old)
    {:noreply, state}
  end

  def handle_info(
        %{event: "new_message", payload: %{author: author, content: content, type: type}},
        state
      ) do
    if public_channel_message?(type) do
      broadcast_channel_bubble(state, author, content)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  # --- Private helpers ---

  defp channel_session(channel_name) do
    %{
      status: "active",
      creator_id: nil,
      creator_nick: nil,
      title: channel_name,
      channel_name: channel_name,
      map_id: "elfic_forest",
      max_participants: :infinity,
      peak_participants: 0,
      last_participant_count: 0,
      metadata: %{},
      inserted_at: DateTime.utc_now(),
      expires_at: nil,
      closed_at: nil,
      closed_reason: nil
    }
  end

  defp sync_channel_members(%{kind: :channel, channel_name: channel_name} = state) do
    case ChannelServer.get_state(channel_name) do
      {:ok, %{members: members}} ->
        current_keys =
          members
          |> Enum.map(fn {nick, _role} -> channel_participant_key(nick) end)
          |> MapSet.new()

        state =
          state.participants
          |> Map.keys()
          |> Enum.reject(&MapSet.member?(current_keys, &1))
          |> Enum.reduce(state, &remove_channel_member_by_key/2)

        Enum.reduce(members, state, fn {nick, role}, acc ->
          add_channel_member(acc, nick, role)
        end)

      {:error, :not_found} ->
        state
    end
  end

  defp sync_channel_members(state), do: state

  defp remove_channel_member_by_key(key, state) do
    case Map.fetch(state.participants, key) do
      {:ok, participant} -> remove_channel_member(state, participant.nickname)
      :error -> state
    end
  end

  defp add_channel_member(state, nickname, role, previous \\ nil) do
    key = channel_participant_key(nickname)

    if Map.has_key?(state.participants, key) do
      update_in(state.participants[key], fn participant ->
        %{participant | nickname: nickname, role: channel_role(role), online?: true}
      end)
    else
      {x, y, dir} =
        case previous do
          %{x: x, y: y, dir: dir} -> {x, y, dir}
          _ -> pick_spawn(state)
        end

      participant = %{
        key: key,
        user_id: nil,
        nickname: nickname,
        role: channel_role(role),
        avatar: avatar_for(state, key),
        x: x,
        y: y,
        dir: dir,
        pose: "standing",
        seat_id: nil,
        zone_id: zone_at(state.map, x, y),
        moving?: false,
        online?: true,
        muted?: false,
        input_seq: 0,
        last_input_at: nil,
        chat_times: [],
        joined_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      }

      state = put_in(state.participants[key], participant)
      broadcast_presence_join(state, key, participant)
      update_participant_counts(state)
    end
  end

  defp remove_channel_member(state, nickname) do
    key = channel_participant_key(nickname)

    case Map.get(state.participants, key) do
      nil ->
        state

      participant ->
        state =
          state
          |> free_seat(participant)
          |> update_in([:participants], &Map.delete(&1, key))

        broadcast_presence_left(state, key)
        update_participant_counts(state)
    end
  end

  defp channel_role(:bot), do: :bot
  defp channel_role(_), do: :participant

  defp channel_participant_key(nickname) do
    normalized = nickname |> to_string() |> String.downcase()
    "nick:#{normalized}"
  end

  defp public_channel_message?(type) when type in [:message, :action, "message", "action"],
    do: true

  defp public_channel_message?(_), do: false

  defp broadcast_channel_bubble(state, author, content) do
    key = channel_participant_key(author)

    case Map.get(state.participants, key) do
      nil ->
        :ok

      participant ->
        broadcast(state.channel_name, "space_message", %{
          key: key,
          nickname: participant.nickname,
          text: normalize_text(content)
        })
    end
  end

  # Authoritative movement: validate a single cardinal step and either apply it
  # (broadcast a delta) or reject it. Bounds/collision rejections still publish a
  # correction delta so the client can reconcile its local prediction; malformed
  # or cooled-down inputs are dropped silently.
  defp apply_input(state, key, payload) do
    participant = Map.get(state.participants, key)

    cond do
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
        state = free_seat(state, participant)
        new_zone = zone_at(state.map, target_x, target_y)

        moved = %{
          participant
          | x: target_x,
            y: target_y,
            dir: dir,
            pose: "standing",
            seat_id: nil,
            zone_id: new_zone,
            last_input_at: mono_ms(),
            input_seq: payload.seq
        }

        state = put_in(state.participants[key], moved)
        state = maybe_broadcast_zone(state, key, participant.zone_id, new_zone)
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

    broadcast(state.channel_name, "space_delta", payload)
    state
  end

  # Presence deltas so every other client's engine adds/removes the participant
  # (the named space_participant_joined/left events carry only the nickname).
  defp broadcast_presence_join(state, key, participant) do
    broadcast(state.channel_name, "space_delta", %{
      server_time: System.system_time(:millisecond),
      seq_ack: %{},
      updates: %{},
      joined: %{key => participant_view(participant)},
      left: []
    })
  end

  defp broadcast_presence_left(state, key) do
    broadcast(state.channel_name, "space_delta", %{
      server_time: System.system_time(:millisecond),
      seq_ack: %{},
      updates: %{},
      joined: %{},
      left: [key]
    })
  end

  defp valid_step?(%{dx: dx, dy: dy})
       when dx in [-1, 0, 1] and dy in [-1, 0, 1],
       do: abs(dx) + abs(dy) == 1

  defp valid_step?(_), do: false

  # --- Interactions (seats, boards) ---

  defp do_interact(state, key, %{kind: "sit", target_id: seat_id}) do
    participant = Map.get(state.participants, key)
    seat = Enum.find(state.map.seats, &(&1.id == seat_id))

    cond do
      not active_participant?(participant) -> {:reply, {:error, :not_participant}, state}
      seat == nil -> {:reply, {:error, :invalid_target}, state}
      seat_taken?(state, seat_id, key) -> {:reply, {:error, :seat_taken}, state}
      not adjacent?(participant, seat) -> {:reply, {:error, :too_far}, state}
      true -> sit(state, key, participant, seat)
    end
  end

  defp do_interact(state, key, %{kind: "stand"}) do
    participant = Map.get(state.participants, key)

    if active_participant?(participant) do
      stand(state, key, participant)
    else
      {:reply, {:error, :not_participant}, state}
    end
  end

  defp do_interact(state, key, %{kind: "use", target_id: id}) do
    participant = Map.get(state.participants, key)
    target = Enum.find(state.map.interactables, &(&1.id == id))

    cond do
      not active_participant?(participant) -> {:reply, {:error, :not_participant}, state}
      target == nil -> {:reply, {:error, :invalid_target}, state}
      not adjacent?(participant, target) -> {:reply, {:error, :too_far}, state}
      true -> {:reply, {:ok, %{modal: modal_of(target)}}, state}
    end
  end

  defp do_interact(state, _key, _payload), do: {:reply, {:error, :invalid_target}, state}

  defp sit(state, key, participant, seat) do
    state = free_seat(state, participant)

    seated = %{
      participant
      | x: seat.x,
        y: seat.y,
        dir: seat.dir,
        pose: "sitting",
        seat_id: seat.id,
        zone_id: zone_at(state.map, seat.x, seat.y)
    }

    state = put_in(state.participants[key], seated)
    state = put_in(state.seats[seat.id], key)
    state = broadcast_delta(state, key, seated, seated.input_seq)
    {:reply, :ok, state}
  end

  defp stand(state, key, participant) do
    state = free_seat(state, participant)
    stood = %{participant | pose: "standing", seat_id: nil}
    state = put_in(state.participants[key], stood)
    state = broadcast_delta(state, key, stood, stood.input_seq)
    {:reply, :ok, state}
  end

  defp free_seat(state, %{seat_id: nil}), do: state

  defp free_seat(state, %{seat_id: seat_id}) do
    update_in(state.seats, &Map.delete(&1, seat_id))
  end

  defp seat_taken?(state, seat_id, key) do
    case Map.get(state.seats, seat_id) do
      nil -> false
      ^key -> false
      _other -> true
    end
  end

  defp adjacent?(participant, %{x: x, y: y}) do
    abs(participant.x - x) <= 1 and abs(participant.y - y) <= 1
  end

  defp active_participant?(nil), do: false
  defp active_participant?(%{online?: online?}), do: online?

  defp modal_of(%{title: title, modal: modal}) do
    %{title: title, kind: Map.get(modal, :kind, "image"), asset: Map.get(modal, :asset)}
  end

  defp normalize_text(text) when is_binary(text) do
    text
    |> String.replace(~r/\p{C}/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp normalize_text(_), do: ""

  # --- Zones ---

  defp maybe_broadcast_zone(state, _key, same, same), do: state

  defp maybe_broadcast_zone(state, key, from, to) do
    broadcast(state.channel_name, "space_zone_changed", %{key: key, zone_id: to, from: from})
    state
  end

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

    pick_seed_spawn(state, occupied, true, true) ||
      pick_spiral_spawn(state, occupied, true, true) ||
      pick_seed_spawn(state, occupied, false, true) ||
      pick_spiral_spawn(state, occupied, false, true) ||
      pick_seed_spawn(state, occupied, true, false) ||
      pick_spiral_spawn(state, occupied, true, false) ||
      pick_seed_spawn(state, occupied, false, false) ||
      pick_spiral_spawn(state, occupied, false, false) ||
      fallback_walkable_spawn(state)
  end

  defp pick_seed_spawn(state, occupied, participant_clear?, visual_clear?) do
    state.map.spawn
    |> Enum.find(
      &spawn_available?(state, occupied, &1.x, &1.y, participant_clear?, visual_clear?)
    )
    |> case do
      nil -> nil
      spawn -> {spawn.x, spawn.y, spawn.dir}
    end
  end

  defp pick_spiral_spawn(state, occupied, participant_clear?, visual_clear?) do
    {origin_x, origin_y} = spawn_origin(state.map.spawn)
    max_radius = max(state.map.width, state.map.height)

    1..max_radius
    |> Stream.flat_map(&spiral_ring(origin_x, origin_y, &1))
    |> Enum.find(fn {x, y} ->
      spawn_available?(state, occupied, x, y, participant_clear?, visual_clear?)
    end)
    |> case do
      nil -> nil
      {x, y} -> {x, y, "down"}
    end
  end

  defp spawn_origin(spawns) do
    xs = Enum.map(spawns, & &1.x)
    ys = Enum.map(spawns, & &1.y)
    {div(Enum.min(xs) + Enum.max(xs), 2), div(Enum.min(ys) + Enum.max(ys), 2)}
  end

  defp spiral_ring(origin_x, origin_y, radius) do
    for y <- (origin_y - radius)..(origin_y + radius),
        x <- (origin_x - radius)..(origin_x + radius),
        max(abs(x - origin_x), abs(y - origin_y)) == radius do
      {x, y}
    end
  end

  defp spawn_available?(state, occupied, x, y) do
    in_bounds?(state.map, x, y) and not MapSet.member?(state.blocked, {x, y}) and
      not MapSet.member?(occupied, {x, y})
  end

  defp spawn_available?(state, occupied, x, y, participant_clear?, visual_clear?) do
    spawn_available?(state, occupied, x, y) and
      (not participant_clear? or clear_of_occupied?(occupied, x, y)) and
      (not visual_clear? or clear_of_static_obstacles?(state, x, y))
  end

  defp clear_of_occupied?(occupied, x, y) do
    Enum.all?(occupied, fn {occupied_x, occupied_y} ->
      max(abs(x - occupied_x), abs(y - occupied_y)) > 1
    end)
  end

  # Avatars are two tiles tall and labels sit just above them. For spawn points,
  # prefer cells whose immediate visual column does not overlap market crates,
  # benches, walls, or other static collision cells.
  defp clear_of_static_obstacles?(state, x, y) do
    Enum.all?((y - 2)..y, fn tile_y ->
      Enum.all?((x - 1)..(x + 1), fn tile_x ->
        not in_bounds?(state.map, tile_x, tile_y) or
          not MapSet.member?(state.blocked, {tile_x, tile_y})
      end)
    end)
  end

  defp fallback_walkable_spawn(state) do
    state.map.spawn
    |> Enum.find(&walkable?(state, &1.x, &1.y))
    |> case do
      nil -> {0, 0, "down"}
      spawn -> {spawn.x, spawn.y, spawn.dir}
    end
  end

  defp walkable?(state, x, y) do
    in_bounds?(state.map, x, y) and not MapSet.member?(state.blocked, {x, y})
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

  defp update_participant_counts(state) do
    count = online_count(state)

    session = %{
      state.session
      | last_participant_count: count,
        peak_participants: max(Map.get(state.session, :peak_participants, 0), count)
    }

    %{state | session: session}
  end

  defp broadcast(channel_name, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "space:#{channel_name}", %{event: event, payload: payload})
  end
end
