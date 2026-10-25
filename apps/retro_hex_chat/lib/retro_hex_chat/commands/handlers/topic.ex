defmodule RetroHexChat.Commands.Handlers.Topic do
  @moduledoc "Handler for /topic [new topic]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "topic",
    category: :channel,
    syntax: dgettext("commands", "/topic [new topic]"),
    summary:
      dgettext(
        "commands",
        "View or change the channel topic displayed in the topic bar at the top of the channel."
      ),
    description:
      dgettext(
        "commands",
        "View or change the channel topic displayed in the topic bar at the top of the channel.\nNo args: shows current topic. With text: sets a new topic.\nMust be in a channel. If channel has +t mode, only operators can change the topic."
      ),
    examples: ["/topic", dgettext("commands", "/topic Welcome to #elixir!")],
    parameters: [
      Parameter.optional(:text, "new topic", dgettext("commands", "New channel topic"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], context) do
    case context.active_channel do
      nil -> {:error, dgettext("commands", "You are not in any channel")}
      channel -> {:ok, :ui_action, :view_topic, %{channel: channel}}
    end
  end

  def execute(args, context) do
    case context.active_channel do
      nil ->
        {:error, dgettext("commands", "You are not in any channel")}

      channel ->
        topic = Enum.join(args, " ")
        {:ok, :ui_action, :set_topic, %{channel: channel, topic: topic}}
    end
  end
end
