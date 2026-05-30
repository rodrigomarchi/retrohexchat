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

  alias RetroHexChat.Channels.{Events, Masks, Membership, Modes, Policy, Queries, Registry}
  alias RetroHexChat.Chat
  alias RetroHexChat.Chat.Formatter
  alias RetroHexChat.Services.ChanServ
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @type state :: %{
          name: String.t(),
          topic: String.t(),
          topic_set_by: String.t() | nil,
          topic_set_at: DateTime.t() | nil,
          membership: Membership.t(),
          modes: Modes.t(),
          bans: MapSet.t(String.t()),
          ban_exceptions: MapSet.t(String.t()),
          invite_exceptions: MapSet.t(String.t()),
          registered: boolean(),
          created_at: DateTime.t(),
          join_timestamps: [DateTime.t()],
          last_activity_touched_at: DateTime.t() | nil
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
  Join a channel. The first user to join becomes owner.
  Returns `{:ok, state_map}` on success.
  """
  @spec join(String.t(), String.t(), String.t() | nil, keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def join(channel_name, nickname, password \\ nil, opts \\ []) do
    identified = Keyword.get(opts, :identified, false)
    bot = Keyword.get(opts, :bot, false)
    GenServer.call(via(channel_name), {:join, nickname, password, identified, bot})
  end

  @doc """
  Leave a channel. If the channel becomes empty and is not registered,
  the process will stop itself.
  """
  @spec part(String.t(), String.t(), String.t() | nil) :: :ok | {:error, String.t()}
  def part(channel_name, nickname, reason \\ nil) do
    case Registry.lookup(channel_name) do
      {:ok, pid} -> GenServer.call(pid, {:part, nickname, reason})
      {:error, :not_found} -> {:error, "Channel not found"}
    end
  catch
    :exit, _reason -> {:error, "Channel not found"}
  end

  @doc """
  Send a message to the channel. The message is broadcast via PubSub.
  """
  @spec send_message(String.t(), String.t(), String.t(), atom() | keyword()) ::
          :ok | {:error, String.t()}
  def send_message(channel_name, nickname, content, type_or_opts \\ :message) do
    {type, opts} =
      if is_list(type_or_opts) do
        {:message, type_or_opts}
      else
        {type_or_opts, []}
      end

    GenServer.call(via(channel_name), {:send_message, nickname, content, type, opts})
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
  Set channel modes. Requires appropriate privilege level.
  """
  @spec set_mode(String.t(), String.t(), String.t(), [String.t()]) ::
          :ok | {:error, String.t()}
  def set_mode(channel_name, nickname, mode_string, params \\ []) do
    GenServer.call(via(channel_name), {:set_mode, nickname, mode_string, params})
  end

  @doc """
  Kick a user from the channel. Requires sufficient rank.
  """
  @spec kick(String.t(), String.t(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def kick(channel_name, operator_nick, target_nick, reason \\ nil) do
    GenServer.call(via(channel_name), {:kick, operator_nick, target_nick, reason})
  end

  @doc """
  Ban a user from the channel. Requires operator or owner.
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

  @doc "Add a ban exception. Requires operator privilege."
  @spec add_ban_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def add_ban_exception(channel_name, operator_nick, target_nick) do
    GenServer.call(via(channel_name), {:add_ban_exception, operator_nick, target_nick})
  end

  @doc "Remove a ban exception. Requires operator privilege."
  @spec remove_ban_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def remove_ban_exception(channel_name, operator_nick, target_nick) do
    GenServer.call(via(channel_name), {:remove_ban_exception, operator_nick, target_nick})
  end

  @doc "Add an invite exception. Requires operator privilege."
  @spec add_invite_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def add_invite_exception(channel_name, operator_nick, target_nick) do
    GenServer.call(via(channel_name), {:add_invite_exception, operator_nick, target_nick})
  end

  @doc "Remove an invite exception. Requires operator privilege."
  @spec remove_invite_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def remove_invite_exception(channel_name, operator_nick, target_nick) do
    GenServer.call(via(channel_name), {:remove_invite_exception, operator_nick, target_nick})
  end

  @doc "Remove a ban (unban). Requires operator privilege."
  @spec unban(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def unban(channel_name, operator_nick, target_nick) do
    GenServer.call(via(channel_name), {:unban, operator_nick, target_nick})
  end

  @doc "Knock on an invite-only channel. Channel must be +i and not +K."
  @spec knock(String.t(), String.t(), String.t() | nil) :: :ok | {:error, String.t()}
  def knock(channel_name, nickname, message \\ nil) do
    GenServer.call(via(channel_name), {:knock, nickname, message})
  end

  @doc "Set the welcome message for a channel."
  @spec set_welcome(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def set_welcome(channel_name, message, set_by) do
    GenServer.call(via(channel_name), {:set_welcome, message, set_by})
  end

  @doc "Clear the welcome message for a channel."
  @spec clear_welcome(String.t(), String.t()) :: :ok | {:error, String.t()}
  def clear_welcome(channel_name, cleared_by) do
    GenServer.call(via(channel_name), {:clear_welcome, cleared_by})
  end

  @doc "Get the welcome message for a channel."
  @spec get_welcome(String.t()) :: {:ok, %{message: String.t(), set_by: String.t()}} | {:ok, nil}
  def get_welcome(channel_name) do
    GenServer.call(via(channel_name), :get_welcome)
  end

  @doc "Mute a user in the channel. Requires operator privilege."
  @spec channel_mute(String.t(), String.t(), String.t(), non_neg_integer() | :permanent) ::
          :ok | {:error, String.t()}
  def channel_mute(channel_name, operator_nick, target_nick, duration \\ :permanent) do
    GenServer.call(via(channel_name), {:channel_mute, operator_nick, target_nick, duration})
  end

  @doc "Unmute a user in the channel. Requires operator privilege."
  @spec channel_unmute(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def channel_unmute(channel_name, operator_nick, target_nick) do
    GenServer.call(via(channel_name), {:channel_unmute, operator_nick, target_nick})
  end

  @doc "Transfer channel ownership to another member."
  @spec transfer_ownership(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def transfer_ownership(channel_name, current_owner, new_owner) do
    GenServer.call(via(channel_name), {:transfer_ownership, current_owner, new_owner})
  end

  @doc "Mark a live channel process as registered after ChanServ registration."
  @spec mark_registered(String.t()) :: :ok | {:error, String.t()}
  def mark_registered(channel_name) do
    case Registry.lookup(channel_name) do
      {:ok, pid} -> GenServer.call(pid, :mark_registered)
      {:error, :not_found} -> {:error, "Channel not found"}
    end
  catch
    :exit, _reason -> {:error, "Channel not found"}
  end

  # ──────────────────────────────────────────────────────────────
  # GenServer Callbacks
  # ──────────────────────────────────────────────────────────────

  @impl true
  def init(channel_name) do
    state = %{
      name: channel_name,
      topic: "",
      topic_set_by: nil,
      topic_set_at: nil,
      membership: Membership.new(),
      modes: Modes.new(),
      bans: MapSet.new(),
      ban_exceptions: MapSet.new(),
      invite_exceptions: MapSet.new(),
      registered: false,
      created_at: DateTime.utc_now(),
      join_timestamps: [],
      channel_mutes: MapSet.new(),
      welcome_message: nil,
      last_activity_touched_at: nil
    }

    {:ok, load_persisted_state(state) |> load_welcome_message()}
  end

  @impl true
  def handle_call({:join, nickname, password, identified, bot}, _from, state) do
    with :ok <- check_not_banned(state, nickname),
         :ok <- check_not_member(state, nickname),
         :ok <-
           (if bot do
              :ok
            else
              Policy.can_join?(
                state.modes,
                state.membership,
                password,
                nickname,
                state.invite_exceptions,
                identified
              )
            end),
         :ok <- if(bot, do: :ok, else: check_join_throttle(state, nickname)) do
      role = if bot, do: :bot, else: determine_join_role(state, nickname)
      new_membership = Membership.add(state.membership, nickname, role)
      new_timestamps = [DateTime.utc_now() | state.join_timestamps]
      new_state = %{state | membership: new_membership, join_timestamps: new_timestamps}

      broadcast(
        state.name,
        {:user_joined, %{channel: state.name, nickname: nickname, role: role}}
      )

      new_state = maybe_touch_activity(new_state)
      {:reply, {:ok, state_to_map(new_state)}, new_state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  # Backwards-compatible 4-arg join (no bot flag)
  def handle_call({:join, nickname, password, identified}, _from, state)
      when is_boolean(identified) do
    handle_call({:join, nickname, password, identified, false}, {:join_compat, nil}, state)
  end

  # Backwards-compatible 3-arg join (no identified flag)
  def handle_call({:join, nickname, password}, _from, state) do
    handle_call({:join, nickname, password, false, false}, {:join_compat, nil}, state)
  end

  def handle_call({:part, nickname, reason}, _from, state) do
    if Membership.member?(state.membership, nickname) do
      new_membership = Membership.remove(state.membership, nickname)
      new_state = %{state | membership: new_membership}

      broadcast(
        state.name,
        {:user_left, %{channel: state.name, nickname: nickname, reason: reason}}
      )

      if Membership.count(new_membership) == 0 and not state.registered do
        {:stop, :normal, :ok, new_state}
      else
        {:reply, :ok, new_state}
      end
    else
      {:reply, {:error, "Not in channel"}, state}
    end
  end

  def handle_call({:send_message, nickname, content, type, opts}, _from, state) do
    with :ok <- RetroHexChat.Chat.Policy.validate_content(content),
         :ok <- Policy.can_speak?(state.modes, state.membership, nickname),
         :ok <- check_channel_mute(state, nickname) do
      final_content =
        if Modes.strip_colors?(state.modes) do
          Formatter.strip(content)
        else
          content
        end

      reply_to_id = Keyword.get(opts, :reply_to_id)

      {msg, id, timestamp} =
        persist_and_get_id(state.name, nickname, final_content, type, reply_to_id)

      payload = %{
        id: id,
        channel: state.name,
        author: nickname,
        content: final_content,
        type: type,
        timestamp: timestamp,
        reply_to_id: msg && msg.reply_to_id,
        reply_to_author: msg && msg.reply_to_author,
        reply_to_preview: msg && msg.reply_to_preview
      }

      broadcast(state.name, %{event: "new_message", payload: payload})

      {:reply, :ok, maybe_touch_activity(state)}
    else
      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  # Backward compat: old 4-element tuple without opts
  def handle_call({:send_message, nickname, content, type}, from, state) do
    handle_call({:send_message, nickname, content, type, []}, from, state)
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state_to_map(state), state}
  end

  def handle_call({:set_mode, nickname, mode_string, params}, _from, state) do
    {ban_ops, clean_mode_string, clean_params} =
      extract_ban_operations(mode_string, params)

    with :ok <- check_mode_permissions(state.membership, nickname, mode_string, params),
         {:ok, new_state} <- apply_ban_operations(ban_ops, nickname, state),
         {:ok, new_membership} <-
           apply_user_modes(new_state.membership, clean_mode_string, clean_params),
         {:ok, new_modes} <-
           Modes.apply_changes(new_state.modes, clean_mode_string, clean_params) do
      new_state = %{new_state | modes: new_modes, membership: new_membership}

      Events.emit_mode_changed(state.name, mode_string, nickname)

      broadcast(
        state.name,
        {:mode_changed,
         %{channel: state.name, nickname: nickname, mode_string: mode_string, params: params}}
      )

      {:reply, :ok, new_state}
    else
      {:error, _} = err -> {:reply, err, state}
    end
  end

  def handle_call({:kick, actor_nick, target_nick, reason}, _from, state) do
    case Policy.can_kick?(state.membership, actor_nick, target_nick) do
      :ok ->
        new_membership = Membership.remove(state.membership, target_nick)
        new_state = %{state | membership: new_membership}

        broadcast(
          state.name,
          {:user_kicked,
           %{
             operator: actor_nick,
             target: target_nick,
             reason: reason
           }}
        )

        if Membership.count(new_membership) == 0 and not state.registered do
          {:stop, :normal, :ok, new_state}
        else
          {:reply, :ok, new_state}
        end

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:ban, actor_nick, target_nick, reason}, _from, state) do
    case Policy.can_ban?(state.membership, actor_nick, target_nick) do
      :ok ->
        new_bans = MapSet.put(state.bans, target_nick)
        new_state = %{state | bans: new_bans}

        maybe_persist_ban(:add, state.name, target_nick, actor_nick, reason, state)

        broadcast(
          state.name,
          {:user_banned,
           %{
             channel: state.name,
             operator: actor_nick,
             target: target_nick,
             reason: reason
           }}
        )

        new_state = eject_ban_matches(new_state, actor_nick, target_nick, "Banned")

        {:reply, :ok, new_state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:rename_user, old_nick, new_nick}, _from, state) do
    new_membership = Membership.rename(state.membership, old_nick, new_nick)
    {:reply, :ok, %{state | membership: new_membership}}
  end

  def handle_call({:set_topic, nickname, topic}, _from, state) do
    case Policy.can_change_topic?(state.modes, state.membership, nickname) do
      :ok ->
        now = DateTime.utc_now()

        new_state = %{
          state
          | topic: topic,
            topic_set_by: nickname,
            topic_set_at: now
        }

        Events.emit_topic_changed(state.name, topic, nickname)

        broadcast(
          state.name,
          {:topic_changed,
           %{
             channel: state.name,
             nickname: nickname,
             topic: topic,
             set_at: now
           }}
        )

        {:reply, :ok, new_state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:add_ban_exception, operator_nick, target_nick}, _from, state) do
    if Policy.operator?(state.membership, operator_nick) do
      new_exceptions = MapSet.put(state.ban_exceptions, target_nick)
      new_state = %{state | ban_exceptions: new_exceptions}

      maybe_persist_exception(:ban_exception, :add, state.name, target_nick, operator_nick, state)

      broadcast(
        state.name,
        {:ban_exception_added,
         %{channel: state.name, nickname: target_nick, added_by: operator_nick}}
      )

      {:reply, :ok, new_state}
    else
      {:reply, {:error, "You must be a channel operator"}, state}
    end
  end

  def handle_call({:remove_ban_exception, operator_nick, target_nick}, _from, state) do
    if Policy.operator?(state.membership, operator_nick) do
      new_exceptions = MapSet.delete(state.ban_exceptions, target_nick)
      new_state = %{state | ban_exceptions: new_exceptions}

      maybe_persist_exception(
        :ban_exception,
        :remove,
        state.name,
        target_nick,
        operator_nick,
        state
      )

      broadcast(
        state.name,
        {:ban_exception_removed,
         %{channel: state.name, nickname: target_nick, removed_by: operator_nick}}
      )

      {:reply, :ok, new_state}
    else
      {:reply, {:error, "You must be a channel operator"}, state}
    end
  end

  def handle_call({:add_invite_exception, operator_nick, target_nick}, _from, state) do
    if Policy.operator?(state.membership, operator_nick) do
      new_exceptions = MapSet.put(state.invite_exceptions, target_nick)
      new_state = %{state | invite_exceptions: new_exceptions}

      maybe_persist_exception(
        :invite_exception,
        :add,
        state.name,
        target_nick,
        operator_nick,
        state
      )

      broadcast(
        state.name,
        {:invite_exception_added,
         %{channel: state.name, nickname: target_nick, added_by: operator_nick}}
      )

      {:reply, :ok, new_state}
    else
      {:reply, {:error, "You must be a channel operator"}, state}
    end
  end

  def handle_call({:remove_invite_exception, operator_nick, target_nick}, _from, state) do
    if Policy.operator?(state.membership, operator_nick) do
      new_exceptions = MapSet.delete(state.invite_exceptions, target_nick)
      new_state = %{state | invite_exceptions: new_exceptions}

      maybe_persist_exception(
        :invite_exception,
        :remove,
        state.name,
        target_nick,
        operator_nick,
        state
      )

      broadcast(
        state.name,
        {:invite_exception_removed,
         %{channel: state.name, nickname: target_nick, removed_by: operator_nick}}
      )

      {:reply, :ok, new_state}
    else
      {:reply, {:error, "You must be a channel operator"}, state}
    end
  end

  def handle_call({:unban, operator_nick, target_nick}, _from, state) do
    if Policy.operator?(state.membership, operator_nick) do
      new_bans = MapSet.delete(state.bans, target_nick)
      new_state = %{state | bans: new_bans}

      maybe_persist_ban(:remove, state.name, target_nick, operator_nick, nil, state)

      broadcast(
        state.name,
        {:user_unbanned, %{channel: state.name, operator: operator_nick, target: target_nick}}
      )

      {:reply, :ok, new_state}
    else
      {:reply, {:error, "You must be a channel operator to unban users"}, state}
    end
  end

  def handle_call({:set_welcome, message, set_by}, _from, state) do
    welcome = %{message: message, set_by: set_by}
    new_state = %{state | welcome_message: welcome}

    try do
      ServiceQueries.upsert_welcome_message(state.name, message, set_by)
    rescue
      e -> Logger.warning("Failed to persist welcome for #{state.name}: #{inspect(e)}")
    end

    broadcast(
      state.name,
      {:welcome_changed, %{channel: state.name, message: message, set_by: set_by}}
    )

    {:reply, :ok, new_state}
  end

  def handle_call({:clear_welcome, _cleared_by}, _from, state) do
    new_state = %{state | welcome_message: nil}

    try do
      ServiceQueries.delete_welcome_message(state.name)
    rescue
      e -> Logger.warning("Failed to clear welcome for #{state.name}: #{inspect(e)}")
    end

    broadcast(
      state.name,
      {:welcome_changed, %{channel: state.name, message: nil, set_by: nil}}
    )

    {:reply, :ok, new_state}
  end

  def handle_call(:get_welcome, _from, state) do
    {:reply, {:ok, state.welcome_message}, state}
  end

  def handle_call(:mark_registered, _from, state) do
    {:reply, :ok, %{state | registered: true}}
  end

  def handle_call({:knock, nickname, message}, _from, state) do
    cond do
      not Modes.invite_only?(state.modes) ->
        {:reply, {:error, "Channel is not invite-only"}, state}

      Modes.no_knock?(state.modes) ->
        {:reply, {:error, "Knocking is disabled for this channel"}, state}

      Masks.matches_any?(state.bans, nickname) and
          not Masks.matches_any?(state.ban_exceptions, nickname) ->
        {:reply, {:error, "You are banned from that channel"}, state}

      Membership.member?(state.membership, nickname) ->
        {:reply, {:error, "You are already in that channel"}, state}

      true ->
        broadcast(
          state.name,
          {:knock, %{nickname: nickname, channel: state.name, message: message}}
        )

        {:reply, :ok, state}
    end
  end

  def handle_call({:channel_mute, operator_nick, target_nick, duration}, _from, state) do
    with {:ok, op_role} <- Membership.role(state.membership, operator_nick),
         true <- Membership.rank(op_role) >= Membership.rank(:half_operator),
         {:ok, _} <- Membership.role(state.membership, target_nick),
         true <-
           Membership.rank(op_role) >
             Membership.rank(elem(Membership.role(state.membership, target_nick), 1)) do
      new_mutes = MapSet.put(state.channel_mutes, target_nick)
      new_state = %{state | channel_mutes: new_mutes}

      if is_integer(duration) and duration > 0 do
        Process.send_after(self(), {:unmute_timer, target_nick}, duration * 1_000)
      end

      broadcast(state.name, {:user_channel_muted, %{target: target_nick, channel: state.name}})
      {:reply, :ok, new_state}
    else
      {:error, :not_member} -> {:reply, {:error, "User is not in channel"}, state}
      false -> {:reply, {:error, "Insufficient privileges"}, state}
    end
  end

  def handle_call({:channel_unmute, operator_nick, target_nick}, _from, state) do
    with {:ok, op_role} <- Membership.role(state.membership, operator_nick),
         true <- Membership.rank(op_role) >= Membership.rank(:half_operator) do
      new_mutes = MapSet.delete(state.channel_mutes, target_nick)
      new_state = %{state | channel_mutes: new_mutes}

      broadcast(state.name, {:user_channel_unmuted, %{target: target_nick, channel: state.name}})
      {:reply, :ok, new_state}
    else
      {:error, :not_member} -> {:reply, {:error, "Insufficient privileges"}, state}
      false -> {:reply, {:error, "Insufficient privileges"}, state}
    end
  end

  def handle_call({:transfer_ownership, current_owner, new_owner}, _from, state) do
    with {:ok, :owner} <- Membership.role(state.membership, current_owner),
         {:ok, _} <- Membership.role(state.membership, new_owner) do
      new_membership =
        state.membership
        |> Membership.set_role(current_owner, :operator)
        |> Membership.set_role(new_owner, :owner)

      new_state = %{state | membership: new_membership}

      broadcast(
        state.name,
        {:mode_changed,
         %{
           nickname: current_owner,
           mode_string: "+q",
           params: [new_owner],
           channel: state.name
         }}
      )

      broadcast(
        state.name,
        {:mode_changed,
         %{
           nickname: current_owner,
           mode_string: "-q",
           params: [current_owner],
           channel: state.name
         }}
      )

      broadcast(
        state.name,
        {:mode_changed,
         %{
           nickname: current_owner,
           mode_string: "+o",
           params: [current_owner],
           channel: state.name
         }}
      )

      {:reply, :ok, new_state}
    else
      {:ok, _role} -> {:reply, {:error, "Only the channel owner can transfer ownership"}, state}
      {:error, :not_member} -> {:reply, {:error, "User is not in channel"}, state}
    end
  end

  @impl true
  def handle_info({:unmute_timer, target_nick}, state) do
    if MapSet.member?(state.channel_mutes, target_nick) do
      new_state = %{state | channel_mutes: MapSet.delete(state.channel_mutes, target_nick)}
      broadcast(state.name, {:user_channel_unmuted, %{target: target_nick, channel: state.name}})
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # ──────────────────────────────────────────────────────────────
  # Private Helpers
  # ──────────────────────────────────────────────────────────────

  defp extract_ban_operations(mode_string, params) do
    case String.split(mode_string, "", trim: true) do
      [sign | flags] when sign in ["+", "-"] ->
        action = if sign == "+", do: :ban, else: :unban

        {ban_ops, remaining_flags, remaining_params} =
          collect_ban_flags(action, flags, params)

        clean_mode_string =
          case remaining_flags do
            [] -> sign
            _ -> sign <> Enum.join(remaining_flags)
          end

        {ban_ops, clean_mode_string, remaining_params}

      _ ->
        {[], mode_string, params}
    end
  end

  defp collect_ban_flags(action, flags, params) do
    {ops, kept_flags, kept_params, _remaining_params} =
      Enum.reduce(flags, {[], [], [], params}, fn
        "b", {ops, kept, kp, [nick | rest]} ->
          {[{action, nick} | ops], kept, kp, rest}

        "b", {ops, kept, kp, []} ->
          {ops, kept, kp, []}

        flag, {ops, kept, kp, [param | rest]} when flag in ~w(o v q h k l j) ->
          {ops, kept ++ [flag], kp ++ [param], rest}

        flag, {ops, kept, kp, []} when flag in ~w(o v q h k l j) ->
          {ops, kept ++ [flag], kp, []}

        flag, {ops, kept, kp, rest} ->
          {ops, kept ++ [flag], kp, rest}
      end)

    {Enum.reverse(ops), kept_flags, kept_params}
  end

  defp apply_ban_operations([], _nickname, state), do: {:ok, state}

  defp apply_ban_operations(ban_ops, nickname, state) do
    Enum.reduce_while(ban_ops, {:ok, state}, fn
      {:ban, target}, {:ok, st} ->
        case do_mode_ban(st, nickname, target) do
          {:ok, new_st} -> {:cont, {:ok, new_st}}
          {:error, _} = err -> {:halt, err}
        end

      {:unban, target}, {:ok, st} ->
        case do_mode_unban(st, nickname, target) do
          {:ok, new_st} -> {:cont, {:ok, new_st}}
          {:error, _} = err -> {:halt, err}
        end
    end)
  end

  defp do_mode_ban(state, nickname, target) do
    with :ok <- Policy.can_ban?(state.membership, nickname, target) do
      new_state = %{state | bans: MapSet.put(state.bans, target)}
      maybe_persist_ban(:add, state.name, target, nickname, nil, state)

      broadcast(
        state.name,
        {:user_banned, %{channel: state.name, operator: nickname, target: target, reason: nil}}
      )

      {:ok, eject_ban_matches(new_state, nickname, target, "Banned")}
    end
  end

  defp do_mode_unban(state, nickname, target) do
    if Policy.operator?(state.membership, nickname) do
      new_state = %{state | bans: MapSet.delete(state.bans, target)}
      maybe_persist_ban(:remove, state.name, target, nickname, nil, state)

      broadcast(
        state.name,
        {:user_unbanned, %{channel: state.name, operator: nickname, target: target}}
      )

      {:ok, new_state}
    else
      {:error, "You must be a channel operator to unban users"}
    end
  end

  defp eject_ban_matches(state, operator, mask, reason) do
    state.membership
    |> Membership.to_list()
    |> Enum.map(fn {nick, _role} -> nick end)
    |> Enum.filter(&Masks.matches?(mask, &1))
    |> Enum.reject(&(&1 == operator))
    |> Enum.filter(&(Policy.can_ban?(state.membership, operator, &1) == :ok))
    |> Enum.reduce(state, fn target, acc ->
      broadcast(
        acc.name,
        {:user_kicked, %{operator: operator, target: target, reason: reason}}
      )

      %{acc | membership: Membership.remove(acc.membership, target)}
    end)
  end

  defp check_mode_permissions(membership, nickname, mode_string, params) do
    flags = extract_mode_flags(mode_string, params)

    Enum.reduce_while(flags, :ok, fn flag, _acc ->
      case Policy.can_set_mode?(membership, nickname, flag) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp extract_mode_flags(mode_string, params) do
    case String.split(mode_string, "", trim: true) do
      ["+" | flags] -> extract_flags_with_params(flags, params)
      ["-" | flags] -> extract_flags_with_params(flags, params)
      _ -> []
    end
  end

  defp extract_flags_with_params(flags, _params) do
    # Return all flag characters for permission checking
    flags
  end

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

  defp process_user_flag(:add, "q", acc, [nick | rest]), do: {[{nick, :owner} | acc], rest}
  defp process_user_flag(:remove, "q", acc, [nick | rest]), do: {[{nick, :regular} | acc], rest}
  defp process_user_flag(:add, "o", acc, [nick | rest]), do: {[{nick, :operator} | acc], rest}
  defp process_user_flag(:remove, "o", acc, [nick | rest]), do: {[{nick, :regular} | acc], rest}

  defp process_user_flag(:add, "h", acc, [nick | rest]),
    do: {[{nick, :half_operator} | acc], rest}

  defp process_user_flag(:remove, "h", acc, [nick | rest]),
    do: {[{nick, :regular} | acc], rest}

  defp process_user_flag(:add, "v", acc, [nick | rest]), do: {[{nick, :voiced} | acc], rest}
  defp process_user_flag(:remove, "v", acc, [nick | rest]), do: {[{nick, :regular} | acc], rest}
  defp process_user_flag(:add, "k", acc, [_ | rest]), do: {acc, rest}
  defp process_user_flag(:add, "l", acc, [_ | rest]), do: {acc, rest}
  defp process_user_flag(:add, "j", acc, [_ | rest]), do: {acc, rest}

  defp process_user_flag(_, flag, acc, []) when flag in ~w(o v k l q h j), do: {acc, []}
  defp process_user_flag(_, _, acc, remaining), do: {acc, remaining}

  defp check_channel_mute(state, nickname) do
    if MapSet.member?(state.channel_mutes, nickname) do
      {:error, "You are muted in this channel"}
    else
      :ok
    end
  end

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
      topic_set_by: state.topic_set_by,
      topic_set_at: state.topic_set_at,
      members: Membership.to_list(state.membership),
      member_count: Membership.count(state.membership),
      owners: Membership.owners(state.membership),
      operators: Membership.operators(state.membership),
      half_operators: Membership.half_operators(state.membership),
      modes: Modes.to_string(state.modes),
      modes_detail: %{
        moderated: Modes.moderated?(state.modes),
        invite_only: Modes.invite_only?(state.modes),
        topic_lock: Modes.topic_locked?(state.modes),
        key: state.modes.key,
        limit: state.modes.limit,
        no_external: Modes.no_external?(state.modes),
        secret: Modes.secret?(state.modes),
        private: Modes.private?(state.modes),
        strip_colors: Modes.strip_colors?(state.modes),
        registered_only: Modes.registered_only?(state.modes),
        no_knock: Modes.no_knock?(state.modes),
        join_throttle: state.modes.join_throttle
      },
      bans: MapSet.to_list(state.bans),
      ban_exceptions: MapSet.to_list(state.ban_exceptions),
      invite_exceptions: MapSet.to_list(state.invite_exceptions),
      created_at: state.created_at
    }
  end

  defp check_not_banned(state, nickname) do
    banned = Masks.matches_any?(state.bans, nickname)
    excepted = Masks.matches_any?(state.ban_exceptions, nickname)

    if banned and not excepted do
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

  defp check_join_throttle(state, nickname) do
    cond do
      not Modes.has_join_throttle?(state.modes) -> :ok
      Policy.operator?(state.membership, nickname) -> :ok
      true -> enforce_throttle(state)
    end
  end

  defp enforce_throttle(state) do
    {count, seconds} = state.modes.join_throttle
    cutoff = DateTime.add(DateTime.utc_now(), -seconds, :second)

    recent =
      Enum.count(state.join_timestamps, fn ts ->
        DateTime.compare(ts, cutoff) != :lt
      end)

    if recent >= count,
      do: {:error, "Channel join throttle active, please try again shortly"},
      else: :ok
  end

  defp persist_and_get_id(channel_name, nickname, content, type, reply_to_id) do
    base_attrs = %{
      channel_name: channel_name,
      author_nickname: nickname,
      content: content,
      type: to_string(type)
    }

    result =
      if reply_to_id do
        case resolve_reply_attrs(reply_to_id) do
          {:ok, reply_attrs} ->
            Chat.Queries.insert_reply_message(Map.merge(base_attrs, reply_attrs))

          {:error, _} ->
            Chat.Queries.insert_message(base_attrs)
        end
      else
        Chat.Queries.insert_message(base_attrs)
      end

    case result do
      {:ok, message} ->
        {message, message.id, message.inserted_at}

      {:error, changeset} ->
        Logger.warning("Failed to persist message in #{channel_name}: #{inspect(changeset)}")
        {nil, "msg-#{System.unique_integer([:positive])}", DateTime.utc_now()}
    end
  rescue
    e ->
      Logger.warning("Failed to persist message in #{channel_name}: #{inspect(e)}")
      {nil, "msg-#{System.unique_integer([:positive])}", DateTime.utc_now()}
  end

  defp resolve_reply_attrs(reply_to_id) do
    case Chat.Queries.get_message(reply_to_id) do
      nil ->
        {:error, :not_found}

      parent ->
        preview =
          if String.length(parent.content) > 100,
            do: String.slice(parent.content, 0, 97) <> "...",
            else: parent.content

        {:ok,
         %{
           reply_to_id: parent.id,
           reply_to_author: parent.author_nickname,
           reply_to_preview: preview
         }}
    end
  end

  defp maybe_persist_exception(type, action, channel_name, nickname, added_by, state) do
    if state.registered do
      case {type, action} do
        {:ban_exception, :add} ->
          ServiceQueries.add_ban_exception(channel_name, nickname, added_by)

        {:ban_exception, :remove} ->
          ServiceQueries.remove_ban_exception(channel_name, nickname)

        {:invite_exception, :add} ->
          ServiceQueries.add_invite_exception(channel_name, nickname, added_by)

        {:invite_exception, :remove} ->
          ServiceQueries.remove_invite_exception(channel_name, nickname)
      end
    end
  rescue
    e ->
      Logger.warning("Failed to persist #{type} #{action} for #{channel_name}: #{inspect(e)}")
  end

  defp maybe_persist_ban(action, channel_name, nickname, actor, reason, state) do
    if state.registered do
      case action do
        :add -> ServiceQueries.add_ban(channel_name, nickname, actor, reason)
        :remove -> ServiceQueries.remove_ban(channel_name, nickname)
      end
    end
  rescue
    e ->
      Logger.warning("Failed to persist ban #{action} for #{channel_name}: #{inspect(e)}")
  end

  defp load_persisted_state(state) do
    case Queries.load_persisted_state(state.name) do
      nil ->
        state

      persisted ->
        modes = apply_persisted_modes(state.modes, persisted)
        bans = persisted.bans |> MapSet.new()
        ban_exceptions = Map.get(persisted, :ban_exceptions, []) |> MapSet.new()
        invite_exceptions = Map.get(persisted, :invite_exceptions, []) |> MapSet.new()

        %{
          state
          | topic: persisted.topic,
            modes: modes,
            bans: bans,
            ban_exceptions: ban_exceptions,
            invite_exceptions: invite_exceptions,
            registered: true
        }
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
    |> maybe_set_join_throttle(Map.get(persisted, :mode_join_throttle))
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

  defp maybe_set_join_throttle(modes, nil), do: modes
  defp maybe_set_join_throttle(modes, ""), do: modes

  defp maybe_set_join_throttle(modes, throttle_str) when is_binary(throttle_str) do
    case String.split(throttle_str, ":") do
      [count_str, seconds_str] ->
        with {count, ""} <- Integer.parse(count_str),
             {seconds, ""} <- Integer.parse(seconds_str),
             true <- count > 0 and seconds > 0 do
          %{modes | join_throttle: {count, seconds}}
        else
          _ -> modes
        end

      _ ->
        modes
    end
  end

  defp load_welcome_message(state) do
    case ServiceQueries.get_welcome_message(state.name) do
      nil ->
        state

      welcome ->
        %{state | welcome_message: %{message: welcome.message, set_by: welcome.set_by}}
    end
  rescue
    e ->
      Logger.warning("Failed to load welcome message for #{state.name}: #{inspect(e)}")
      state
  end

  @activity_touch_interval_seconds 300

  defp maybe_touch_activity(%{registered: false} = state), do: state

  defp maybe_touch_activity(state) do
    now = DateTime.utc_now()

    should_touch =
      is_nil(state.last_activity_touched_at) or
        DateTime.diff(now, state.last_activity_touched_at, :second) >=
          @activity_touch_interval_seconds

    if should_touch do
      ServiceQueries.touch_channel_activity(state.name)
      %{state | last_activity_touched_at: now}
    else
      state
    end
  rescue
    e ->
      Logger.warning("Failed to touch activity for #{state.name}: #{inspect(e)}")
      state
  end

  defp determine_join_role(state, nickname) do
    cond do
      Membership.count(state.membership) == 0 and not state.registered ->
        :owner

      state.registered ->
        access_level_to_role(state.name, nickname)

      true ->
        :regular
    end
  end

  defp access_level_to_role(channel_name, nickname) do
    case ChanServ.check_access(channel_name, nickname) do
      {:ok, level} when level in ["founder", "sop"] -> :owner
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
