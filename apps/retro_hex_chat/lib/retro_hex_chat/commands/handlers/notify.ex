defmodule RetroHexChat.Commands.Handlers.Notify do
  @moduledoc "Handler for /notify [add|remove|edit|list] [args]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate("list"), do: :ok

  def validate("add") do
    {:error, "Usage: /notify add <nickname> [note]"}
  end

  def validate("add " <> _rest), do: :ok

  def validate("remove") do
    {:error, "Usage: /notify remove <nickname>"}
  end

  def validate("remove " <> _rest), do: :ok

  def validate("edit") do
    {:error, "Usage: /notify edit <nickname> <note>"}
  end

  def validate("edit " <> rest) do
    case String.split(rest) do
      [_nick] -> {:error, "Usage: /notify edit <nickname> <note>"}
      [_nick | _note_words] -> :ok
    end
  end

  def validate(_), do: {:error, "Unknown /notify subcommand. Use: add, remove, edit, list"}

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
      syntax: "/notify [add|remove|edit|list] [args]",
      description: "Manage your notify (buddy) list.",
      examples: [
        "/notify add Alice Works on Elixir",
        "/notify remove Alice",
        "/notify edit Alice New note",
        "/notify list",
        "/notify"
      ]
    }
  end
end
