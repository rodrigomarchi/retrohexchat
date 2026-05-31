defmodule RetroHexChat.Commands.Handlers.Knock do
  @moduledoc "Handler for /knock #channel [message]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, gettext("Usage: /knock #channel [message]")}
  end

  def execute([channel_name | rest], _context) do
    if String.starts_with?(channel_name, "#") do
      message = if rest == [], do: nil, else: Enum.join(rest, " ")
      {:ok, :ui_action, :knock_channel, %{channel: channel_name, message: message}}
    else
      {:error, gettext("Usage: /knock #channel [message]")}
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
      name: "knock",
      syntax: gettext("/knock #channel [message]"),
      description:
        gettext(
          "Request to be let into an invite-only (+i) channel. Operators see your knock and can invite you.\nChannel name must start with #."
        ),
      examples: [
        gettext("/knock #private"),
        gettext("/knock #private Hey, can I join?")
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
      command: "knock",
      syntax: gettext("/knock #channel [message]"),
      description:
        gettext(
          "Request to be let into an invite-only (+i) channel. Operators see your knock and can invite you.\nChannel name must start with #."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "#channel",
          required: true,
          type: :channel,
          position: 0,
          description: gettext("Channel to request access to")
        },
        %Parameter{
          name: "message",
          required: false,
          type: :text,
          position: 1,
          description: gettext("Message for the channel operators")
        }
      ],
      examples: [
        gettext("/knock #private"),
        gettext("/knock #private Hey, can I join?")
      ]
    }
  end
end
