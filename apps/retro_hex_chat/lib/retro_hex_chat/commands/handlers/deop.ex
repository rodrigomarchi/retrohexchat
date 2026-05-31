defmodule RetroHexChat.Commands.Handlers.Deop do
  @moduledoc "Handler for /deop <nickname> — remove channel operator status."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, gettext("Usage: /deop <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :set_mode, %{channel: channel, mode_string: "-o", params: [nick]}}
    end
  end

  @impl true
  def help do
    %{
      name: "deop",
      syntax: gettext("/deop <nickname>"),
      description:
        gettext(
          "Remove channel operator status from a user. Shortcut for /mode -o <nickname>.\nRequires: channel operator or owner."
        ),
      examples: [gettext("/deop alice")]
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
      command: "deop",
      syntax: gettext("/deop <nickname>"),
      description: gettext("Remove channel operator status from a user."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("User to remove operator status from")
        }
      ],
      examples: [gettext("/deop alice")]
    }
  end

  defp require_channel(%{active_channel: nil}),
    do: {:error, gettext("You are not in any channel")}

  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_operator(context, channel) do
    if channel in context.operator_in do
      :ok
    else
      {:error, gettext("You must be a channel operator to use this command")}
    end
  end
end
