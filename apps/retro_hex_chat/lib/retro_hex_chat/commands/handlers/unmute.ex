defmodule RetroHexChat.Commands.Handlers.Unmute do
  @moduledoc "Handler for /unmute <nickname> — remove channel-level mute."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /unmute <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :channel_unmute_user, %{channel: channel, target: nick}}
    end
  end

  @impl true
  def help do
    %{
      name: "unmute",
      syntax: dgettext("commands", "/unmute <nickname>"),
      description:
        dgettext(
          "commands",
          "Remove a channel-level mute from a user.\nRequires: channel operator or owner."
        ),
      examples: [dgettext("commands", "/unmute alice")]
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
      command: "unmute",
      syntax: dgettext("commands", "/unmute <nickname>"),
      description: dgettext("commands", "Remove a channel-level mute from a user."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to unmute")
        }
      ],
      examples: [dgettext("commands", "/unmute alice")]
    }
  end

  defp require_channel(%{active_channel: nil}),
    do: {:error, dgettext("commands", "You are not in any channel")}

  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_operator(context, channel) do
    if channel in context.operator_in do
      :ok
    else
      {:error, dgettext("commands", "You must be a channel operator to use this command")}
    end
  end
end
