defmodule RetroHexChat.Commands.Handlers.Op do
  @moduledoc "Handler for /op <nickname> — give channel operator status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "op",
    category: :channel,
    syntax: dgettext("commands", "/op <nickname>"),
    summary: dgettext("commands", "Give channel operator status to a user."),
    description:
      dgettext(
        "commands",
        "Give channel operator status to a user. Shortcut for /mode +o <nickname>.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/op alice")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to give operator status")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /op <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+o", params: [nick]}}
    end
  end
end
