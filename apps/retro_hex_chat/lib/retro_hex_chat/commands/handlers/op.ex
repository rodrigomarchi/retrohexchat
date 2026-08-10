defmodule RetroHexChat.Commands.Handlers.Op do
  @moduledoc "Handler for /op <nickname> — give channel operator status."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /op <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "+o", params: [nick]}}
    end
  end

  @impl true
  def help do
    %{
      name: "op",
      syntax: dgettext("commands", "/op <nickname>"),
      description:
        dgettext(
          "commands",
          "Give channel operator status to a user. Shortcut for /mode +o <nickname>.\nRequires: channel operator or owner."
        ),
      examples: [dgettext("commands", "/op alice")]
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
      command: "op",
      syntax: dgettext("commands", "/op <nickname>"),
      description: dgettext("commands", "Give channel operator status to a user."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to give operator status")
        }
      ],
      examples: [dgettext("commands", "/op alice")]
    }
  end
end
