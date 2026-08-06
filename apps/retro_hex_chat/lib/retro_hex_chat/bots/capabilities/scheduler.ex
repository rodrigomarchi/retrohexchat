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

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.Capabilities.Scheduler.Durable
  alias RetroHexChat.Bots.Policy

  require Logger

  @impl true
  @spec name() :: atom()
  def name, do: :scheduler

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "Scheduled and periodic messages")

  # A schedule an operator set up is a standing instruction, not scratch state:
  # it has to be there after a deploy, or the room goes quiet without anyone
  # touching anything.
  @impl true
  @spec durable_keys() :: [atom()]
  def durable_keys, do: [:schedules]

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
  def init_timers(server_state, _cap_name, _config, cap_state) do
    case Durable.reconcile(server_state.bot_id, cap_state.schedules) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Bot schedule durable reconcile failed for #{server_state.bot_id}: #{inspect(reason)}"
        )
    end

    server_state
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
        if_admin(ctx, fn -> handle_list(state) end)

      {:schedule, "add " <> rest} ->
        if_admin(ctx, fn -> handle_add(rest, state, config) end)

      {:schedule, "remove " <> id} ->
        if_admin(ctx, fn -> handle_remove(String.trim(id), state) end)

      :ignore ->
        :ignore
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

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
      %{trigger: "schedule add", description: dgettext("bots", "Add a scheduled message")},
      %{trigger: "schedule list", description: dgettext("bots", "List active schedules")},
      %{trigger: "schedule remove", description: dgettext("bots", "Remove a schedule")}
    ]
  end

  # A schedule makes the bot speak on a timer, unattended, in a room the author
  # need not be in. That is bot configuration, so it answers to whoever runs the
  # server rather than to whoever holds ops where the bot happens to be sitting.
  @spec if_admin(map(), (-> RetroHexChat.Bots.Capability.capability_result())) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp if_admin(ctx, fun) do
    if Policy.admin?(Map.get(ctx, :author)) do
      fun.()
    else
      {:reply, dgettext("bots", "Only server administrators can manage schedules.")}
    end
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
      {:reply, dgettext("bots", "No active schedules.")}
    else
      lines =
        Enum.map(schedules, fn s ->
          type_str = format_schedule_type(s)

          dgettext("bots", "  %{id} | %{type} | %{channel} | %{message}",
            id: s["id"],
            type: type_str,
            channel: s["channel"],
            message: truncate(s["message"], 40)
          )
        end)

      {:multi_reply, [dgettext("bots", "Active schedules:") | lines]}
    end
  end

  @spec handle_add(String.t(), map(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_add(rest, state, config) do
    max = Map.get(config, "max_schedules", 10)
    min_interval = Map.get(config, "min_interval_min", 5)

    if length(state.schedules) >= max do
      {:reply, dgettext("bots", "Maximum %{max} schedules reached.", max: max)}
    else
      case parse_add_args(rest) do
        {:interval, minutes, channel, message} ->
          add_interval(minutes, channel, message, min_interval, state)

        {:daily, time, channel, message} ->
          add_daily(time, channel, message, state)

        :error ->
          {:reply,
           dgettext(
             "bots",
             "Usage: schedule add interval <min> <#channel> <message> OR schedule add daily <HH:MM> <#channel> <message>"
           )}
      end
    end
  end

  @spec add_interval(integer(), String.t(), String.t(), integer(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp add_interval(minutes, channel, message, min_interval, state) do
    if minutes < min_interval do
      {:reply, dgettext("bots", "Minimum interval is %{minutes} minutes.", minutes: min_interval)}
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

      {:reply,
       dgettext("bots", "Schedule '%{id}' added: every %{minutes}min in %{channel}.",
         id: id,
         minutes: minutes,
         channel: channel
       ), new_state}
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

      {:reply,
       dgettext("bots", "Schedule '%{id}' added: daily at %{time} UTC in %{channel}.",
         id: id,
         time: time,
         channel: channel
       ), new_state}
    else
      {:reply, dgettext("bots", "Invalid time format. Use HH:MM (24h UTC).")}
    end
  end

  @spec handle_remove(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_remove(id, state) do
    if find_schedule(state.schedules, id) do
      new_schedules = Enum.reject(state.schedules, &(&1["id"] == id))
      new_state = %{state | schedules: new_schedules}
      {:reply, dgettext("bots", "Schedule '%{id}' removed.", id: id), new_state}
    else
      {:reply, dgettext("bots", "Schedule '%{id}' not found.", id: id)}
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
  def find_schedule(schedules, id) do
    Enum.find(schedules, &(&1["id"] == id))
  end

  @spec mark_schedule_fired([map()], String.t()) :: [map()]
  @spec mark_schedule_fired([map()], String.t(), DateTime.t()) :: [map()]
  def mark_schedule_fired(schedules, id, now \\ DateTime.utc_now()) do
    Enum.map(schedules, fn s ->
      if s["id"] == id do
        Map.put(s, "last_fired", DateTime.to_iso8601(now))
      else
        s
      end
    end)
  end

  @spec calculate_next_delay(map()) :: non_neg_integer()
  @spec calculate_next_delay(map(), DateTime.t()) :: non_neg_integer()
  def calculate_next_delay(schedule, now \\ DateTime.utc_now())

  def calculate_next_delay(%{"type" => "interval", "interval_min" => min}, _now) do
    min * 60 * 1000
  end

  def calculate_next_delay(%{"type" => "daily", "time" => time}, %DateTime{} = now) do
    case parse_time(time) do
      {:ok, {hour, minute}} ->
        target_today = %{now | hour: hour, minute: minute, second: 0, microsecond: {0, 0}}

        diff = DateTime.diff(target_today, now, :millisecond)

        if diff > 0, do: diff, else: diff + 86_400_000

      :error ->
        3_600_000
    end
  end

  def calculate_next_delay(_schedule, _now), do: 0

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
  defp format_schedule_type(%{"type" => "interval", "interval_min" => min}),
    do: dgettext("bots", "q/%{minutes}min", minutes: min)

  defp format_schedule_type(%{"type" => "daily", "time" => time}),
    do: dgettext("bots", "daily@%{time}", time: time)

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
