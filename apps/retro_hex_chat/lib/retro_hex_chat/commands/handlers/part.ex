defmodule RetroHexChat.Commands.Handlers.Part do
  @moduledoc "Handler for /part [#channel] [message]"
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
      nil -> {:error, dgettext("commands", "You are not in any channel")}
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
        nil -> {:error, dgettext("commands", "You are not in any channel")}
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
      syntax: dgettext("commands", "/part [#channel] [message]"),
      description:
        dgettext(
          "commands",
          "Leave the current channel or a specified channel, with an optional parting message.\nDefaults to current channel. If the first word doesn't start with #, it's treated as the part message.\nYou must be in the channel to leave it."
        ),
      examples: [
        "/part",
        dgettext("commands", "/part #elixir"),
        dgettext("commands", "/part #elixir Goodbye!")
      ]
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
      syntax: dgettext("commands", "/part [#channel] [message]"),
      description:
        dgettext(
          "commands",
          "Leave the current channel or a specified channel, with an optional parting message shown to others."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "#channel",
          required: false,
          type: :channel,
          position: 0,
          description: dgettext("commands", "Channel to leave (defaults to current)")
        },
        %Parameter{
          name: "message",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Part message")
        }
      ],
      examples: [
        "/part",
        dgettext("commands", "/part #elixir"),
        dgettext("commands", "/part #elixir Goodbye!")
      ]
    }
  end
end
