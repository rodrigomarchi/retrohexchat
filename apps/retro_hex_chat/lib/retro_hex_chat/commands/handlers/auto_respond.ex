defmodule RetroHexChat.Commands.Handlers.AutoRespond do
  @moduledoc "Handler for /autorespond [subcommand] [args]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @valid_triggers ~w(on_join on_part on_nick_change)

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate("list"), do: :ok

  def validate("add " <> rest) do
    parts = String.split(rest, " ", trim: true)

    case parts do
      [trigger | cmd_parts] when trigger in @valid_triggers and cmd_parts != [] ->
        :ok

      [_trigger] ->
        {:error, "Usage: /autorespond add <trigger> [#channel] <command>"}

      _ ->
        {:error, "Usage: /autorespond add <on_join|on_part|on_nick_change> [#channel] <command>"}
    end
  end

  def validate("add"), do: {:error, "Usage: /autorespond add <trigger> [#channel] <command>"}

  def validate("remove " <> rest) do
    if String.trim(rest) == "" do
      {:error, "Usage: /autorespond remove <position>"}
    else
      :ok
    end
  end

  def validate("remove"), do: {:error, "Usage: /autorespond remove <position>"}

  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_autorespond_dialog, %{}}
  end

  def execute(["list"], _context) do
    {:ok, :ui_action, :autorespond_list_display, %{}}
  end

  def execute(["add", trigger_str | rest], _context) do
    case parse_trigger(trigger_str) do
      {:ok, trigger_event} ->
        {channel_filter, cmd_parts} = extract_channel_filter(rest)
        command = Enum.join(cmd_parts, " ")

        {:ok, :ui_action, :autorespond_added,
         %{trigger_event: trigger_event, channel_filter: channel_filter, command: command}}

      :error ->
        {:error,
         "Invalid trigger '#{trigger_str}'. Valid triggers: on_join, on_part, on_nick_change"}
    end
  end

  def execute(["remove", position_str], _context) do
    case Integer.parse(position_str) do
      {pos, ""} ->
        {:ok, :ui_action, :autorespond_removed, %{position: pos}}

      _ ->
        {:error, "Invalid position '#{position_str}'. Must be a number."}
    end
  end

  def execute(_args, _context) do
    {:ok, :system, %{content: help_text()}}
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "autorespond",
      syntax: "/autorespond [list|add|remove]",
      description:
        "Automatically run a command when someone joins, leaves, or changes their nickname.\nSubcommands: list, add <trigger> [#channel] <command>, remove <position>. No args opens the dialog.\nValid triggers: on_join, on_part, on_nick_change.\nUse $nick in your command to reference the triggering user. The remove subcommand takes a 0-based index number.",
      examples: [
        "/autorespond",
        "/autorespond list",
        "/autorespond add on_join #welcome /notice $nick Welcome!",
        "/autorespond add on_part /say $nick left",
        "/autorespond remove 0"
      ]
    }
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp parse_trigger("on_join"), do: {:ok, :on_join}
  defp parse_trigger("on_part"), do: {:ok, :on_part}
  defp parse_trigger("on_nick_change"), do: {:ok, :on_nick_change}
  defp parse_trigger(_), do: :error

  defp extract_channel_filter([first | rest]) when rest != [] do
    if String.starts_with?(first, "#") do
      {first, rest}
    else
      {nil, [first | rest]}
    end
  end

  defp extract_channel_filter(parts), do: {nil, parts}

  defp help_text do
    """
    Usage: /autorespond [list|add|remove]
    /autorespond add <on_join|on_part|on_nick_change> [#channel] <command>
    /autorespond remove <position>
    /autorespond list
    """
    |> String.trim()
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "autorespond",
      syntax: "/autorespond [list|add|remove]",
      description:
        "Automatically run a command when someone joins, leaves, or changes their nickname.",
      category: :config,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: false,
          type: :text,
          position: 0,
          description: "Subcommand: list, add, remove"
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: "Subcommand arguments"
        }
      ],
      examples: [
        "/autorespond",
        "/autorespond list",
        "/autorespond add on_join #welcome /notice $nick Welcome!",
        "/autorespond add on_part /say $nick left",
        "/autorespond remove 0"
      ],
      subcommands: [
        %{name: "list", description: "Show auto-respond rules"},
        %{name: "add", description: "Add an auto-respond rule"},
        %{name: "remove", description: "Remove an auto-respond rule"}
      ]
    }
  end
end
