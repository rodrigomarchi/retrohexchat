defmodule RetroHexChat.Commands.Handlers.Devoice do
  @moduledoc "Handler for /devoice <nickname> — remove voice status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "devoice",
    category: :channel,
    syntax: dgettext("commands", "/devoice <nickname>"),
    summary: dgettext("commands", "Remove voice status from a user."),
    description:
      dgettext(
        "commands",
        "Remove voice status from a user. Shortcut for /mode -v <nickname>.\nRequires: half-operator, operator, or owner."
      ),
    examples: [dgettext("commands", "/devoice alice")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to remove voice from")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /devoice <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_half_op_or_above(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "-v", params: [nick]}}
    end
  end
end
