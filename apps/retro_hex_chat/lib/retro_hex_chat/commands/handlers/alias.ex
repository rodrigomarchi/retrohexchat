defmodule RetroHexChat.Commands.Handlers.Alias do
  @moduledoc "Handler for /alias [subcommand] [args]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate("list"), do: :ok

  def validate("add " <> rest) do
    parts = String.split(rest, " ", parts: 2, trim: true)

    case parts do
      [_name, _expansion] -> :ok
      [_name] -> {:error, dgettext("commands", "Usage: /alias add <name> <expansion>")}
      _ -> {:error, dgettext("commands", "Usage: /alias add <name> <expansion>")}
    end
  end

  def validate("add"), do: {:error, dgettext("commands", "Usage: /alias add <name> <expansion>")}

  def validate("remove " <> rest) do
    if String.trim(rest) == "" do
      {:error, dgettext("commands", "Usage: /alias remove <name>")}
    else
      :ok
    end
  end

  def validate("remove"), do: {:error, dgettext("commands", "Usage: /alias remove <name>")}

  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_alias_dialog, %{}}
  end

  def execute(["add", name | expansion_parts], _context) do
    expansion = Enum.join(expansion_parts, " ")
    {:ok, :ui_action, :alias_added, %{name: name, expansion: expansion}}
  end

  def execute(["remove", name], _context) do
    {:ok, :ui_action, :alias_removed, %{name: name}}
  end

  def execute(["list"], _context) do
    {:ok, :ui_action, :alias_list_display, %{}}
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
      name: "alias",
      syntax: dgettext("commands", "/alias [list|add|remove]"),
      description:
        dgettext(
          "commands",
          "Create short command shortcuts that expand into longer commands.\nSubcommands: list, add <name> <expansion>, remove <name>. No args opens the dialog.\nSupports $1-$9 for positional arguments, $nick for your nickname, $chan for current channel.\nMax 50 aliases. Registered users: persisted. Guests: session-only."
        ),
      examples: [
        "/alias",
        dgettext("commands", "/alias list"),
        dgettext("commands", "/alias add hi /me says hello everyone!"),
        dgettext("commands", "/alias add greet /me waves at $1"),
        dgettext("commands", "/alias remove hi")
      ]
    }
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "alias",
      syntax: dgettext("commands", "/alias [list|add|remove]"),
      description:
        dgettext("commands", "Create short command shortcuts that expand into longer commands."),
      category: :config,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: false,
          type: :text,
          position: 0,
          description: dgettext("commands", "Subcommand: list, add, remove")
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
        "/alias",
        dgettext("commands", "/alias list"),
        dgettext("commands", "/alias add hi /me says hello everyone!"),
        dgettext("commands", "/alias add greet /me waves at $1"),
        dgettext("commands", "/alias remove hi")
      ],
      subcommands: [
        %{name: "add", description: dgettext("commands", "Create a new command alias")},
        %{name: "remove", description: dgettext("commands", "Remove an existing alias")},
        %{name: "list", description: dgettext("commands", "Show all defined aliases")}
      ]
    }
  end
end
