defmodule RetroHexChat.Channels.Server do
  @moduledoc """
  GenServer managing state for a single IRC channel.
  Process-per-channel architecture (Constitution III).

  Each channel gets its own process that tracks membership, modes,
  bans, and topic. All mutations go through this process to ensure
  serialized access to channel state.
  """
  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Channels.{Events, Membership, Modes, Policy, Queries, Registry}
  alias RetroHexChat.Chat
  alias RetroHexChat.Services.ChanServ

  @type state :: %{
          name: String.t(),
          topic: String.t(),
          membership: Membership.t(),
          modes: Modes.t(),
          bans: MapSet.t(String.t()),
          registered: boolean(),
          created_at: DateTime.t()
        }

  @pubsub RetroHexChat.PubSub

  # ──────────────────────────────────────────────────────────────
  # Public API
  # ──────────────────────────────────────────────────────────────

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(channel_name) do
    GenServer.start_link(__MODULE__, channel_name, name: Registry.via_tuple(channel_name))
  end

  @doc """
  Join a channel. The first user to join becomes operator.
  Returns `{:ok, state_map}` on success.
  """
  @spec join(String.t(), String.t(), String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def join(channel_name, nickname, password \\ nil) do
    GenServer.call(via(channel_name), {:join, nickname, password})
  end

  @doc """
  Leave a channel. If the channel becomes empty and is not registered,
  the process will stop itself.
  """
  @spec part(String.t(), String.t(), String.t() | nil) :: :ok | {:error, String.t()}
  def part(channel_name, nickname, reason \\ nil) do
    GenServer.call(via(channel_name), {:part, nickname, reason})
  end

  @doc """
  Send a message to the channel. The message is broadcast via PubSub.
  """
  @spec send_message(String.t(), String.t(), String.t(), atom()) :: :ok | {:error, String.t()}
  def send_message(channel_name, nickname, content, type \\ :message) do
    GenServer.call(via(channel_name), {:send_message, nickname, content, type})
  end

  @doc """
  Get the current state of a channel.
  """
  @spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_state(channel_name) do
    case Registry.lookup(channel_name) do
      {:ok, _pid} -> {:ok, GenServer.call(via(channel_name), :get_state)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Set channel modes. Requires operator privilege.
  """
  @spec set_mode(String.t(), String.t(), String.t(), [String.t()]) ::
          :ok | {:error, String.t()}
  def set_mode(channel_name, nickname, mode_string, params \\ []) do
    GenServer.call(via(channel_name), {:set_mode, nickname, mode_string, params})
  end

  @doc """
  Kick a user from the channel. Requires operator privilege.
  """
  @spec kick(String.t(), String.t(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def kick(channel_name, operator_nick, target_nick, reason \\ nil) do
    GenServer.call(via(channel_name), {:kick, operator_nick, target_nick, reason})
  end

  @doc """
  Ban a user from the channel. Requires operator privilege.
  """
  @spec ban(String.t(), String.t(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def ban(channel_name, operator_nick, target_nick, reason \\ nil) do
    GenServer.call(via(channel_name), {:ban, operator_nick, target_nick, reason})
  end

  @doc """
  Rename a user in the channel membership (for nick changes).
  """
  @spec rename_user(String.t(), String.t(), String.t()) :: :ok
  def rename_user(channel_name, old_nick, new_nick) do
    GenServer.call(via(channel_name), {:rename_user, old_nick, new_nick})
  end

  @doc """
  Set the channel topic. Respects topic_lock mode.
  """
  @spec set_topic(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def set_topic(channel_name, nickname, topic) do
    GenServer.call(via(channel_name), {:set_topic, nickname, topic})
  end

  # ──────────────────────────────────────────────────────────────
  # GenServer Callbacks
  # ──────────────────────────────────────────────────────────────

  @impl true
  def init(channel_name) do
    state = %{
      name: channel_name,
      topic: "",
      membership: Membership.new(),
      modes: Modes.new(),
      bans: MapSet.new(),
      registered: false,
      created_at: DateTime.utc_now()
    }

    {:ok, load_persisted_state(state)}
  end

  @impl true
  def handle_call({:join, nickname, password}, _from, state) do
    with :ok <- check_not_banned(state, nickname),
         :ok <- check_not_member(state, nickname),
         :ok <- Policy.can_join?(state.modes, state.membership, password) do
      role = determine_join_role(state, nickname)
      new_membership = Membership.add(state.membership, nickname, role)
      new_state = %{state | membership: new_membership}

      broadcast(state.name, {:user_joined, %{nickname: nickname, role: role}})

      {:reply, {:ok, state_to_map(new_state)}, new_state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:part, nickname, reason}, _from, state) do
    if Membership.member?(state.membership, nickname) do
      new_membership = Membership.remove(state.membership, nickname)
      new_state = %{state | membership: new_membership}

      broadcast(state.name, {:user_left, %{nickname: nickname, reason: reason}})

      if Membership.count(new_membership) == 0 and not state.registered do
        {:stop, :normal, :ok, new_state}
      else
        {:reply, :ok, new_state}
      end
    else
      {:reply, {:error, "Not in channel"}, state}
    end
  end

  def handle_call({:send_message, nickname, content, type}, _from, state) do
    with :ok <- RetroHexChat.Chat.Policy.validate_content(content),
         :ok <- Policy.can_speak?(state.modes, state.membership, nickname) do
      {id, timestamp} = persist_and_get_id(state.name, nickname, content, type)

      broadcast(
        state.name,
        %{
          event: "new_message",
          payload: %{
            id: id,
            channel: state.name,
            author: nickname,
            content: content,
            type: type,
            timestamp: timestamp
          }
        }
      )

      {:reply, :ok, state}
    else
      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state_to_map(state), state}
  end

  def handle_call({:set_mode, nickname, mode_string, params}, _from, state) do
    with true <- Policy.operator?(state.membership, nickname),
         {:ok, new_membership} <- apply_user_modes(state.membership, mode_string, params),
         {:ok, new_modes} <- Modes.apply_changes(state.modes, mode_string, params) do
      new_state = %{state | modes: new_modes, membership: new_membership}

      Events.emit_mode_changed(state.name, mode_string, nickname)

      broadcast(
        state.name,
        {:mode_changed, %{nickname: nickname, mode_string: mode_string, params: params}}
      )

      {:reply, :ok, new_state}
    else
      false -> {:reply, {:error, "You must be a channel operator to change modes"}, state}
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:kick, operator_nick, target_nick, reason}, _from, state) do
    cond do
      not Policy.operator?(state.membership, operator_nick) ->
        {:reply, {:error, "You must be a channel operator to kick users"}, state}

      not Membership.member?(state.membership, target_nick) ->
        {:reply, {:error, "User #{target_nick} is not in channel"}, state}

      true ->
        new_membership = Membership.remove(state.membership, target_nick)
        new_state = %{state | membership: new_membership}

        broadcast(
          state.name,
          {:user_kicked,
           %{
             operator: operator_nick,
             target: target_nick,
             reason: reason
           }}
        )

        if Membership.count(new_membership) == 0 and not state.registered do
          {:stop, :normal, :ok, new_state}
        else
          {:reply, :ok, new_state}
        end
    end
  end

  def handle_call({:ban, operator_nick, target_nick, reason}, _from, state) do
    if Policy.operator?(state.membership, operator_nick) do
      new_bans = MapSet.put(state.bans, target_nick)
      new_state = %{state | bans: new_bans}

      broadcast(
        state.name,
        {:user_banned,
         %{
           operator: operator_nick,
           target: target_nick,
           reason: reason
         }}
      )

      # Eject banned user from channel if currently a member
      new_state =
        if Membership.member?(new_state.membership, target_nick) do
          new_membership = Membership.remove(new_state.membership, target_nick)

          broadcast(
            state.name,
            {:user_kicked, %{operator: operator_nick, target: target_nick, reason: "Banned"}}
          )

          %{new_state | membership: new_membership}
        else
          new_state
        end

      {:reply, :ok, new_state}
    else
      {:reply, {:error, "You must be a channel operator to ban users"}, state}
    end
  end

  def handle_call({:rename_user, old_nick, new_nick}, _from, state) do
    new_membership = Membership.rename(state.membership, old_nick, new_nick)
    {:reply, :ok, %{state | membership: new_membership}}
  end

  def handle_call({:set_topic, nickname, topic}, _from, state) do
    case Policy.can_change_topic?(state.modes, state.membership, nickname) do
      :ok ->
        new_state = %{state | topic: topic}

        Events.emit_topic_changed(state.name, topic, nickname)

        broadcast(
          state.name,
          {:topic_changed,
           %{
             nickname: nickname,
             topic: topic
           }}
        )

        {:reply, :ok, new_state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  # ──────────────────────────────────────────────────────────────
  # Private Helpers
  # ──────────────────────────────────────────────────────────────

  defp apply_user_modes(membership, mode_string, params) do
    mode_string
    |> extract_user_modes(params)
    |> Enum.reduce_while({:ok, membership}, &apply_single_user_mode/2)
  end

  defp apply_single_user_mode({target, role}, {:ok, mem}) do
    if Membership.member?(mem, target) do
      {:cont, {:ok, Membership.set_role(mem, target, role)}}
    else
      {:halt, {:error, "User #{target} is not in channel"}}
    end
  end

  defp extract_user_modes(mode_string, params) do
    case String.split(mode_string, "", trim: true) do
      ["+" | flags] -> collect_user_flags(:add, flags, params)
      ["-" | flags] -> collect_user_flags(:remove, flags, params)
      _ -> []
    end
  end

  defp collect_user_flags(action, flags, params) do
    {changes, _rest} =
      Enum.reduce(flags, {[], params}, fn flag, {acc, remaining} ->
        process_user_flag(action, flag, acc, remaining)
      end)

    Enum.reverse(changes)
  end

  defp process_user_flag(:add, "o", acc, [nick | rest]), do: {[{nick, :operator} | acc], rest}
  defp process_user_flag(:remove, "o", acc, [nick | rest]), do: {[{nick, :regular} | acc], rest}
  defp process_user_flag(:add, "v", acc, [nick | rest]), do: {[{nick, :voiced} | acc], rest}
  defp process_user_flag(:remove, "v", acc, [nick | rest]), do: {[{nick, :regular} | acc], rest}
  defp process_user_flag(:add, "k", acc, [_ | rest]), do: {acc, rest}
  defp process_user_flag(:add, "l", acc, [_ | rest]), do: {acc, rest}
  defp process_user_flag(_, flag, acc, []) when flag in ~w(o v k l), do: {acc, []}
  defp process_user_flag(_, _, acc, remaining), do: {acc, remaining}

  defp via(channel_name), do: Registry.via_tuple(channel_name)

  defp broadcast(channel_name, message) do
    case Phoenix.PubSub.broadcast(@pubsub, "channel:#{channel_name}", message) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("PubSub broadcast to channel:#{channel_name} failed: #{inspect(reason)}")
    end
  end

  defp state_to_map(state) do
    %{
      name: state.name,
      topic: state.topic,
      members: Membership.to_list(state.membership),
      member_count: Membership.count(state.membership),
      operators: Membership.operators(state.membership),
      modes: Modes.to_string(state.modes),
      bans: MapSet.to_list(state.bans),
      created_at: state.created_at
    }
  end

  defp check_not_banned(state, nickname) do
    if MapSet.member?(state.bans, nickname) do
      {:error, "You are banned from #{state.name}"}
    else
      :ok
    end
  end

  defp check_not_member(state, nickname) do
    if Membership.member?(state.membership, nickname) do
      {:error, "Already in channel"}
    else
      :ok
    end
  end

  defp persist_and_get_id(channel_name, nickname, content, type) do
    case Chat.Queries.insert_message(%{
           channel_name: channel_name,
           author_nickname: nickname,
           content: content,
           type: to_string(type)
         }) do
      {:ok, message} ->
        {message.id, message.inserted_at}

      {:error, changeset} ->
        Logger.warning("Failed to persist message in #{channel_name}: #{inspect(changeset)}")
        {"msg-#{System.unique_integer([:positive])}", DateTime.utc_now()}
    end
  rescue
    e ->
      Logger.warning("Failed to persist message in #{channel_name}: #{inspect(e)}")
      {"msg-#{System.unique_integer([:positive])}", DateTime.utc_now()}
  end

  defp load_persisted_state(state) do
    case Queries.load_persisted_state(state.name) do
      nil ->
        state

      persisted ->
        modes = apply_persisted_modes(state.modes, persisted)
        bans = persisted.bans |> MapSet.new()

        %{state | topic: persisted.topic, modes: modes, bans: bans, registered: true}
    end
  rescue
    e ->
      Logger.warning("Failed to load persisted state for #{state.name}: #{inspect(e)}")
      state
  catch
    kind, reason ->
      Logger.warning(
        "Failed to load persisted state for #{state.name}: #{kind} #{inspect(reason)}"
      )

      state
  end

  defp apply_persisted_modes(modes, persisted) do
    modes
    |> maybe_apply_mode_string(persisted.modes)
    |> maybe_set_key(persisted.mode_key)
    |> maybe_set_limit(persisted.mode_limit)
  end

  defp maybe_apply_mode_string(modes, nil), do: modes
  defp maybe_apply_mode_string(modes, ""), do: modes

  defp maybe_apply_mode_string(modes, mode_string) do
    case Modes.apply_changes(modes, mode_string) do
      {:ok, new_modes} -> new_modes
      _ -> modes
    end
  end

  defp maybe_set_key(modes, nil), do: modes
  defp maybe_set_key(modes, key), do: %{modes | key: key}

  defp maybe_set_limit(modes, nil), do: modes
  defp maybe_set_limit(modes, limit), do: %{modes | limit: limit}

  defp determine_join_role(state, nickname) do
    cond do
      Membership.count(state.membership) == 0 and not state.registered ->
        :operator

      state.registered ->
        access_level_to_role(state.name, nickname)

      true ->
        :regular
    end
  end

  defp access_level_to_role(channel_name, nickname) do
    case ChanServ.check_access(channel_name, nickname) do
      {:ok, level} when level in ["founder", "sop"] -> :operator
      {:ok, "aop"} -> :operator
      {:ok, "vop"} -> :voiced
      _ -> :regular
    end
  rescue
    e ->
      Logger.warning(
        "Failed to check access level for #{nickname} in #{channel_name}: #{inspect(e)}"
      )

      :regular
  end
end
