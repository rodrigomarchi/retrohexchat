defmodule RetroHexChat.Commands.Handlers.Kick do
  @moduledoc "Handler for /kick <nickname> [reason]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /kick <nickname> [reason]")}
  end

  def execute([target | rest], context) do
    denied = dgettext("commands", "You must be a channel operator to kick users")

    with {:ok, channel} <- require_channel(context),
         :ok <- require_half_op_or_above(context, channel, denied) do
      reason = if rest == [], do: nil, else: Enum.join(rest, " ")

      {:ok, :ui_action, :kick_user, %{channel: channel, target: target, reason: reason}}
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
      name: "kick",
      syntax: dgettext("commands", "/kick <nickname> [reason]"),
      description:
        dgettext(
          "commands",
          "Remove a user from the channel with an optional reason. They can rejoin unless also banned.\nRequires: channel operator or half-operator. Must be in a channel."
        ),
      examples: [
        dgettext("commands", "/kick troll"),
        dgettext("commands", "/kick troll Spamming the channel")
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
      command: "kick",
      syntax: dgettext("commands", "/kick <nickname> [reason]"),
      description:
        dgettext(
          "commands",
          "Remove a user from the channel with an optional reason. They can rejoin unless also banned.\nRequires: channel operator or half-operator. Must be in a channel."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to kick")
        },
        %Parameter{
          name: "reason",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Reason for the kick")
        }
      ],
      examples: [
        dgettext("commands", "/kick troll"),
        dgettext("commands", "/kick troll Spamming the channel")
      ]
    }
  end
end
