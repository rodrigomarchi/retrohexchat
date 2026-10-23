defmodule RetroHexChat.Commands.Handlers.Unignore do
  @moduledoc "Handler for /unignore <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "unignore",
    category: :user,
    syntax: dgettext("commands", "/unignore <nickname>"),
    summary:
      dgettext(
        "commands",
        "Stop ignoring a user you previously blocked, making their messages visible again."
      ),
    description:
      dgettext(
        "commands",
        "Stop ignoring a user you previously blocked, making their messages visible again.\nNickname is required. Use /ignore with no args to see your ignore list first."
      ),
    examples: [
      dgettext("commands", "/unignore SpamBot")
    ],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "Remove user from ignore list")
      }
    ]

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /unignore <nickname>")}
  def validate(_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([nick | _], _context) do
    {:ok, :ui_action, :ignore_remove, %{nickname: nick}}
  end
end
