defmodule RetroHexChat.Commands.Handlers.Kick do
  @moduledoc "Handler for /kick <nickname> [reason]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /kick <nickname> [reason]"}
  end

  def execute([target | rest], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_kick_privilege(context, channel) do
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
      syntax: "/kick <nickname> [reason]",
      description: "Kick a user from the channel. Requires half-operator or higher.",
      examples: ["/kick troll", "/kick troll Spamming the channel"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  defp require_kick_privilege(context, channel) do
    is_operator = channel in context.operator_in
    is_half_op = channel in Map.get(context, :half_operator_in, [])

    if is_operator or is_half_op do
      :ok
    else
      {:error, "You must be a channel operator to kick users"}
    end
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
      syntax: "/kick <nickname> [reason]",
      description: "Kick a user from the channel. Requires half-operator or higher.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "Usuário a ser expulso"
        },
        %Parameter{
          name: "reason",
          required: false,
          type: :text,
          position: 1,
          description: "Motivo da expulsão"
        }
      ],
      examples: ["/kick troll", "/kick troll Spamming the channel"]
    }
  end
end
