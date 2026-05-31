defmodule RetroHexChat.Commands.Handlers.Join do
  @moduledoc "Handler for /join #channel [password]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Queries

  @default_max_channels 10

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, gettext("Usage: /join #channel [password]")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, gettext("Usage: /join #channel [password]")}

  def execute([channel_name | rest], context) do
    password = List.first(rest)

    cond do
      not String.starts_with?(channel_name, "#") ->
        {:error, gettext("Invalid channel name. Channel names must start with #")}

      String.length(channel_name) > 50 ->
        {:error, gettext("Channel name too long (max 50 characters)")}

      String.contains?(channel_name, " ") ->
        {:error, gettext("Channel name cannot contain spaces")}

      length(context.channels) >= max_channels() ->
        {:error, "Maximum channel limit reached (#{max_channels()})"}

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
      syntax: gettext("/join #channel [password]"),
      description:
        gettext(
          "Enter a chat channel to read and send messages. Creates the channel if it doesn't exist yet.\nChannel name must start with #, max 50 characters, no spaces.\nMax 10 channels at once. Password required if channel has +k mode set."
        ),
      examples: [gettext("/join #elixir"), gettext("/join #secret mypassword")]
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
      syntax: gettext("/join #channel [password]"),
      description:
        gettext(
          "Enter a chat channel to read and send messages. Creates the channel if it doesn't exist yet.\nChannel name must start with #, max 50 characters, no spaces.\nMax 10 channels at once. Password required if channel has +k mode set."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "#channel",
          required: true,
          type: :channel,
          position: 0,
          description: gettext("Channel name")
        },
        %Parameter{
          name: "password",
          required: false,
          type: :text,
          position: 1,
          description: gettext("Channel password (if key-protected)")
        }
      ],
      examples: [gettext("/join #elixir"), gettext("/join #secret mypassword")]
    }
  end

  @spec max_channels() :: pos_integer()
  defp max_channels do
    case Queries.get_setting("max_channels") do
      nil -> @default_max_channels
      val -> String.to_integer(val)
    end
  rescue
    _ -> @default_max_channels
  end
end
