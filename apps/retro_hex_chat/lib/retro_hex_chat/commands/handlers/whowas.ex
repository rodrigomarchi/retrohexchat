defmodule RetroHexChat.Commands.Handlers.Whowas do
  @moduledoc "Handler for /whowas <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "whowas",
    category: :user,
    syntax: dgettext("commands", "/whowas <nickname>"),
    summary: dgettext("commands", "Look up information about a user who recently disconnected."),
    description:
      dgettext(
        "commands",
        "Look up information about a user who recently disconnected.\nShows last seen time, channels, and quit message. Data cached for up to 1 hour.\nFor online users, use /whois instead."
      ),
    examples: [dgettext("commands", "/whowas SomeUser")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "Recently disconnected user")
      }
    ]

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /whowas <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /whowas <nickname>")}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :show_whowas_info, %{nickname: target}}
  end
end
