defmodule RetroHexChat.Commands.Handlers.Join do
  @moduledoc "Handler for /join #channel [password]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /join #channel [password]"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /join #channel [password]"}

  def execute([channel_name | rest], context) do
    password = List.first(rest)

    cond do
      not String.starts_with?(channel_name, "#") ->
        {:error, "Invalid channel name. Channel names must start with #"}

      String.length(channel_name) > 50 ->
        {:error, "Channel name too long (max 50 characters)"}

      String.contains?(channel_name, " ") ->
        {:error, "Channel name cannot contain spaces"}

      length(context.channels) >= 10 ->
        {:error, "Maximum channel limit reached (10)"}

      channel_name in context.channels ->
        {:error, "You are already in #{channel_name}"}

      true ->
        {:ok, :join, channel_name, password}
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
      name: "join",
      syntax: "/join #channel [password]",
      description:
        "Enter a chat channel to read and send messages. Creates the channel if it doesn't exist yet.\nChannel name must start with #, max 50 characters, no spaces.\nMax 10 channels at once. Password required if channel has +k mode set.",
      examples: ["/join #elixir", "/join #secret mypassword"]
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
      command: "join",
      syntax: "/join #channel [password]",
      description:
        "Enter a chat channel to read and send messages. Creates the channel if it doesn't exist yet.\nChannel name must start with #, max 50 characters, no spaces.\nMax 10 channels at once. Password required if channel has +k mode set.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "#channel",
          required: true,
          type: :channel,
          position: 0,
          description: "Channel name"
        },
        %Parameter{
          name: "password",
          required: false,
          type: :text,
          position: 1,
          description: "Channel password (if key-protected)"
        }
      ],
      examples: ["/join #elixir", "/join #secret mypassword"]
    }
  end
end
