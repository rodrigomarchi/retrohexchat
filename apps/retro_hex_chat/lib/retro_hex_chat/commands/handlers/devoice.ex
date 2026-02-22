defmodule RetroHexChat.Commands.Handlers.Devoice do
  @moduledoc "Handler for /devoice <nickname> — remove voice status."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /devoice <nickname>"}

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
      syntax: "/devoice <nickname>",
      description:
        "Remove voice status from a user. Shortcut for /mode -v <nickname>.\nRequires: half-operator, operator, or owner.",
      examples: ["/devoice alice"]
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
      syntax: "/devoice <nickname>",
      description: "Remove voice status from a user.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "User to remove voice from"
        }
      ],
      examples: ["/devoice alice"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_half_op_or_above(context, channel) do
    is_op = channel in context.operator_in
    is_half_op = channel in Map.get(context, :half_operator_in, [])

    if is_op or is_half_op do
      :ok
    else
      {:error, "You must be at least a half-operator to use this command"}
    end
  end
end
