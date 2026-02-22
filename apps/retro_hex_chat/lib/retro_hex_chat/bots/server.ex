defmodule RetroHexChat.Bots.Server do
  @moduledoc """
  GenServer managing a single bot instance.
  Subscribes to channel PubSub topics and dispatches messages/events
  to the bot's active capabilities.

  Supports stateful capabilities via `capability_states` and timer-driven
  capabilities via `capability_timers`.
  """
  use GenServer, restart: :transient

  require Logger

  alias RetroHexChat.Bots.Registry
  alias RetroHexChat.Channels

  @pubsub RetroHexChat.PubSub

  @capability_modules %{
    mention: RetroHexChat.Bots.Capabilities.Mention,
    greeter: RetroHexChat.Bots.Capabilities.Greeter,
    custom_commands: RetroHexChat.Bots.Capabilities.CustomCommands,
    help: RetroHexChat.Bots.Capabilities.Help,
    llm: RetroHexChat.Bots.Capabilities.LLM,
    script: RetroHexChat.Bots.Capabilities.Script,
    game: RetroHexChat.Bots.Capabilities.Game,
    scheduler: RetroHexChat.Bots.Capabilities.Scheduler,
    moderation: RetroHexChat.Bots.Capabilities.Moderation,
    rss: RetroHexChat.Bots.Capabilities.RSS,
    trivia: RetroHexChat.Bots.Capabilities.Trivia,
    dice: RetroHexChat.Bots.Capabilities.Dice
  }

  @type state :: %{
          bot_id: integer(),
          name: String.t(),
          nickname: String.t(),
          command_prefix: String.t(),
          created_by: String.t(),
          enabled: boolean(),
          cooldown_ms: non_neg_integer(),
          capabilities: [{atom(), module(), map()}],
          channels: %{String.t() => map()},
          custom_commands: %{String.t() => map()},
          last_response_at: %{String.t() => DateTime.t()},
          capability_states: %{atom() => map()},
          capability_timers: %{reference() => {atom(), term()}},
          stats: %{
            messages_handled: integer(),
            commands_processed: integer(),
            started_at: DateTime.t()
          }
        }

  # ── Public API ──────────────────────────────────────────────

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(bot_data) do
    GenServer.start_link(__MODULE__, bot_data, name: Registry.via_tuple(bot_data.nickname))
  end

  @spec get_state(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_state(bot_nickname) do
    case Registry.lookup(bot_nickname) do
      {:ok, _pid} -> {:ok, GenServer.call(via(bot_nickname), :get_state)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @spec join_channel(String.t(), String.t()) :: :ok | {:error, term()}
  def join_channel(bot_nickname, channel_name) do
    GenServer.call(via(bot_nickname), {:join_channel, channel_name})
  end

  @spec part_channel(String.t(), String.t()) :: :ok | {:error, term()}
  def part_channel(bot_nickname, channel_name) do
    GenServer.call(via(bot_nickname), {:part_channel, channel_name})
  end

  @spec update_config(String.t(), map()) :: :ok
  def update_config(bot_nickname, updates) do
    GenServer.call(via(bot_nickname), {:update_config, updates})
  end

  @spec reload_commands(String.t(), map()) :: :ok
  def reload_commands(bot_nickname, commands) do
    GenServer.cast(via(bot_nickname), {:reload_commands, commands})
  end

  @spec set_enabled(String.t(), boolean()) :: :ok
  def set_enabled(bot_nickname, enabled) do
    GenServer.call(via(bot_nickname), {:set_enabled, enabled})
  end

  @spec get_capability_state(String.t(), atom()) :: {:ok, map()} | {:error, :not_found}
  def get_capability_state(bot_nickname, cap_name) do
    case Registry.lookup(bot_nickname) do
      {:ok, _pid} ->
        GenServer.call(via(bot_nickname), {:get_capability_state, cap_name})

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # ── Callbacks ───────────────────────────────────────────────

  @impl true
  def init(bot_data) do
    state = build_initial_state(bot_data)

    # Subscribe to channels
    Enum.each(state.channels, fn {channel_name, _} ->
      Phoenix.PubSub.subscribe(@pubsub, "channel:#{channel_name}")
    end)

    # Initialize capability timers (scheduler, rss, etc.)
    state = init_capability_timers(state)

    Logger.info("Bot #{state.nickname} started with #{map_size(state.channels)} channels")
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state_to_map(state), state}
  end

  def handle_call({:get_capability_state, cap_name}, _from, state) do
    cap_state = Map.get(state.capability_states, cap_name, %{})
    {:reply, {:ok, cap_state}, state}
  end

  def handle_call({:join_channel, channel_name}, _from, state) do
    if Map.has_key?(state.channels, channel_name) do
      {:reply, {:error, "Already in channel"}, state}
    else
      Phoenix.PubSub.subscribe(@pubsub, "channel:#{channel_name}")

      new_channels =
        Map.put(state.channels, channel_name, %{enabled: true, capability_overrides: %{}})

      join_channel_process(channel_name, state.nickname)
      {:reply, :ok, %{state | channels: new_channels}}
    end
  end

  def handle_call({:part_channel, channel_name}, _from, state) do
    if Map.has_key?(state.channels, channel_name) do
      Phoenix.PubSub.unsubscribe(@pubsub, "channel:#{channel_name}")
      part_channel_process(channel_name, state.nickname)
      new_channels = Map.delete(state.channels, channel_name)
      {:reply, :ok, %{state | channels: new_channels}}
    else
      {:reply, {:error, "Not in channel"}, state}
    end
  end

  def handle_call({:update_config, updates}, _from, state) do
    new_state =
      state
      |> maybe_update(:command_prefix, updates)
      |> maybe_update(:cooldown_ms, updates)
      |> maybe_update(:enabled, updates)

    {:reply, :ok, new_state}
  end

  def handle_call({:set_enabled, enabled}, _from, state) do
    {:reply, :ok, %{state | enabled: enabled}}
  end

  @impl true
  def handle_cast({:reload_commands, commands}, state) do
    {:noreply, %{state | custom_commands: commands}}
  end

  @impl true
  def handle_info({:new_message, payload}, state) do
    state = handle_channel_message(payload, state)
    {:noreply, state}
  end

  def handle_info({:user_joined, payload}, state) do
    state = handle_channel_event(:user_joined, payload, state)
    {:noreply, state}
  end

  def handle_info({:user_left, payload}, state) do
    state = handle_channel_event(:user_left, payload, state)
    {:noreply, state}
  end

  def handle_info({:user_kicked, payload}, state) do
    if payload.nickname == state.nickname do
      # Bot was kicked — remove channel
      channel = payload.channel
      Phoenix.PubSub.unsubscribe(@pubsub, "channel:#{channel}")
      {:noreply, %{state | channels: Map.delete(state.channels, channel)}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:topic_changed, payload}, state) do
    state = handle_channel_event(:topic_changed, payload, state)
    {:noreply, state}
  end

  def handle_info({:capability_timer, cap_name, payload}, state) do
    state = handle_capability_timer(cap_name, payload, state)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Timer Infrastructure ──────────────────────────────────

  @spec schedule_capability_timer(state(), atom(), term(), non_neg_integer()) :: state()
  def schedule_capability_timer(state, cap_name, payload, delay_ms) do
    ref = Process.send_after(self(), {:capability_timer, cap_name, payload}, delay_ms)
    timers = Map.put(state.capability_timers, ref, {cap_name, payload})
    %{state | capability_timers: timers}
  end

  @spec cancel_capability_timers(state(), atom()) :: state()
  def cancel_capability_timers(state, cap_name) do
    {to_cancel, to_keep} =
      Enum.split_with(state.capability_timers, fn {_ref, {name, _}} -> name == cap_name end)

    Enum.each(to_cancel, fn {ref, _} -> Process.cancel_timer(ref) end)
    %{state | capability_timers: Map.new(to_keep)}
  end

  # ── Internal ────────────────────────────────────────────────

  @spec handle_channel_message(map(), state()) :: state()
  defp handle_channel_message(payload, state) do
    channel = payload.channel

    if payload.nickname == state.nickname or not state.enabled or
         not channel_enabled?(state, channel) do
      state
    else
      context = build_context(state, channel)

      # 1. Run passive capabilities (moderation) — always run, no cooldown
      state = dispatch_passive_capabilities(payload.content, payload.nickname, context, state)

      # 2. Run active capabilities (first-match-wins) — subject to cooldown
      if not in_cooldown?(state, channel) do
        {result, state} =
          dispatch_active_capabilities(
            :message,
            payload.content,
            payload.nickname,
            context,
            state
          )

        maybe_respond(state, channel, result)
      else
        state
      end
    end
  end

  @spec handle_channel_event(atom(), map(), state()) :: state()
  defp handle_channel_event(event, payload, state) do
    channel = Map.get(payload, :channel)
    nickname = Map.get(payload, :nickname)

    if state.enabled and
         nickname != state.nickname and
         channel != nil and
         channel_enabled?(state, channel) do
      context = build_context(state, channel)

      {result, state} =
        dispatch_active_capabilities(:event, event, payload, context, state)

      maybe_respond(state, channel, result)
    else
      state
    end
  end

  @spec dispatch_passive_capabilities(String.t(), String.t(), map(), state()) :: state()
  defp dispatch_passive_capabilities(content, author, context, state) do
    state.capabilities
    |> Enum.filter(fn {_name, cap_mod, _config} -> capability_passive?(cap_mod) end)
    |> Enum.reduce(state, fn {name, cap_mod, config}, acc ->
      cap_state = Map.get(acc.capability_states, name, %{})
      ctx = %{context | config: config, capability_state: cap_state}

      case cap_mod.handle_message(content, author, ctx) do
        {:side_effect, %{state_update: new_cap_state}} ->
          update_capability_state(acc, name, new_cap_state)

        {:side_effect, action} ->
          handle_side_effect(acc, context.channel, action)

        {:reply, text, new_cap_state} ->
          acc = update_capability_state(acc, name, new_cap_state)
          send_bot_message(context.channel, acc.nickname, text)
          acc

        {:reply, text} ->
          send_bot_message(context.channel, acc.nickname, text)
          acc

        :ignore ->
          acc
      end
    end)
  end

  @spec dispatch_active_capabilities(:message | :event, term(), term(), map(), state()) ::
          {RetroHexChat.Bots.Capability.capability_result(), state()}
  defp dispatch_active_capabilities(:message, content, author, context, state) do
    Enum.reduce_while(state.capabilities, {:ignore, state}, fn {name, cap_mod, config},
                                                               {_, acc} ->
      if capability_passive?(cap_mod),
        do: {:cont, {:ignore, acc}},
        else: dispatch_message_to_cap(name, cap_mod, config, content, author, context, acc)
    end)
  end

  defp dispatch_active_capabilities(:event, event, payload, context, state) do
    Enum.reduce_while(state.capabilities, {:ignore, state}, fn {name, cap_mod, config},
                                                               {_, acc} ->
      if capability_passive?(cap_mod),
        do: {:cont, {:ignore, acc}},
        else: dispatch_event_to_cap(name, cap_mod, config, event, payload, context, acc)
    end)
  end

  defp dispatch_message_to_cap(name, cap_mod, config, content, author, context, acc) do
    cap_state = Map.get(acc.capability_states, name, %{})
    ctx = %{context | config: merge_command_config(config, acc), capability_state: cap_state}

    case cap_mod.handle_message(content, author, ctx) do
      :ignore ->
        {:cont, {:ignore, acc}}

      {:reply, text, new_cap_state} ->
        {:halt, {{:reply, text}, update_capability_state(acc, name, new_cap_state)}}

      result ->
        {:halt, {result, acc}}
    end
  end

  defp dispatch_event_to_cap(name, cap_mod, config, event, payload, context, acc) do
    cap_state = Map.get(acc.capability_states, name, %{})
    ctx = %{context | config: config, capability_state: cap_state}

    case cap_mod.handle_event(event, payload, ctx) do
      :ignore -> {:cont, {:ignore, acc}}
      result -> {:halt, {result, acc}}
    end
  end

  @spec handle_capability_timer(atom(), term(), state()) :: state()
  defp handle_capability_timer(cap_name, payload, state) do
    case find_capability(state, cap_name) do
      {_name, cap_mod, config} ->
        cap_state = Map.get(state.capability_states, cap_name, %{})
        channel = Map.get(payload, :channel)
        ctx = build_context(state, channel || "")
        ctx = %{ctx | config: config, capability_state: cap_state}

        if function_exported?(cap_mod, :handle_timer, 3) do
          {result, new_cap_state} = cap_mod.handle_timer(payload, cap_state, ctx)
          state = update_capability_state(state, cap_name, new_cap_state)
          maybe_respond_timer(state, channel, result)
        else
          state
        end

      nil ->
        state
    end
  end

  @spec handle_side_effect(state(), String.t(), map()) :: state()
  defp handle_side_effect(state, channel, %{action: :warn, message: msg}) do
    send_bot_message(channel, state.nickname, msg)
    state
  end

  defp handle_side_effect(state, _channel, %{state_update: _}), do: state
  defp handle_side_effect(state, _channel, _action), do: state

  @spec capability_passive?(module()) :: boolean()
  defp capability_passive?(cap_mod) do
    function_exported?(cap_mod, :passive?, 0) and cap_mod.passive?()
  end

  @spec find_capability(state(), atom()) :: {atom(), module(), map()} | nil
  defp find_capability(state, cap_name) do
    Enum.find(state.capabilities, fn {name, _mod, _config} -> name == cap_name end)
  end

  @spec update_capability_state(state(), atom(), map()) :: state()
  defp update_capability_state(state, cap_name, new_state) do
    %{state | capability_states: Map.put(state.capability_states, cap_name, new_state)}
  end

  @spec merge_command_config(map(), state()) :: map()
  defp merge_command_config(config, state) do
    Map.put(config, "commands", state.custom_commands)
  end

  @spec maybe_respond(state(), String.t(), RetroHexChat.Bots.Capability.capability_result()) ::
          state()
  defp maybe_respond(state, _channel, :ignore), do: state

  defp maybe_respond(state, channel, {:reply, text}) do
    send_bot_message(channel, state.nickname, text)
    update_cooldown(state, channel)
  end

  defp maybe_respond(state, channel, {:reply_action, text}) do
    send_bot_message(channel, state.nickname, text)
    update_cooldown(state, channel)
  end

  defp maybe_respond(state, channel, {:multi_reply, lines}) do
    Enum.each(lines, fn line ->
      send_bot_message(channel, state.nickname, line)
    end)

    update_cooldown(state, channel)
  end

  defp maybe_respond(state, _channel, {:side_effect, _action}), do: state

  @spec maybe_respond_timer(
          state(),
          String.t() | nil,
          RetroHexChat.Bots.Capability.capability_result()
        ) ::
          state()
  defp maybe_respond_timer(state, nil, _result), do: state
  defp maybe_respond_timer(state, _channel, :ignore), do: state

  defp maybe_respond_timer(state, channel, {:reply, text}) do
    send_bot_message(channel, state.nickname, text)
    state
  end

  defp maybe_respond_timer(state, channel, {:multi_reply, lines}) do
    Enum.each(lines, &send_bot_message(channel, state.nickname, &1))
    state
  end

  defp maybe_respond_timer(state, _channel, _other), do: state

  @spec send_bot_message(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  defp send_bot_message(channel, nickname, content) do
    case Channels.Server.send_message(channel, nickname, content) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Bot #{nickname} failed to send: #{inspect(reason)}")
    end
  end

  @spec update_cooldown(state(), String.t()) :: state()
  defp update_cooldown(state, channel) do
    now = DateTime.utc_now()
    stats = %{state.stats | messages_handled: state.stats.messages_handled + 1}
    %{state | last_response_at: Map.put(state.last_response_at, channel, now), stats: stats}
  end

  @spec in_cooldown?(state(), String.t()) :: boolean()
  defp in_cooldown?(state, channel) do
    case Map.get(state.last_response_at, channel) do
      nil ->
        false

      last_at ->
        diff = DateTime.diff(DateTime.utc_now(), last_at, :millisecond)
        diff < state.cooldown_ms
    end
  end

  @spec channel_enabled?(state(), String.t()) :: boolean()
  defp channel_enabled?(state, channel) do
    case Map.get(state.channels, channel) do
      %{enabled: enabled} -> enabled
      nil -> false
    end
  end

  @spec build_context(state(), String.t()) :: map()
  defp build_context(state, channel) do
    %{
      bot_nickname: state.nickname,
      bot_name: state.name,
      channel: channel,
      command_prefix: state.command_prefix,
      config: %{},
      capability_state: %{}
    }
  end

  @spec build_initial_state(map()) :: state()
  defp build_initial_state(bot_data) do
    capabilities = build_capabilities(bot_data.capabilities || %{})
    channels = build_channels(bot_data[:channel_configs] || [])
    custom_commands = build_custom_commands(bot_data[:custom_commands] || [])
    capability_states = init_capability_states(capabilities)

    %{
      bot_id: bot_data.id,
      name: bot_data.name,
      nickname: bot_data.nickname,
      command_prefix: bot_data.command_prefix || "!",
      created_by: bot_data.created_by,
      enabled: bot_data.enabled,
      cooldown_ms: bot_data.cooldown_ms || 2000,
      capabilities: capabilities,
      channels: channels,
      custom_commands: custom_commands,
      last_response_at: %{},
      capability_states: capability_states,
      capability_timers: %{},
      stats: %{messages_handled: 0, commands_processed: 0, started_at: DateTime.utc_now()}
    }
  end

  @spec init_capability_states([{atom(), module(), map()}]) :: %{atom() => map()}
  defp init_capability_states(capabilities) do
    Map.new(capabilities, fn {name, cap_mod, config} ->
      cap_state =
        if function_exported?(cap_mod, :init_state, 1) do
          cap_mod.init_state(config)
        else
          %{}
        end

      {name, cap_state}
    end)
  end

  @spec init_capability_timers(state()) :: state()
  defp init_capability_timers(state) do
    Enum.reduce(state.capabilities, state, fn {name, cap_mod, config}, acc ->
      cap_state = Map.get(acc.capability_states, name, %{})

      if function_exported?(cap_mod, :init_timers, 4) do
        cap_mod.init_timers(acc, name, config, cap_state)
      else
        acc
      end
    end)
  end

  @spec build_capabilities(map()) :: [{atom(), module(), map()}]
  defp build_capabilities(cap_config) do
    cap_config
    |> Enum.filter(fn {_name, config} -> Map.get(config, "enabled", true) end)
    |> Enum.map(fn {name, config} ->
      atom_name = if is_binary(name), do: String.to_existing_atom(name), else: name
      module = Map.get(@capability_modules, atom_name)

      if module do
        {atom_name, module, config}
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec build_channels([map()]) :: %{String.t() => map()}
  defp build_channels(channel_configs) do
    Map.new(channel_configs, fn config ->
      channel_name =
        if is_struct(config), do: config.channel_name, else: Map.get(config, :channel_name)

      enabled = if is_struct(config), do: config.enabled, else: Map.get(config, :enabled, true)

      overrides =
        if is_struct(config),
          do: config.capability_overrides,
          else: Map.get(config, :capability_overrides, %{})

      {channel_name, %{enabled: enabled, capability_overrides: overrides}}
    end)
  end

  @spec build_custom_commands([map()]) :: %{String.t() => map()}
  defp build_custom_commands(commands) do
    Map.new(commands, fn cmd ->
      trigger = if is_struct(cmd), do: cmd.trigger, else: Map.get(cmd, :trigger)
      response = if is_struct(cmd), do: cmd.response, else: Map.get(cmd, :response)
      description = if is_struct(cmd), do: cmd.description, else: Map.get(cmd, :description, "")
      enabled = if is_struct(cmd), do: cmd.enabled, else: Map.get(cmd, :enabled, true)

      {trigger,
       %{"response" => response, "description" => description || "", "enabled" => enabled}}
    end)
  end

  @spec state_to_map(state()) :: map()
  defp state_to_map(state) do
    %{
      bot_id: state.bot_id,
      name: state.name,
      nickname: state.nickname,
      command_prefix: state.command_prefix,
      created_by: state.created_by,
      enabled: state.enabled,
      cooldown_ms: state.cooldown_ms,
      channels: Map.keys(state.channels),
      custom_commands: state.custom_commands,
      stats: state.stats
    }
  end

  @spec join_channel_process(String.t(), String.t()) :: :ok
  defp join_channel_process(channel_name, nickname) do
    # Ensure channel process exists, then join as bot
    case Channels.Registry.lookup(channel_name) do
      {:ok, _pid} ->
        Channels.Server.join(channel_name, nickname, nil, bot: true)
        :ok

      {:error, :not_found} ->
        Channels.Supervisor.start_child(channel_name)
        Channels.Server.join(channel_name, nickname, nil, bot: true)
        :ok
    end
  rescue
    _ -> :ok
  end

  @spec part_channel_process(String.t(), String.t()) :: :ok
  defp part_channel_process(channel_name, nickname) do
    Channels.Server.part(channel_name, nickname, "Bot leaving")
    :ok
  rescue
    _ -> :ok
  end

  @spec maybe_update(state(), atom(), map()) :: state()
  defp maybe_update(state, key, updates) do
    case Map.get(updates, key) do
      nil -> state
      value -> Map.put(state, key, value)
    end
  end

  @spec via(String.t()) :: {:via, Elixir.Registry, {atom(), String.t()}}
  defp via(bot_nickname), do: Registry.via_tuple(bot_nickname)
end
