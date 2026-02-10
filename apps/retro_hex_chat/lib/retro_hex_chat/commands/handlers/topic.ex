defmodule RetroHexChat.Commands.Handlers.Topic do
  @moduledoc "Handler for /topic [new topic]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], context) do
    case context.active_channel do
      nil -> {:error, "You are not in any channel"}
      channel -> {:ok, :ui_action, :view_topic, %{channel: channel}}
    end
  end

  def execute(args, context) do
    case context.active_channel do
      nil ->
        {:error, "You are not in any channel"}

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
      syntax: "/topic [new topic]",
      description: "View or set the channel topic.",
      examples: ["/topic", "/topic Welcome to #elixir!"]
    }
  end
end
