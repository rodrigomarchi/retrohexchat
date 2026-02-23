defmodule RetroHexChat.Bots.Capabilities.Scheduler do
  @moduledoc """
  Scheduled/periodic message capability.

  Supports:
  - Interval schedules (every N minutes)
  - Daily schedules (at HH:MM UTC)

  Commands via chat:
  - `!Bot schedule add interval <min> <#channel> <message>`
  - `!Bot schedule add daily <HH:MM> <#channel> <message>`
  - `!Bot schedule list`
  - `!Bot schedule remove <id>`
  """
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.Server

  @impl true
  @spec name() :: atom()
  def name, do: :scheduler

  @impl true
  @spec description() :: String.t()
  def description, do: "Scheduled and periodic messages"

  @impl true
  @spec init_state(map()) :: map()
  def init_state(config) do
    schedules = Map.get(config, "schedules", [])

    %{
      schedules:
        Enum.map(schedules, fn s ->
          Map.merge(%{"last_fired" => nil}, s)
        end)
    }
  end

  @impl true
  @spec init_timers(map(), atom(), map(), map()) :: map()
  def init_timers(server_state, cap_name, _config, cap_state) do
    schedules = cap_state.schedules

    Enum.reduce(schedules, server_state, fn schedule, acc ->
      delay = calculate_next_delay(schedule)

      if delay > 0 do
        payload = %{channel: schedule["channel"], schedule_id: schedule["id"]}

        Server.schedule_capability_timer(acc, cap_name, payload, delay)
      else
        acc
      end
    end)
  end

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, _author, ctx) do
    prefix = ctx.command_prefix
    bot_name = ctx.bot_nickname
    state = ctx.capability_state
    config = ctx.config

    case parse_command(content, prefix, bot_name) do
      {:schedule, "list"} ->
        handle_list(state)

      {:schedule, "add " <> rest} ->
        handle_add(rest, state, config)

      {:schedule, "remove " <> id} ->
        handle_remove(String.trim(id), state)

      :ignore ->
        :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec handle_timer(term(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  def handle_timer(%{schedule_id: sched_id, channel: _channel}, state, _ctx) do
    case find_schedule(state.schedules, sched_id) do
      nil ->
        {:ignore, state}

      schedule ->
        message = schedule["message"]
        # Update last_fired
        new_schedules = update_schedule_fired(state.schedules, sched_id)
        new_state = %{state | schedules: new_schedules}
        # The server will need to reschedule — handled by returning the result
        # For now, just fire the message
        {{:reply, message}, new_state}
    end
  end

  def handle_timer(_payload, state, _ctx), do: {:ignore, state}

  @impl true
  @spec reschedule_delay(map(), map()) :: {:reschedule, non_neg_integer(), map()} | :no_reschedule
  def reschedule_delay(%{schedule_id: sched_id} = payload, cap_state) do
    case find_schedule(cap_state.schedules, sched_id) do
      nil ->
        :no_reschedule

      schedule ->
        delay = calculate_next_delay(schedule)

        if delay > 0,
          do: {:reschedule, delay, payload},
          else: :no_reschedule
    end
  end

  def reschedule_delay(_payload, _cap_state), do: :no_reschedule

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "enabled" => true,
      "max_schedules" => 10,
      "min_interval_min" => 5,
      "timezone" => "UTC",
      "schedules" => []
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [
      %{trigger: "schedule add", description: "Add a scheduled message"},
      %{trigger: "schedule list", description: "List active schedules"},
      %{trigger: "schedule remove", description: "Remove a schedule"}
    ]
  end

  # ── Command Parsing ──

  @spec parse_command(String.t(), String.t(), String.t()) :: {:schedule, String.t()} | :ignore
  defp parse_command(content, prefix, bot_name) do
    lower = String.downcase(content)
    cmd_prefix = String.downcase(prefix) <> String.downcase(bot_name)

    if String.starts_with?(lower, cmd_prefix <> " schedule ") do
      sub =
        content
        |> String.slice(String.length(cmd_prefix <> " schedule ")..-1//1)
        |> String.trim()

      {:schedule, String.downcase(sub)}
    else
      :ignore
    end
  end

  # ── Handlers ──

  @spec handle_list(map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_list(state) do
    schedules = state.schedules

    if schedules == [] do
      {:reply, "No active schedules."}
    else
      lines =
        Enum.map(schedules, fn s ->
          type_str = format_schedule_type(s)
          "  #{s["id"]} | #{type_str} | #{s["channel"]} | #{truncate(s["message"], 40)}"
        end)

      {:multi_reply, ["Active schedules:" | lines]}
    end
  end

  @spec handle_add(String.t(), map(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_add(rest, state, config) do
    max = Map.get(config, "max_schedules", 10)
    min_interval = Map.get(config, "min_interval_min", 5)

    if length(state.schedules) >= max do
      {:reply, "Maximum #{max} schedules reached."}
    else
      case parse_add_args(rest) do
        {:interval, minutes, channel, message} ->
          add_interval(minutes, channel, message, min_interval, state)

        {:daily, time, channel, message} ->
          add_daily(time, channel, message, state)

        :error ->
          {:reply,
           "Usage: schedule add interval <min> <#channel> <message> OR schedule add daily <HH:MM> <#channel> <message>"}
      end
    end
  end

  @spec add_interval(integer(), String.t(), String.t(), integer(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp add_interval(minutes, channel, message, min_interval, state) do
    if minutes < min_interval do
      {:reply, "Minimum interval is #{min_interval} minutes."}
    else
      id = generate_id()

      schedule = %{
        "id" => id,
        "type" => "interval",
        "interval_min" => minutes,
        "channel" => channel,
        "message" => message,
        "last_fired" => nil
      }

      new_state = %{state | schedules: state.schedules ++ [schedule]}
      {:reply, "Schedule '#{id}' added: every #{minutes}min in #{channel}.", new_state}
    end
  end

  @spec add_daily(String.t(), String.t(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp add_daily(time, channel, message, state) do
    if valid_time?(time) do
      id = generate_id()

      schedule = %{
        "id" => id,
        "type" => "daily",
        "time" => time,
        "channel" => channel,
        "message" => message,
        "last_fired" => nil
      }

      new_state = %{state | schedules: state.schedules ++ [schedule]}
      {:reply, "Schedule '#{id}' added: daily at #{time} UTC in #{channel}.", new_state}
    else
      {:reply, "Invalid time format. Use HH:MM (24h UTC)."}
    end
  end

  @spec handle_remove(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_remove(id, state) do
    if find_schedule(state.schedules, id) do
      new_schedules = Enum.reject(state.schedules, &(&1["id"] == id))
      new_state = %{state | schedules: new_schedules}
      {:reply, "Schedule '#{id}' removed.", new_state}
    else
      {:reply, "Schedule '#{id}' not found."}
    end
  end

  # ── Helpers ──

  @spec parse_add_args(String.t()) ::
          {:interval, integer(), String.t(), String.t()}
          | {:daily, String.t(), String.t(), String.t()}
          | :error
  defp parse_add_args(rest) do
    case String.split(rest, " ", parts: 4) do
      ["interval", min_str, channel, message] ->
        case Integer.parse(min_str) do
          {min, _} -> {:interval, min, ensure_hash(channel), message}
          :error -> :error
        end

      ["daily", time, channel, message] ->
        {:daily, time, ensure_hash(channel), message}

      _ ->
        :error
    end
  end

  @spec find_schedule([map()], String.t()) :: map() | nil
  defp find_schedule(schedules, id) do
    Enum.find(schedules, &(&1["id"] == id))
  end

  @spec update_schedule_fired([map()], String.t()) :: [map()]
  defp update_schedule_fired(schedules, id) do
    Enum.map(schedules, fn s ->
      if s["id"] == id do
        Map.put(s, "last_fired", DateTime.to_iso8601(DateTime.utc_now()))
      else
        s
      end
    end)
  end

  @spec calculate_next_delay(map()) :: non_neg_integer()
  def calculate_next_delay(%{"type" => "interval", "interval_min" => min}) do
    min * 60 * 1000
  end

  def calculate_next_delay(%{"type" => "daily", "time" => time}) do
    case parse_time(time) do
      {:ok, {hour, minute}} ->
        now = DateTime.utc_now()
        target_today = %{now | hour: hour, minute: minute, second: 0, microsecond: {0, 0}}

        diff = DateTime.diff(target_today, now, :millisecond)

        if diff > 0, do: diff, else: diff + 86_400_000

      :error ->
        3_600_000
    end
  end

  def calculate_next_delay(_), do: 0

  @spec parse_time(String.t()) :: {:ok, {non_neg_integer(), non_neg_integer()}} | :error
  defp parse_time(time) do
    case String.split(time, ":") do
      [h, m] ->
        with {hour, _} <- Integer.parse(h),
             {minute, _} <- Integer.parse(m),
             true <- hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 do
          {:ok, {hour, minute}}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  @spec valid_time?(String.t()) :: boolean()
  defp valid_time?(time), do: match?({:ok, _}, parse_time(time))

  @spec generate_id() :: String.t()
  defp generate_id do
    "s" <> (:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower))
  end

  @spec format_schedule_type(map()) :: String.t()
  defp format_schedule_type(%{"type" => "interval", "interval_min" => min}), do: "q/#{min}min"
  defp format_schedule_type(%{"type" => "daily", "time" => time}), do: "daily@#{time}"
  defp format_schedule_type(_), do: "unknown"

  @spec truncate(String.t(), pos_integer()) :: String.t()
  defp truncate(str, max) do
    if String.length(str) > max do
      String.slice(str, 0, max - 3) <> "..."
    else
      str
    end
  end

  @spec ensure_hash(String.t()) :: String.t()
  defp ensure_hash("#" <> _ = ch), do: ch
  defp ensure_hash(ch), do: "#" <> ch
end
