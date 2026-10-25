defmodule RetroHexChat.Commands.Handlers.Knock do
  @moduledoc "Handler for /knock #channel [message]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "knock",
    category: :channel,
    syntax: dgettext("commands", "/knock #channel [message]"),
    summary:
      dgettext(
        "commands",
        "Request to be let into an invite-only (+i) channel. Operators see your knock and can invite you.\nChannel name must start with #."
      ),
    description:
      dgettext(
        "commands",
        "Request to be let into an invite-only (+i) channel. Operators see your knock and can invite you.\nChannel name must start with #."
      ),
    examples: [
      dgettext("commands", "/knock #private"),
      dgettext("commands", "/knock #private Hey, can I join?")
    ],
    parameters: [
      Parameter.required(
        :channel,
        "#channel",
        dgettext("commands", "Channel to request access to")
      ),
      Parameter.optional(
        :text,
        "message",
        dgettext("commands", "Message for the channel operators")
      )
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /knock #channel [message]")}
  end

  def execute([channel_name | rest], _context) do
    if String.starts_with?(channel_name, "#") do
      message = if rest == [], do: nil, else: Enum.join(rest, " ")
      {:ok, :ui_action, :knock_channel, %{channel: channel_name, message: message}}
    else
      {:error, dgettext("commands", "Usage: /knock #channel [message]")}
    end
  end
end
