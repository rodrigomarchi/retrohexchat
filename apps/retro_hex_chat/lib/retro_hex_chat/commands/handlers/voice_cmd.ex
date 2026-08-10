defmodule RetroHexChat.Commands.Handlers.VoiceCmd do
  @moduledoc "Handler for /voice <nickname> — give voice status."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /voice <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_half_op_or_above(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+v", params: [nick]}}
    end
  end

  @impl true
  def help do
    %{
      name: "voice",
      syntax: dgettext("commands", "/voice <nickname>"),
      description:
        dgettext(
          "commands",
          "Give voice status to a user. Shortcut for /mode +v <nickname>.\nRequires: half-operator, operator, or owner."
        ),
      examples: [dgettext("commands", "/voice alice")]
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
      command: "voice",
      syntax: dgettext("commands", "/voice <nickname>"),
      description: dgettext("commands", "Give voice status to a user."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to give voice")
        }
      ],
      examples: [dgettext("commands", "/voice alice")]
    }
  end
end
