defmodule RetroHexChat.Commands.Handlers.AutoRespond do
  @moduledoc "Handler for /autorespond [subcommand] [args]"
  use Gettext, backend: RetroHexChat.Gettext

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  alias RetroHexChat.Commands.CommandSyntax.Parameter

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  alias RetroHexChat.Commands.Handler

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  alias RetroHexChat.Commands.Handler.Args

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "autorespond",
    category: :config,
    syntax: dgettext("commands", "/autorespond [list|add|remove]"),
    summary:
      dgettext(
        "commands",
        "Automatically run a command when someone joins, leaves, or changes their nickname."
      ),
    description:
      dgettext(
        "commands",
        "Automatically run a command when someone joins, leaves, or changes their nickname.\nSubcommands: list, add <trigger> [#channel] <command>, remove <position>. No args opens the dialog.\nValid triggers: on_join, on_part, on_nick_change.\nUse $nick in your command to reference the triggering user. The remove subcommand takes a 0-based index number."
      ),
    examples: [
      "/autorespond",
      dgettext("commands", "/autorespond list"),
      dgettext("commands", "/autorespond add on_join #welcome /notice $nick Welcome!"),
      dgettext("commands", "/autorespond add on_part /me waves goodbye to $nick"),
      dgettext("commands", "/autorespond remove 0")
    ],
    parameters: [
      Parameter.optional(
        :text,
        "subcommand",
        dgettext("commands", "Subcommand: list, add, remove")
      ),
      Parameter.optional(:text, "args", dgettext("commands", "Subcommand arguments"))
    ],
    subcommands: [
      %{name: "list", description: dgettext("commands", "Show auto-respond rules")},
      %{name: "add", description: dgettext("commands", "Add an auto-respond rule")},
      %{name: "remove", description: dgettext("commands", "Remove an auto-respond rule")}
    ]

  @valid_triggers ~w(on_join on_part on_nick_change)

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  def validate(""), do: :ok
  def validate("list"), do: :ok

  def validate("add " <> rest) do
    parts = String.split(rest, " ", trim: true)

    case parts do
      [trigger | cmd_parts] when trigger in @valid_triggers and cmd_parts != [] ->
        :ok

      [_trigger] ->
        {:error, dgettext("commands", "Usage: /autorespond add <trigger> [#channel] <command>")}

      _ ->
        {:error,
         dgettext(
           "commands",
           "Usage: /autorespond add <on_join|on_part|on_nick_change> [#channel] <command>"
         )}
    end
  end

  def validate("add"),
    do: {:error, dgettext("commands", "Usage: /autorespond add <trigger> [#channel] <command>")}

  def validate("remove " <> rest),
    do: Args.present(rest, dgettext("commands", "Usage: /autorespond remove <position>"))

  def validate("remove"),
    do: {:error, dgettext("commands", "Usage: /autorespond remove <position>")}

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
         dgettext(
           "commands",
           "Invalid trigger '%{trigger_str}'. Valid triggers: on_join, on_part, on_nick_change",
           trigger_str: trigger_str
         )}
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
end
