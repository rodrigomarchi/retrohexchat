defmodule RetroHexChat.Commands.Handlers.Whois do
  @moduledoc "Handler for /whois <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "whois",
    category: :user,
    syntax: dgettext("commands", "/whois <nickname>"),
    summary: dgettext("commands", "Look up detailed information about an online user."),
    description:
      dgettext(
        "commands",
        "Look up detailed information about an online user.\nShows: nickname, channels (shared channels highlighted), idle time, away status, bio, and registration status.\nUser must be online. For offline users, use /whowas."
      ),
    examples: [dgettext("commands", "/whois SomeUser")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to look up"))
    ]

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /whois <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /whois <nickname>")}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :show_whois_info, %{nickname: target}}
  end
end
