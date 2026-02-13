defmodule RetroHexChat.Commands.Handlers.Alias do
  @moduledoc "Handler for /alias [subcommand] [args]"
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
      [_name] -> {:error, "Usage: /alias add <name> <expansion>"}
      _ -> {:error, "Usage: /alias add <name> <expansion>"}
    end
  end

  def validate("add"), do: {:error, "Usage: /alias add <name> <expansion>"}

  def validate("remove " <> rest) do
    if String.trim(rest) == "" do
      {:error, "Usage: /alias remove <name>"}
    else
      :ok
    end
  end

  def validate("remove"), do: {:error, "Usage: /alias remove <name>"}

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
      syntax: "/alias [list|add|remove]",
      description: "Manage command aliases. Type a short alias to expand into longer commands.",
      examples: [
        "/alias",
        "/alias list",
        "/alias add hi /me says hello everyone!",
        "/alias add greet /me waves at $1",
        "/alias remove hi"
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
      syntax: "/alias [list|add|remove]",
      description: "Manage command aliases. Type a short alias to expand into longer commands.",
      category: :config,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: false,
          type: :text,
          position: 0,
          description: "Subcomando: list, add, remove"
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: "Argumentos do subcomando"
        }
      ],
      examples: [
        "/alias",
        "/alias list",
        "/alias add hi /me says hello everyone!",
        "/alias add greet /me waves at $1",
        "/alias remove hi"
      ]
    }
  end
end
