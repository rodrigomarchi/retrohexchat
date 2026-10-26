defmodule RetroHexChat.Commands.Handlers.Unignore do
  @moduledoc "Handler for /unignore <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "unignore",
    category: :user,
    usage: dgettext("commands", "Usage: /unignore <nickname>"),
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
      Parameter.required(:nick, "nickname", dgettext("commands", "Remove user from ignore list"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([nick | _], _context) do
    {:ok, :ui_action, :ignore_remove, %{nickname: nick}}
  end
end
