defmodule RetroHexChat.Commands.Handlers.Devoice do
  @moduledoc "Handler for /devoice <nickname> — remove voice status."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /devoice <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_half_op_or_above(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "-v", params: [nick]}}
    end
  end

  @impl true
  def help do
    %{
      name: "devoice",
      syntax: dgettext("commands", "/devoice <nickname>"),
      description:
        dgettext(
          "commands",
          "Remove voice status from a user. Shortcut for /mode -v <nickname>.\nRequires: half-operator, operator, or owner."
        ),
      examples: [dgettext("commands", "/devoice alice")]
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
      command: "devoice",
      syntax: dgettext("commands", "/devoice <nickname>"),
      description: dgettext("commands", "Remove voice status from a user."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "User to remove voice from")
        }
      ],
      examples: [dgettext("commands", "/devoice alice")]
    }
  end
end
