defmodule RetroHexChat.Commands.Handlers.Invite do
  @moduledoc "Handler for /invite <nickname> [#channel]"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "invite",
    category: :channel,
    syntax: dgettext("commands", "/invite <nickname> [#channel]"),
    summary:
      dgettext(
        "commands",
        "Send a channel invitation to another user. Required for invite-only (+i) channels.\nDefaults to current channel if no #channel specified. Must be in a channel when no channel arg given.\n/invite auto — toggles whether you automatically join channels when invited."
      ),
    description:
      dgettext(
        "commands",
        "Send a channel invitation to another user. Required for invite-only (+i) channels.\nDefaults to current channel if no #channel specified. Must be in a channel when no channel arg given.\n/invite auto — toggles whether you automatically join channels when invited."
      ),
    examples: [
      dgettext("commands", "/invite Alice"),
      dgettext("commands", "/invite Alice #private"),
      dgettext("commands", "/invite auto")
    ],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to invite")),
      Parameter.optional(
        :channel,
        "#channel",
        dgettext("commands", "Target channel (defaults to current channel)")
      )
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /invite <nickname> [#channel]")}
  end

  def execute(["auto"], _context) do
    {:ok, :ui_action, :toggle_auto_join_on_invite, %{}}
  end

  def execute([nickname], context) do
    with {:ok, channel} <- require_channel(context) do
      {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
    end
  end

  def execute([nickname, channel], _context) do
    {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
  end
end
