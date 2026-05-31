defmodule RetroHexChat.Bots.Capabilities.Dice do
  @moduledoc """
  Dice rolling capability for RPG games.

  Supports standard dice notation: NdS, NdS+M, NdS-M, NdSkh/klN.

  Examples:
    - `!Bot roll 2d6` → "Rolling 2d6: [3, 5] = 8"
    - `!Bot roll 4d6kh3` → "Rolling 4d6kh3: [6, 4, 3, 1] → keeping [6, 4, 3] = 13"
    - `!Bot roll d20+5` → "Rolling 1d20+5: [17] + 5 = 22"
  """
  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.Bots.Capability

  @max_dice_default 100
  @max_sides_default 1000

  # Regex for dice notation: [N]dS[kh/klK][+/-M]
  @dice_regex ~r/^(\d*)d(\d+)(?:(kh|kl)(\d+))?([+-]\d+)?$/i

  @impl true
  @spec name() :: atom()
  def name, do: :dice

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "Dice rolling for RPG games (e.g., 2d6, d20+5, 4d6kh3)")

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, _author, ctx) do
    prefix = ctx.command_prefix
    bot_name = ctx.bot_nickname

    case parse_command(content, prefix, bot_name) do
      {:roll, notation} -> do_roll(notation, ctx.config)
      :ignore -> :ignore
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
      "max_dice" => @max_dice_default,
      "max_sides" => @max_sides_default,
      "default_notation" => "d20"
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    max_dice = Map.get(config, "max_dice", @max_dice_default)
    max_sides = Map.get(config, "max_sides", @max_sides_default)

    cond do
      not is_integer(max_dice) or max_dice < 1 or max_dice > 1000 ->
        {:error, dgettext("bots", "max_dice must be between 1 and 1000")}

      not is_integer(max_sides) or max_sides < 2 or max_sides > 10_000 ->
        {:error, dgettext("bots", "max_sides must be between 2 and 10_000")}

      true ->
        :ok
    end
  end

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [
      %{trigger: "roll", description: dgettext("bots", "Roll dice (e.g., 2d6, d20+5, 4d6kh3)")},
      %{trigger: "dice", description: dgettext("bots", "Alias for roll")}
    ]
  end

  # ── Internal ──

  @spec parse_command(String.t(), String.t(), String.t()) :: {:roll, String.t()} | :ignore
  defp parse_command(content, prefix, bot_name) do
    lower = String.downcase(content)
    bot_lower = String.downcase(bot_name)
    cmd_prefix = String.downcase(prefix) <> bot_lower

    cond do
      String.starts_with?(lower, cmd_prefix <> " roll ") ->
        notation =
          content |> String.slice(String.length(cmd_prefix <> " roll ")..-1//1) |> String.trim()

        {:roll, notation}

      String.starts_with?(lower, cmd_prefix <> " dice ") ->
        notation =
          content |> String.slice(String.length(cmd_prefix <> " dice ")..-1//1) |> String.trim()

        {:roll, notation}

      String.starts_with?(lower, cmd_prefix <> " roll") ->
        {:roll, ""}

      String.starts_with?(lower, cmd_prefix <> " dice") ->
        {:roll, ""}

      true ->
        :ignore
    end
  end

  @spec do_roll(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp do_roll("", config) do
    default = Map.get(config, "default_notation", "d20")
    do_roll(default, config)
  end

  defp do_roll(notation, config) do
    max_dice = Map.get(config, "max_dice", @max_dice_default)
    max_sides = Map.get(config, "max_sides", @max_sides_default)

    case parse_notation(notation) do
      {:ok, parsed} ->
        validate_and_roll(parsed, notation, max_dice, max_sides)

      {:error, msg} ->
        {:reply, msg}
    end
  end

  @spec validate_and_roll(map(), String.t(), integer(), integer()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp validate_and_roll(parsed, notation, max_dice, max_sides) do
    cond do
      parsed.count > max_dice ->
        {:reply, dgettext("bots", "Error: Maximum %{max} dice allowed.", max: max_dice)}

      parsed.sides > max_sides ->
        {:reply, dgettext("bots", "Error: Maximum %{max} sides allowed.", max: max_sides)}

      parsed.sides < 2 ->
        {:reply, dgettext("bots", "Error: Dice must have at least 2 sides.")}

      true ->
        rolls = roll_dice(parsed.count, parsed.sides)
        {:reply, format_result(notation, rolls, parsed)}
    end
  end

  @type parsed_notation :: %{
          count: pos_integer(),
          sides: pos_integer(),
          modifier: integer(),
          keep: nil | {:high, pos_integer()} | {:low, pos_integer()}
        }

  @spec parse_notation(String.t()) :: {:ok, parsed_notation()} | {:error, String.t()}
  def parse_notation(notation) do
    notation = String.trim(notation)

    case Regex.run(@dice_regex, notation) do
      [_, count_str, sides_str, keep_dir, keep_n, mod_str] ->
        build_parsed(count_str, sides_str, keep_dir, keep_n, mod_str)

      [_, count_str, sides_str, keep_dir, keep_n] ->
        build_parsed(count_str, sides_str, keep_dir, keep_n, "")

      [_, count_str, sides_str] ->
        build_parsed(count_str, sides_str, "", "", "")

      _ ->
        {:error,
         dgettext(
           "bots",
           "Invalid dice notation '%{notation}'. Use format: NdS, NdS+M, NdSkh/klN",
           notation: notation
         )}
    end
  end

  @spec build_parsed(String.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, parsed_notation()} | {:error, String.t()}
  defp build_parsed(count_str, sides_str, keep_dir, keep_n, mod_str) do
    count = if count_str == "", do: 1, else: String.to_integer(count_str)
    sides = String.to_integer(sides_str)
    modifier = parse_modifier(mod_str)
    keep = parse_keep(keep_dir, keep_n, count)

    case keep do
      {:error, msg} -> {:error, msg}
      _ -> {:ok, %{count: count, sides: sides, modifier: modifier, keep: keep}}
    end
  end

  @spec parse_modifier(String.t()) :: integer()
  defp parse_modifier(""), do: 0
  defp parse_modifier("+" <> n), do: String.to_integer(n)
  defp parse_modifier("-" <> n), do: -String.to_integer(n)

  @spec parse_keep(String.t(), String.t(), integer()) ::
          nil | {:high, pos_integer()} | {:low, pos_integer()} | {:error, String.t()}
  defp parse_keep("", _, _count), do: nil

  defp parse_keep(dir, n_str, count) do
    n = String.to_integer(n_str)

    cond do
      n < 1 ->
        {:error, dgettext("bots", "Keep count must be at least 1.")}

      n > count ->
        {:error,
         dgettext("bots", "Cannot keep %{keep} dice when only rolling %{count}.",
           keep: n,
           count: count
         )}

      dir == "kh" ->
        {:high, n}

      dir == "kl" ->
        {:low, n}
    end
  end

  @spec roll_dice(pos_integer(), pos_integer()) :: [pos_integer()]
  defp roll_dice(count, sides) do
    Enum.map(1..count, fn _ -> :rand.uniform(sides) end)
  end

  @spec format_result(String.t(), [pos_integer()], parsed_notation()) :: String.t()
  defp format_result(notation, rolls, parsed) do
    case parsed.keep do
      nil ->
        format_simple_result(notation, rolls, parsed.modifier)

      {:high, n} ->
        format_keep_result(notation, rolls, n, :desc, parsed.modifier)

      {:low, n} ->
        format_keep_result(notation, rolls, n, :asc, parsed.modifier)
    end
  end

  @spec format_simple_result(String.t(), [pos_integer()], integer()) :: String.t()
  defp format_simple_result(notation, rolls, modifier) do
    sum = Enum.sum(rolls)
    rolls_str = format_rolls(rolls)

    if modifier == 0 do
      dgettext("bots", "Rolling %{notation}: %{rolls} = %{sum}",
        notation: notation,
        rolls: rolls_str,
        sum: sum
      )
    else
      sign = if modifier > 0, do: "+", else: ""

      dgettext("bots", "Rolling %{notation}: %{rolls} %{sign} %{modifier} = %{total}",
        notation: notation,
        rolls: rolls_str,
        sign: sign,
        modifier: modifier,
        total: sum + modifier
      )
    end
  end

  @spec format_keep_result(String.t(), [pos_integer()], pos_integer(), :asc | :desc, integer()) ::
          String.t()
  defp format_keep_result(notation, rolls, keep_n, direction, modifier) do
    sorted =
      case direction do
        :desc -> Enum.sort(rolls, :desc)
        :asc -> Enum.sort(rolls, :asc)
      end

    kept = Enum.take(sorted, keep_n)
    sum = Enum.sum(kept)
    rolls_str = format_rolls(rolls)
    kept_str = format_rolls(kept)

    base =
      dgettext("bots", "Rolling %{notation}: %{rolls} → keeping %{kept}",
        notation: notation,
        rolls: rolls_str,
        kept: kept_str
      )

    if modifier == 0 do
      dgettext("bots", "%{base} = %{sum}", base: base, sum: sum)
    else
      sign = if modifier > 0, do: "+", else: ""

      dgettext("bots", "%{base} %{sign} %{modifier} = %{total}",
        base: base,
        sign: sign,
        modifier: modifier,
        total: sum + modifier
      )
    end
  end

  defp format_rolls(rolls), do: "[" <> Enum.join(rolls, ", ") <> "]"
end
