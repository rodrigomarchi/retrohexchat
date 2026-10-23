defmodule RetroHexChat.Commands.Handlers.Ban do
  @moduledoc "Handler for /ban <nickname> [reason]"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "ban",
    category: :channel,
    syntax: dgettext("commands", "/ban <nickname> [reason]"),
    summary:
      dgettext(
        "commands",
        "Permanently block a user from the channel. The ban persists until removed with /mode -b."
      ),
    description:
      dgettext(
        "commands",
        "Permanently block a user from the channel. The ban persists until removed with /mode -b.\nRequires: channel operator. Must be in a channel."
      ),
    examples: [
      dgettext("commands", "/ban troll"),
      dgettext("commands", "/ban troll Repeated violations")
    ],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to ban")
      },
      %Parameter{
        name: "reason",
        required: false,
        type: :text,
        position: 1,
        description: dgettext("commands", "Reason for the ban")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /ban <nickname> [reason]")}
  end

  def execute([target | rest], context) do
    denied = dgettext("commands", "You must be a channel operator to ban users")

    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel, denied) do
      reason = if rest == [], do: nil, else: Enum.join(rest, " ")

      {:ok, :ui_action, :ban_user, %{channel: channel, target: target, reason: reason}}
    end
  end
end
