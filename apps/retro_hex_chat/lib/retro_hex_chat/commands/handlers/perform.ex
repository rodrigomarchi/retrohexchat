defmodule RetroHexChat.Commands.Handlers.Perform do
  @moduledoc "Handler for /perform [subcommand] [args]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate("list"), do: :ok
  def validate("clear"), do: :ok

  def validate("add " <> rest) do
    if String.trim(rest) == "" do
      {:error, dgettext("commands", "Usage: /perform add <command>")}
    else
      :ok
    end
  end

  def validate("add"), do: {:error, dgettext("commands", "Usage: /perform add <command>")}

  def validate("remove " <> rest) do
    case Integer.parse(String.trim(rest)) do
      {_, ""} ->
        :ok

      _ ->
        {:error,
         dgettext("commands", "Invalid position: %{string_trim_rest}. Must be a number.",
           string_trim_rest: String.trim(rest)
         )}
    end
  end

  def validate("remove"), do: {:error, dgettext("commands", "Usage: /perform remove <number>")}

  def validate("move " <> rest) do
    validate_move_args(String.trim(rest))
  end

  def validate("move"), do: {:error, dgettext("commands", "Usage: /perform move <from> <to>")}

  def validate(args) do
    subcmd = args |> String.split(" ", parts: 2) |> List.first()
    {:error, "Unknown subcommand: #{subcmd}. Use: list, add, remove, move, clear"}
  end

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_perform_dialog, %{}}
  end

  def execute(["list"], _context) do
    {:ok, :ui_action, :perform_list_display, %{}}
  end

  def execute(["add" | command_parts], _context) do
    command = Enum.join(command_parts, " ")
    {:ok, :ui_action, :perform_add, %{command: command}}
  end

  def execute(["remove", position_str], _context) do
    {position, ""} = Integer.parse(position_str)
    {:ok, :ui_action, :perform_remove, %{position: position}}
  end

  def execute(["move", from_str, to_str], _context) do
    {from, ""} = Integer.parse(from_str)
    {to, ""} = Integer.parse(to_str)
    {:ok, :ui_action, :perform_move, %{from: from, to: to}}
  end

  def execute(["clear"], _context) do
    {:ok, :ui_action, :perform_clear, %{}}
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
      name: "perform",
      syntax: dgettext("commands", "/perform [list|add|remove|move|clear]"),
      description:
        dgettext(
          "commands",
          "Set up commands that automatically run every time you connect.\nSubcommands: list, add <command>, remove <index>, move <from> <to>, clear. No args opens the dialog.\nCommon use: /perform add /ns identify mypassword\nPositions are 0-based index numbers. Passwords are masked in the list display."
        ),
      examples: [
        "/perform",
        dgettext("commands", "/perform list"),
        dgettext("commands", "/perform add /join #elixir"),
        dgettext("commands", "/perform add /ns identify mypassword"),
        dgettext("commands", "/perform remove 0"),
        dgettext("commands", "/perform move 0 2"),
        dgettext("commands", "/perform clear")
      ]
    }
  end

  @spec validate_move_args(String.t()) :: :ok | {:error, String.t()}
  defp validate_move_args(args) do
    case String.split(args, " ", trim: true) do
      [from_str, to_str] ->
        with {_, ""} <- Integer.parse(from_str),
             {_, ""} <- Integer.parse(to_str) do
          :ok
        else
          _ -> {:error, dgettext("commands", "Invalid positions. Must be numbers.")}
        end

      _ ->
        {:error, dgettext("commands", "Usage: /perform move <from> <to>")}
    end
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "perform",
      syntax: dgettext("commands", "/perform [list|add|remove|move|clear]"),
      description:
        dgettext(
          "commands",
          "Set up commands that automatically run every time you connect, like identifying with NickServ."
        ),
      category: :config,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: false,
          type: :text,
          position: 0,
          description: dgettext("commands", "Subcommand: list, add, remove, move, clear")
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Subcommand arguments")
        }
      ],
      examples: [
        "/perform",
        dgettext("commands", "/perform list"),
        dgettext("commands", "/perform add /join #elixir"),
        dgettext("commands", "/perform add /ns identify mypassword"),
        dgettext("commands", "/perform remove 0"),
        dgettext("commands", "/perform move 0 2"),
        dgettext("commands", "/perform clear")
      ],
      subcommands: [
        %{name: "list", description: dgettext("commands", "Show perform commands")},
        %{name: "add", description: dgettext("commands", "Add a command to perform on connect")},
        %{name: "remove", description: dgettext("commands", "Remove a perform command")},
        %{name: "move", description: dgettext("commands", "Reorder a perform command")},
        %{name: "clear", description: dgettext("commands", "Clear all perform commands")}
      ]
    }
  end
end
