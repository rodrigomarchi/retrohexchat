defmodule RetroHexChat.Commands.Handlers.Join do
  @moduledoc "Handler for /join #channel [password]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Admin
  alias RetroHexChat.Channels.Name
  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "join",
    category: :channel,
    syntax: dgettext("commands", "/join #channel [password]"),
    summary:
      dgettext(
        "commands",
        "Enter a chat channel to read and send messages. Creates the channel if it doesn't exist yet.\nChannel name must start with #, max 50 characters, no spaces.\nMax 10 channels at once. Password required if channel has +k mode set."
      ),
    description:
      dgettext(
        "commands",
        "Enter a chat channel to read and send messages. Creates the channel if it doesn't exist yet.\nChannel name must start with #, max 50 characters, no spaces.\nMax 10 channels at once. Password required if channel has +k mode set."
      ),
    examples: [
      dgettext("commands", "/join #elixir"),
      dgettext("commands", "/join #secret mypassword")
    ],
    parameters: [
      %Parameter{
        name: "#channel",
        required: true,
        type: :channel,
        position: 0,
        description: dgettext("commands", "Channel name")
      },
      %Parameter{
        name: "password",
        required: false,
        type: :text,
        position: 1,
        description: dgettext("commands", "Channel password (if key-protected)")
      }
    ]

  @default_max_channels 10

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /join #channel [password]")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context),
    do: {:error, dgettext("commands", "Usage: /join #channel [password]")}

  def execute([channel_name | rest], context) do
    password = List.first(rest)

    cond do
      problem = name_problem(channel_name) ->
        {:error, problem}

      length(context.channels) >= max_channels() ->
        {:error, "Maximum channel limit reached (#{max_channels()})"}

      channel_name in context.channels ->
        {:error, "You are already in #{channel_name}"}

      true ->
        {:ok, :join, channel_name, password}
    end
  end

  # A value an admin saved that is not a number falls back to the default.
  @spec max_channels() :: pos_integer()
  defp max_channels do
    case Integer.parse(Admin.server_setting("max_channels")) do
      {count, ""} when count > 0 -> count
      _other -> @default_max_channels
    end
  end

  @spec name_problem(String.t()) :: String.t() | nil
  defp name_problem(channel_name) do
    case Name.check(channel_name) do
      :ok ->
        nil

      {:error, :no_prefix} ->
        dgettext("commands", "Invalid channel name. Channel names must start with #")

      {:error, :empty} ->
        dgettext("commands", "Write the channel name after the #.")

      {:error, :too_long} ->
        dgettext("commands", "Channel name too long (max 50 characters)")

      {:error, :whitespace} ->
        dgettext("commands", "Channel name cannot contain spaces")
    end
  end
end
