defmodule RetroHexChat.Commands.Handlers.VoiceCmd do
  @moduledoc "Handler for /voice <nickname> — give voice status."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, gettext("Usage: /voice <nickname>")}

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
      syntax: gettext("/voice <nickname>"),
      description:
        gettext(
          "Give voice status to a user. Shortcut for /mode +v <nickname>.\nRequires: half-operator, operator, or owner."
        ),
      examples: [gettext("/voice alice")]
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
      syntax: gettext("/voice <nickname>"),
      description: gettext("Give voice status to a user."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("User to give voice")
        }
      ],
      examples: [gettext("/voice alice")]
    }
  end

  defp require_channel(%{active_channel: nil}),
    do: {:error, gettext("You are not in any channel")}

  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_half_op_or_above(context, channel) do
    is_op = channel in context.operator_in
    is_half_op = channel in Map.get(context, :half_operator_in, [])

    if is_op or is_half_op do
      :ok
    else
      {:error, gettext("You must be at least a half-operator to use this command")}
    end
  end
end
