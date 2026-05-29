defmodule RetroHexChat.Chat.TimerManager do
  @moduledoc """
  Pure functions for timer validation, parsing, and state management.
  Timer refs and scheduling are managed by the LiveView process.
  """

  @max_timers 5
  @max_name_length 30
  @min_once_interval 1
  @min_repeat_interval 10
  @max_interval 86_400
  @name_pattern ~r/^[a-zA-Z0-9_-]+$/

  @spec parse_timer_args([String.t()]) :: {:ok, map()} | {:error, String.t()}
  def parse_timer_args([]) do
    {:error, "Usage: /timer <name> [repeat] <seconds> <command>"}
  end

  def parse_timer_args(["list"]) do
    {:ok, %{action: :list}}
  end

  def parse_timer_args(["stop"]) do
    {:error, "Usage: /timer stop <name>"}
  end

  def parse_timer_args(["stop", name]) do
    {:ok, %{action: :stop, name: name}}
  end

  def parse_timer_args([name, "repeat", interval_str | command_parts])
      when command_parts != [] do
    case Integer.parse(interval_str) do
      {interval, ""} ->
        {:ok,
         %{
           action: :create,
           name: name,
           type: :repeat,
           interval: interval,
           command: Enum.join(command_parts, " ")
         }}

      _ ->
        {:error, "Invalid interval: #{interval_str}. Must be a number of seconds."}
    end
  end

  def parse_timer_args([_name, "repeat", _interval_str]) do
    {:error, "Usage: /timer <name> repeat <seconds> <command>"}
  end

  def parse_timer_args([_name, "repeat"]) do
    {:error, "Usage: /timer <name> repeat <seconds> <command>"}
  end

  def parse_timer_args([name, interval_str | command_parts]) when command_parts != [] do
    case Integer.parse(interval_str) do
      {interval, ""} ->
        {:ok,
         %{
           action: :create,
           name: name,
           type: :once,
           interval: interval,
           command: Enum.join(command_parts, " ")
         }}

      _ ->
        {:error, "Invalid interval: #{interval_str}. Must be a number of seconds."}
    end
  end

  def parse_timer_args([_name, _interval_str]) do
    {:error, "Usage: /timer <name> <seconds> <command>"}
  end

  def parse_timer_args([_name]) do
    {:error, "Usage: /timer <name> <seconds> <command>"}
  end

  @spec validate_create(map(), String.t(), :once | :repeat, integer(), String.t()) ::
          :ok | {:error, String.t()}
  def validate_create(timers, name, type, interval, _command) do
    with :ok <- validate_timer_name(name),
         :ok <- validate_timer_limit(timers, name),
         :ok <- validate_timer_interval(type, interval) do
      :ok
    end
  end

  defp validate_timer_name(name) do
    if valid_name?(name) do
      :ok
    else
      {:error,
       "Invalid timer name. Use only letters, numbers, hyphens, underscores (max #{@max_name_length} chars)."}
    end
  end

  defp validate_timer_limit(timers, name) do
    if map_size(timers) >= @max_timers and not Map.has_key?(timers, name) do
      {:error, "Maximum #{@max_timers} concurrent timers reached. Stop one first."}
    else
      :ok
    end
  end

  defp validate_timer_interval(:once, interval) when interval < @min_once_interval do
    {:error, "Minimum interval for one-shot timers is #{@min_once_interval} second."}
  end

  defp validate_timer_interval(_type, interval) when interval > @max_interval do
    {:error, "Maximum interval is #{@max_interval} seconds (24 hours)."}
  end

  defp validate_timer_interval(_type, _interval), do: :ok

  @spec clamp_interval(:once | :repeat, integer()) :: {integer(), String.t() | nil}
  def clamp_interval(:repeat, interval) when interval < @min_repeat_interval do
    {@min_repeat_interval, "Repeat interval clamped to minimum #{@min_repeat_interval} seconds."}
  end

  def clamp_interval(_type, interval), do: {interval, nil}

  @spec format_timer_list(map()) :: String.t()
  def format_timer_list(timers) when map_size(timers) == 0 do
    "No active timers."
  end

  def format_timer_list(timers) do
    lines =
      timers
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map(fn {name, info} ->
        "  #{name} (#{info.type}, #{info.interval}s) → #{info.command}"
      end)

    "Active timers:\n" <> Enum.join(lines, "\n")
  end

  defp valid_name?(name) do
    name != "" and
      String.length(name) <= @max_name_length and
      Regex.match?(@name_pattern, name)
  end
end
