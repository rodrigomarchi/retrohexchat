defmodule RetroHexChat.Commands.Handlers.Query do
  @moduledoc "Handler for /query <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "query",
    category: :user,
    syntax: dgettext("commands", "/query <nickname>"),
    summary:
      dgettext(
        "commands",
        "Open a private message tab with a user without sending any message, unlike /msg."
      ),
    description:
      dgettext(
        "commands",
        "Open a private message tab with a user without sending any message, unlike /msg.\nNickname is required. If the PM tab already exists, switches to it."
      ),
    examples: [dgettext("commands", "/query Nick")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "Open a PM tab with this user")
      }
    ]

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /query <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /query <nickname>")}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :open_query, %{nickname: target}}
  end
end
