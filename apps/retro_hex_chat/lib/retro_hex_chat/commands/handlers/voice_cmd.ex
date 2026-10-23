defmodule RetroHexChat.Commands.Handlers.VoiceCmd do
  @moduledoc "Handler for /voice <nickname> — give voice status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "voice",
    category: :channel,
    syntax: dgettext("commands", "/voice <nickname>"),
    summary: dgettext("commands", "Give voice status to a user."),
    description:
      dgettext(
        "commands",
        "Give voice status to a user. Shortcut for /mode +v <nickname>.\nRequires: half-operator, operator, or owner."
      ),
    examples: [dgettext("commands", "/voice alice")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to give voice")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /voice <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_half_op_or_above(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+v", params: [nick]}}
    end
  end
end
