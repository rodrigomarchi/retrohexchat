defmodule RetroHexChat.Commands.Handlers.Notify do
  @moduledoc "Handler for /notify [add|remove|edit|list] [args]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate("list"), do: :ok

  def validate("add") do
    {:error, dgettext("commands", "Usage: /notify add <nickname> [note]")}
  end

  def validate("add " <> _rest), do: :ok

  def validate("remove") do
    {:error, dgettext("commands", "Usage: /notify remove <nickname>")}
  end

  def validate("remove " <> _rest), do: :ok

  def validate("edit") do
    {:error, dgettext("commands", "Usage: /notify edit <nickname> <note>")}
  end

  def validate("edit " <> rest) do
    case String.split(rest) do
      [_nick] -> {:error, dgettext("commands", "Usage: /notify edit <nickname> <note>")}
      [_nick | _note_words] -> :ok
    end
  end

  def validate(_),
    do: {:error, dgettext("commands", "Unknown /notify subcommand. Use: add, remove, edit, list")}

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_notify_list, %{}}
  end

  def execute(["add", nick], _context) do
    {:ok, :ui_action, :notify_add, %{nickname: nick, note: nil}}
  end

  def execute(["add", nick | rest], _context) do
    {:ok, :ui_action, :notify_add, %{nickname: nick, note: Enum.join(rest, " ")}}
  end

  def execute(["remove", nick], _context) do
    {:ok, :ui_action, :notify_remove, %{nickname: nick}}
  end

  def execute(["edit", nick | rest], _context) do
    {:ok, :ui_action, :notify_edit, %{nickname: nick, note: Enum.join(rest, " ")}}
  end

  def execute(["list"], _context) do
    {:ok, :ui_action, :notify_list_display, %{}}
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
      name: "notify",
      syntax: dgettext("commands", "/notify [add|remove|edit|list] [args]"),
      description:
        dgettext(
          "commands",
          "Track when specific users come online or go offline with your buddy list.\nSubcommands: add <nick> [note], remove <nick>, edit <nick> <note>, list. No args opens the dialog.\nRegistered users: persisted. Guests: session-only."
        ),
      examples: [
        dgettext("commands", "/notify add Alice Works on Elixir"),
        dgettext("commands", "/notify remove Alice"),
        dgettext("commands", "/notify edit Alice New note"),
        dgettext("commands", "/notify list"),
        "/notify"
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
      command: "notify",
      syntax: dgettext("commands", "/notify [add|remove|edit|list] [args]"),
      description:
        dgettext(
          "commands",
          "Track when specific users come online or go offline with your buddy list."
        ),
      category: :config,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: false,
          type: :text,
          position: 0,
          description: dgettext("commands", "Subcommand: add, remove, edit, list")
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
        dgettext("commands", "/notify add Alice Works on Elixir"),
        dgettext("commands", "/notify remove Alice"),
        dgettext("commands", "/notify edit Alice New note"),
        dgettext("commands", "/notify list"),
        "/notify"
      ],
      subcommands: [
        %{name: "add", description: dgettext("commands", "Add a user to your notify list")},
        %{
          name: "remove",
          description: dgettext("commands", "Remove a user from your notify list")
        },
        %{name: "edit", description: dgettext("commands", "Edit a user's note")},
        %{name: "list", description: dgettext("commands", "Show your notify list")}
      ]
    }
  end
end
