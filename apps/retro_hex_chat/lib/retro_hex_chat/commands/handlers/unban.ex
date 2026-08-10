defmodule RetroHexChat.Commands.Handlers.Unban do
  @moduledoc "Handler for /unban <nickname>"
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
    {:error, dgettext("commands", "Usage: /unban <nickname>")}
  end

  def execute([target | _rest], context) do
    denied = dgettext("commands", "You must be a channel operator to unban users")

    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel, denied) do
      {:ok, :ui_action, :unban_user, %{channel: channel, target: target}}
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
      name: "unban",
      syntax: dgettext("commands", "/unban <nickname>"),
      description:
        dgettext(
          "commands",
          "Remove a ban from a user, allowing them to rejoin the channel.\nRequires: channel operator. Must be in a channel."
        ),
      examples: [dgettext("commands", "/unban user123")]
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
      command: "unban",
      syntax: dgettext("commands", "/unban <nickname>"),
      description:
        dgettext("commands", "Remove a ban from a user, allowing them to rejoin the channel."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to unban")
        }
      ],
      examples: [dgettext("commands", "/unban user123")]
    }
  end
end
