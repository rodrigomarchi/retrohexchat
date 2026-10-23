defmodule RetroHexChat.Commands.Handlers.Deop do
  @moduledoc "Handler for /deop <nickname> — remove channel operator status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "deop",
    category: :channel,
    syntax: dgettext("commands", "/deop <nickname>"),
    summary: dgettext("commands", "Remove channel operator status from a user."),
    description:
      dgettext(
        "commands",
        "Remove channel operator status from a user. Shortcut for /mode -o <nickname>.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/deop alice")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to remove operator status from")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /deop <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "-o", params: [nick]}}
    end
  end
end
