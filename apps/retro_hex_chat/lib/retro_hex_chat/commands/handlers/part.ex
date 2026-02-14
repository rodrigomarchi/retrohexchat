defmodule RetroHexChat.Commands.Handlers.Part do
  @moduledoc "Handler for /part [#channel] [message]"
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
      channel -> {:ok, :part, channel, nil}
    end
  end

  def execute([channel_name | rest], context) do
    message = if rest == [], do: nil, else: Enum.join(rest, " ")

    if String.starts_with?(channel_name, "#") do
      if channel_name in context.channels do
        {:ok, :part, channel_name, message}
      else
        {:error, "You are not in #{channel_name}"}
      end
    else
      # No channel specified, treat all args as message for active channel
      case context.active_channel do
        nil -> {:error, "You are not in any channel"}
        channel -> {:ok, :part, channel, Enum.join([channel_name | rest], " ")}
      end
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
      name: "part",
      syntax: "/part [#channel] [message]",
      description: "Leave a channel. Defaults to active channel if none specified.",
      examples: ["/part", "/part #elixir", "/part #elixir Goodbye!"]
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
      command: "part",
      syntax: "/part [#channel] [message]",
      description: "Leave a channel. Defaults to active channel if none specified.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "#channel",
          required: false,
          type: :channel,
          position: 0,
          description: "Canal a sair (padrão: canal atual)"
        },
        %Parameter{
          name: "message",
          required: false,
          type: :text,
          position: 1,
          description: "Mensagem de saída"
        }
      ],
      examples: ["/part", "/part #elixir", "/part #elixir Goodbye!"]
    }
  end
end
