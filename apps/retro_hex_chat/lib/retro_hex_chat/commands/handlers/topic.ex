defmodule RetroHexChat.Commands.Handlers.Topic do
  @moduledoc "Handler for /topic [new topic]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], context) do
    case context.active_channel do
      nil -> {:error, gettext("You are not in any channel")}
      channel -> {:ok, :ui_action, :view_topic, %{channel: channel}}
    end
  end

  def execute(args, context) do
    case context.active_channel do
      nil ->
        {:error, gettext("You are not in any channel")}

      channel ->
        topic = Enum.join(args, " ")
        {:ok, :ui_action, :set_topic, %{channel: channel, topic: topic}}
    end
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "topic",
      syntax: gettext("/topic [new topic]"),
      description:
        gettext(
          "View or change the channel topic displayed in the topic bar at the top of the channel.\nNo args: shows current topic. With text: sets a new topic.\nMust be in a channel. If channel has +t mode, only operators can change the topic."
        ),
      examples: ["/topic", gettext("/topic Welcome to #elixir!")]
    }
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "topic",
      syntax: gettext("/topic [new topic]"),
      description:
        gettext(
          "View or change the channel topic displayed in the topic bar at the top of the channel."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "new topic",
          required: false,
          type: :text,
          position: 0,
          description: gettext("New channel topic")
        }
      ],
      examples: ["/topic", gettext("/topic Welcome to #elixir!")]
    }
  end
end
