defmodule RetroHexChat.Channels.Server do
  @moduledoc """
  GenServer managing state for a single IRC channel.
  Process-per-channel architecture (Constitution III).

  Each channel gets its own process that tracks membership, modes,
  bans, and topic. All mutations go through this process to ensure
  serialized access to channel state.
  """
  use Gettext, backend: RetroHexChat.Gettext
  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Channels.{
    Directory,
    Events,
    Masks,
    Membership,
    Modes,
    Mutes,
    Policy,
    Queries,
    Registry
  }

  alias RetroHexChat.Chat
  alias RetroHexChat.Chat.{Attachments, Content}
  alias RetroHexChat.Observability
  alias RetroHexChat.Repo
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
          channel_mutes: MapSet.t(String.t()),
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

    Observability.span(
      [:retro_hex_chat, :channels, :membership, :join],
      %{"chat.channel" => channel_name, identified: identified, bot: bot},
      fn -> GenServer.call(via(channel_name), {:join, nickname, password, identified, bot}) end
    )
  end

  @doc """
  Leave a channel. If the channel becomes empty and is not registered,
  the process will stop itself.
  """
  @spec part(String.t(), String.t(), String.t() | nil) :: :ok | {:error, String.t()}
  def part(channel_name, nickname, reason \\ nil) do
    Observability.span(
      [:retro_hex_chat, :channels, :membership, :part],
      %{"chat.channel" => channel_name, has_reason: is_binary(reason) and reason != ""},
      fn ->
        try do
          case Registry.lookup(channel_name) do
            {:ok, pid} -> GenServer.call(pid, {:part, nickname, reason})
            {:error, :not_found} -> {:error, dgettext("channels", "Channel not found")}
          end
        catch
          :exit, _reason -> {:error, dgettext("channels", "Channel not found")}
        end
      end
    )
  end

  @doc """
  Send a message to the channel. The message is broadcast via PubSub.

  On success returns `{:ok, id}` with the persisted message id, so a caller can
  render an optimistic row keyed by the same id the PubSub echo will carry — the
  echo then updates that row in place instead of appending a duplicate.
  """
  @spec send_message(
          String.t(),
          String.t(),
          String.t(),
          atom() | String.t() | keyword(),
          keyword()
        ) ::
          {:ok, term()} | {:error, String.t()}
  def send_message(channel_name, nickname, content, type_or_opts \\ :message, opts \\ [])

  def send_message(channel_name, nickname, content, type_or_opts, opts)
      when is_list(type_or_opts) and opts == [] do
    send_message(channel_name, nickname, content, :message, type_or_opts)
  end

  def send_message(channel_name, nickname, content, type, opts) do
    type = normalize_send_type(type)

    Observability.span(
      [:retro_hex_chat, :chat, :message, :send],
      message_metadata(type, content, opts, %{"chat.channel" => channel_name}),
      fn -> GenServer.call(via(channel_name), {:send_message, nickname, content, type, opts}) end
    )
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
    Observability.span(
      [:retro_hex_chat, :channels, :mode, :set],
      %{
        "chat.channel" => channel_name,
        "irc.mode" => mode_string,
        parameter_count: length(params)
      },
      fn -> GenServer.call(via(channel_name), {:set_mode, nickname, mode_string, params}) end
    )
  end

  @doc """
  Kick a user from the channel. Requires sufficient rank.
  """
  @spec kick(String.t(), String.t(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def kick(channel_name, operator_nick, target_nick, reason \\ nil) do
    Observability.span(
      [:retro_hex_chat, :channels, :moderation, :kick],
      %{"chat.channel" => channel_name, has_reason: is_binary(reason) and reason != ""},
      fn -> GenServer.call(via(channel_name), {:kick, operator_nick, target_nick, reason}) end
    )
  end

  @doc """
  Ban a user from the channel. Requires operator or owner.
  """
  @spec ban(String.t(), String.t(), String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def ban(channel_name, operator_nick, target_nick, reason \\ nil) do
    Observability.span(
      [:retro_hex_chat, :channels, :moderation, :ban],
      %{"chat.channel" => channel_name, has_reason: is_binary(reason) and reason != ""},
      fn -> GenServer.call(via(channel_name), {:ban, operator_nick, target_nick, reason}) end
    )
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
    Observability.span(
      [:retro_hex_chat, :channels, :topic, :set],
      %{"chat.channel" => channel_name, topic_size_bytes: byte_size(topic)},
      fn -> GenServer.call(via(channel_name), {:set_topic, nickname, topic}) end
    )
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

  @doc false
  @spec apply_channel_mute_expired(String.t(), String.t(), pos_integer()) :: :ok
  def apply_channel_mute_expired(channel_name, target_nick, mute_id) do
    case Registry.lookup(channel_name) do
      {:ok, pid} -> GenServer.call(pid, {:channel_mute_expired, mute_id, target_nick})
      {:error, :not_found} -> :ok
    end
  catch
    :exit, _reason -> :ok
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
      {:error, :not_found} -> {:error, dgettext("channels", "Channel not found")}
    end
  catch
    :exit, _reason -> {:error, dgettext("channels", "Channel not found")}
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

    {:ok,
     state
     |> load_persisted_state()
     |> load_channel_mutes()
     |> load_welcome_message()
     |> refresh_directory()}
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
      reply({:ok, state_to_map(new_state)}, new_state)
    else
      {:error, _} = err -> reply(err, state)
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
        reply(:ok, new_state)
      end
    else
      reply({:error, dgettext("channels", "Not in channel")}, state)
    end
  end

  def handle_call({:send_message, nickname, content, type, opts}, _from, state) do
    Observability.span(
      [:retro_hex_chat, :chat, :message, :handle],
      message_metadata(type, content, opts, %{"chat.channel" => state.name}),
      fn -> do_handle_send_message(nickname, content, type, opts, state) end
    )
  end

  # Backward compat: old 4-element tuple without opts
  def handle_call({:send_message, nickname, content, type}, from, state) do
    handle_call({:send_message, nickname, content, type, []}, from, state)
  end

  def handle_call(:get_state, _from, state) do
    reply(state_to_map(state), state)
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

      reply(:ok, new_state)
    else
      {:error, _} = err -> reply(err, state)
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
             channel: state.name,
             operator: actor_nick,
             target: target_nick,
             reason: reason
           }}
        )

        if Membership.count(new_membership) == 0 and not state.registered do
          {:stop, :normal, :ok, new_state}
        else
          reply(:ok, new_state)
        end

      {:error, _} = err ->
        reply(err, state)
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

        new_state =
          eject_ban_matches(new_state, actor_nick, target_nick, dgettext("channels", "Banned"))

        reply(:ok, new_state)

      {:error, _} = err ->
        reply(err, state)
    end
  end

  def handle_call({:rename_user, old_nick, new_nick}, _from, state) do
    new_membership = Membership.rename(state.membership, old_nick, new_nick)
    reply(:ok, %{state | membership: new_membership})
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

        reply(:ok, new_state)

      {:error, _} = err ->
        reply(err, state)
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

      reply(:ok, new_state)
    else
      reply({:error, dgettext("channels", "You must be a channel operator")}, state)
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

      reply(:ok, new_state)
    else
      reply({:error, dgettext("channels", "You must be a channel operator")}, state)
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

      reply(:ok, new_state)
    else
      reply({:error, dgettext("channels", "You must be a channel operator")}, state)
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

      reply(:ok, new_state)
    else
      reply({:error, dgettext("channels", "You must be a channel operator")}, state)
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

      reply(:ok, new_state)
    else
      reply(
        {:error, dgettext("channels", "You must be a channel operator to unban users")},
        state
      )
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

    reply(:ok, new_state)
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

    reply(:ok, new_state)
  end

  def handle_call(:get_welcome, _from, state) do
    reply({:ok, state.welcome_message}, state)
  end

  def handle_call(:mark_registered, _from, state) do
    reply(:ok, %{state | registered: true})
  end

  def handle_call({:knock, nickname, message}, _from, state) do
    cond do
      not Modes.invite_only?(state.modes) ->
        reply({:error, dgettext("channels", "Channel is not invite-only")}, state)

      Modes.no_knock?(state.modes) ->
        reply({:error, dgettext("channels", "Knocking is disabled for this channel")}, state)

      Masks.matches_any?(state.bans, nickname) and
          not Masks.matches_any?(state.ban_exceptions, nickname) ->
        reply({:error, dgettext("channels", "You are banned from that channel")}, state)

      Membership.member?(state.membership, nickname) ->
        reply({:error, dgettext("channels", "You are already in that channel")}, state)

      true ->
        broadcast(
          state.name,
          {:knock, %{nickname: nickname, channel: state.name, message: message}}
        )

        reply(:ok, state)
    end
  end

  def handle_call({:channel_mute, operator_nick, target_nick, duration}, _from, state) do
    with {:ok, op_role} <- Membership.role(state.membership, operator_nick),
         true <- Membership.rank(op_role) >= Membership.rank(:half_operator),
         {:ok, _} <- Membership.role(state.membership, target_nick),
         true <-
           Membership.rank(op_role) >
             Membership.rank(elem(Membership.role(state.membership, target_nick), 1)),
         {:ok, mute} <- Mutes.mute(state.name, operator_nick, target_nick, duration) do
      new_mutes = MapSet.put(state.channel_mutes, mute.target_nickname)
      new_state = %{state | channel_mutes: new_mutes}

      broadcast(
        state.name,
        {:user_channel_muted, %{target: mute.target_nickname, channel: state.name}}
      )

      reply(:ok, new_state)
    else
      {:error, :not_member} ->
        reply({:error, dgettext("channels", "User is not in channel")}, state)

      false ->
        reply({:error, dgettext("channels", "Insufficient privileges")}, state)

      {:error, reason} ->
        Logger.warning("Failed to persist channel mute for #{state.name}: #{inspect(reason)}")
        reply({:error, dgettext("channels", "Could not persist channel mute")}, state)
    end
  end

  def handle_call({:channel_unmute, operator_nick, target_nick}, _from, state) do
    with {:ok, op_role} <- Membership.role(state.membership, operator_nick),
         true <- Membership.rank(op_role) >= Membership.rank(:half_operator),
         {:ok, _summary} <- Mutes.revoke_active(state.name, target_nick, operator_nick) do
      new_mutes = MapSet.delete(state.channel_mutes, target_nick)
      new_state = %{state | channel_mutes: new_mutes}

      broadcast(state.name, {:user_channel_unmuted, %{target: target_nick, channel: state.name}})
      reply(:ok, new_state)
    else
      {:error, :not_member} ->
        reply({:error, dgettext("channels", "Insufficient privileges")}, state)

      false ->
        reply({:error, dgettext("channels", "Insufficient privileges")}, state)

      {:error, reason} ->
        Logger.warning("Failed to persist channel unmute for #{state.name}: #{inspect(reason)}")
        reply({:error, dgettext("channels", "Could not persist channel unmute")}, state)
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

      reply(:ok, new_state)
    else
      {:ok, _role} ->
        reply(
          {:error, dgettext("channels", "Only the channel owner can transfer ownership")},
          state
        )

      {:error, :not_member} ->
        reply({:error, dgettext("channels", "User is not in channel")}, state)
    end
  end

  def handle_call({:channel_mute_expired, _mute_id, target_nick}, _from, state) do
    if MapSet.member?(state.channel_mutes, target_nick) do
      new_state = %{state | channel_mutes: MapSet.delete(state.channel_mutes, target_nick)}
      broadcast(state.name, {:user_channel_unmuted, %{target: target_nick, channel: state.name}})
      reply(:ok, new_state)
    else
      reply(:ok, state)
    end
  end

  # ──────────────────────────────────────────────────────────────
  # Private Helpers
  # ──────────────────────────────────────────────────────────────

  defp do_handle_send_message(nickname, content, type, opts, state) do
    requested_format = content_format_from_opts(opts)
    attachment_ids = attachment_ids_from_opts(opts)

    with :ok <- validate_message_content(content, requested_format, attachment_ids),
         :ok <- Policy.can_speak?(state.modes, state.membership, nickname),
         :ok <- check_channel_mute(state, nickname),
         {:ok, msg, id, timestamp} <-
           persist_and_get_id(
             state.name,
             nickname,
             content,
             requested_format,
             type,
             Keyword.get(opts, :reply_to_id),
             attachment_ids,
             state
           ) do
      {final_content, content_format} =
        apply_content_mode_policy(content, requested_format, state)

      Observability.set_current_span_attributes(%{
        "chat.message.id" => id,
        "chat.message.persisted" => not is_nil(msg)
      })

      payload = %{
        id: id,
        channel: state.name,
        author: nickname,
        content: final_content,
        content_format: persisted_content_format(msg, content_format),
        type: type,
        timestamp: timestamp,
        reply_to_id: msg && msg.reply_to_id,
        reply_to_author: msg && msg.reply_to_author,
        reply_to_preview: msg && msg.reply_to_preview,
        attachments: attachment_payloads(msg)
      }

      broadcast(state.name, %{event: "new_message", payload: payload})

      reply({:ok, id}, maybe_touch_activity(state))
    else
      {:error, _} = err ->
        reply(err, state)
    end
  end

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

      {:ok, eject_ban_matches(new_state, nickname, target, dgettext("channels", "Banned"))}
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
      {:error, dgettext("channels", "You must be a channel operator to unban users")}
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
        {:user_kicked, %{channel: acc.name, operator: operator, target: target, reason: reason}}
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
      {:halt, {:error, dgettext("channels", "User %{target} is not in channel", target: target)}}
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
      {:error, dgettext("channels", "You are muted in this channel")}
    else
      :ok
    end
  end

  # ── Directory snapshot ────────────────────────────────────────
  #
  # Every callback returns through these, so the directory snapshot cannot go
  # stale by someone forgetting to refresh it after a mutation. Refreshing is
  # cheap — a member count and three mode flags — and it buys `/list` a single
  # ETS read instead of one synchronous call per channel.

  defp reply(value, state), do: {:reply, value, refresh_directory(state)}

  defp refresh_directory(state) do
    Directory.publish(state.name, %{
      name: state.name,
      topic: state.topic,
      member_count: Membership.count(state.membership),
      secret?: Modes.secret?(state.modes),
      private?: Modes.private?(state.modes),
      invite_only?: Modes.invite_only?(state.modes),
      modes: Modes.to_string(state.modes)
    })

    state
  end

  defp via(channel_name), do: Registry.via_tuple(channel_name)

  defp broadcast(channel_name, message) do
    {event, metadata} = broadcast_observability(channel_name, message)

    Observability.span(event, metadata, fn ->
      case Phoenix.PubSub.broadcast(@pubsub, "channel:#{channel_name}", message) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("PubSub broadcast to channel:#{channel_name} failed: #{inspect(reason)}")
          {:error, reason}
      end
    end)
  end

  defp message_metadata(type, content, opts, extra) do
    Map.merge(
      %{
        conversation_type: "channel",
        message_type: normalize_message_type(type),
        message_size_bytes: byte_size(content),
        content_format: content_format_from_opts(opts),
        has_reply: Keyword.has_key?(opts, :reply_to_id)
      },
      extra
    )
  end

  defp broadcast_observability(
         channel_name,
         %{event: "new_message", payload: %{id: id, type: type}} = message
       ) do
    {[:retro_hex_chat, :chat, :message, :broadcast],
     %{
       "chat.channel" => channel_name,
       "chat.message.id" => id,
       conversation_type: "channel",
       message_type: normalize_message_type(type),
       event: Map.get(message, :event, "new_message")
     }}
  end

  defp broadcast_observability(channel_name, message) do
    {[:retro_hex_chat, :channels, :broadcast],
     %{
       "chat.channel" => channel_name,
       event: channel_event_name(message)
     }}
  end

  defp channel_event_name(%{event: event}) when is_binary(event), do: event
  defp channel_event_name({event, _payload}) when is_atom(event), do: Atom.to_string(event)

  defp normalize_send_type(type) when type in [nil, :""], do: :message

  defp normalize_send_type(type) when is_binary(type) do
    if String.trim(type) == "", do: :message, else: type
  end

  defp normalize_send_type(type), do: type

  defp normalize_message_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_message_type(type) when is_binary(type), do: type
  defp normalize_message_type(_type), do: "unknown"

  defp state_to_map(state) do
    %{
      name: state.name,
      topic: state.topic,
      topic_set_by: state.topic_set_by,
      topic_set_at: state.topic_set_at,
      welcome_message: state.welcome_message,
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
      channel_mutes: MapSet.to_list(state.channel_mutes),
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
      {:error, dgettext("channels", "Already in channel")}
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
      do:
        {:error, dgettext("channels", "Channel join throttle active, please try again shortly")},
      else: :ok
  end

  defp persist_and_get_id(
         channel_name,
         nickname,
         content,
         content_format,
         type,
         reply_to_id,
         attachment_ids,
         state
       ) do
    {final_content, persisted_content_format} =
      apply_content_mode_policy(content, content_format, state)

    base_attrs = %{
      channel_name: channel_name,
      author_nickname: nickname,
      content: final_content,
      content_format: persisted_content_format,
      type: to_string(type),
      allow_blank_content: attachment_ids != []
    }

    persist_message_transaction(base_attrs, reply_to_id, nickname, attachment_ids)
    |> case do
      {:ok, {message, id, timestamp}} ->
        {:ok, message, id, timestamp}

      {:error, :attachment_not_found} ->
        {:error, dgettext("chat", "Attachment could not be attached to the message")}

      {:error, changeset} ->
        Logger.warning("Failed to persist message in #{channel_name}: #{inspect(changeset)}")
        {:ok, nil, "msg-#{System.unique_integer([:positive])}", DateTime.utc_now()}
    end
  rescue
    e ->
      Logger.warning("Failed to persist message in #{channel_name}: #{inspect(e)}")
      {:ok, nil, "msg-#{System.unique_integer([:positive])}", DateTime.utc_now()}
  end

  defp persist_message_transaction(base_attrs, reply_to_id, nickname, attachment_ids) do
    Repo.transaction(fn ->
      base_attrs
      |> insert_persisted_message(reply_to_id)
      |> attach_persisted_attachments(nickname, attachment_ids)
    end)
  end

  defp insert_persisted_message(base_attrs, nil), do: Chat.Queries.insert_message(base_attrs)

  defp insert_persisted_message(base_attrs, reply_to_id) do
    case resolve_reply_attrs(reply_to_id) do
      {:ok, reply_attrs} -> Chat.Queries.insert_reply_message(Map.merge(base_attrs, reply_attrs))
      {:error, _} -> Chat.Queries.insert_message(base_attrs)
    end
  end

  defp attach_persisted_attachments({:ok, message}, nickname, attachment_ids) do
    case Chat.Queries.attach_to_message(attachment_ids, nickname, message.id) do
      {:ok, attachments} ->
        message = %{message | attachments: attachments}
        {message, message.id, message.inserted_at}

      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  defp attach_persisted_attachments({:error, reason}, _nickname, _attachment_ids) do
    Repo.rollback(reason)
  end

  defp resolve_reply_attrs(reply_to_id) do
    case Chat.Queries.get_message(reply_to_id) do
      nil ->
        {:error, :not_found}

      parent ->
        preview = Content.reply_preview(parent)

        {:ok,
         %{
           reply_to_id: parent.id,
           reply_to_author: parent.author_nickname,
           reply_to_preview: preview
         }}
    end
  end

  defp apply_content_mode_policy(content, content_format, state) do
    if Modes.strip_colors?(state.modes) do
      {Content.strip_formatting(content, content_format), "plain"}
    else
      {content, content_format}
    end
  end

  defp content_format_from_opts(opts) do
    opts
    |> Keyword.get(:content_format, "irc")
    |> normalize_content_format()
  end

  defp normalize_content_format(format) do
    case Content.normalize_format(format) do
      {:ok, normalized} -> Atom.to_string(normalized)
      :error -> format
    end
  end

  defp persisted_content_format(%{content_format: content_format}, _fallback)
       when is_binary(content_format),
       do: content_format

  defp persisted_content_format(_message, fallback), do: fallback

  defp attachment_ids_from_opts(opts) do
    opts
    |> Keyword.get(:attachment_ids, [])
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
  end

  defp validate_message_content(content, content_format, attachment_ids) do
    case Content.validate(content, content_format) do
      :ok -> :ok
      {:error, :blank} when attachment_ids != [] -> :ok
      {:error, :blank} -> {:error, dgettext("chat", "Message cannot be empty")}
      {:error, :too_long} -> {:error, "Message exceeds maximum length of 1000 characters"}
      {:error, :unsupported_format} -> {:error, dgettext("chat", "Unsupported message format")}
    end
  end

  defp attachment_payloads(%{attachments: %Ecto.Association.NotLoaded{}}), do: []

  defp attachment_payloads(%{attachments: attachments}) when is_list(attachments) do
    attachments
    |> Enum.map(&Attachments.payload/1)
    |> Enum.reject(&is_nil/1)
  end

  defp attachment_payloads(_message), do: []

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

  defp load_channel_mutes(state) do
    %{state | channel_mutes: Mutes.active_nicknames(state.name) |> MapSet.new()}
  rescue
    e ->
      Logger.warning("Failed to load channel mutes for #{state.name}: #{inspect(e)}")
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
