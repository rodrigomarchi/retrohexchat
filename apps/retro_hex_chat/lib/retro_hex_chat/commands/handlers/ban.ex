defmodule RetroHexChat.Commands.Handlers.Ban do
  @moduledoc "Handler for /ban <nickname> [reason]"
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
    {:error, dgettext("commands", "Usage: /ban <nickname> [reason]")}
  end

  def execute([target | rest], context) do
    denied = dgettext("commands", "You must be a channel operator to ban users")

    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel, denied) do
      reason = if rest == [], do: nil, else: Enum.join(rest, " ")

      {:ok, :ui_action, :ban_user, %{channel: channel, target: target, reason: reason}}
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
      name: "ban",
      syntax: dgettext("commands", "/ban <nickname> [reason]"),
      description:
        dgettext(
          "commands",
          "Permanently block a user from the channel. The ban persists until removed with /mode -b.\nRequires: channel operator. Must be in a channel."
        ),
      examples: [
        dgettext("commands", "/ban troll"),
        dgettext("commands", "/ban troll Repeated violations")
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
      command: "ban",
      syntax: dgettext("commands", "/ban <nickname> [reason]"),
      description:
        dgettext(
          "commands",
          "Permanently block a user from the channel. The ban persists until removed with /mode -b."
        ),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to ban")
        },
        %Parameter{
          name: "reason",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Reason for the ban")
        }
      ],
      examples: [
        dgettext("commands", "/ban troll"),
        dgettext("commands", "/ban troll Repeated violations")
      ]
    }
  end
end
