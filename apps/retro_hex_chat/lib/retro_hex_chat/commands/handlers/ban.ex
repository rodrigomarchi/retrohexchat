defmodule RetroHexChat.Commands.Handlers.Ban do
  @moduledoc "Handler for /ban <nickname> [reason]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /ban <nickname> [reason]"}
  end

  def execute([target | rest], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
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
      syntax: "/ban <nickname> [reason]",
      description: "Ban a user from the channel. Requires operator privilege.",
      examples: ["/ban troll", "/ban troll Repeated violations"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  defp require_operator(%{operator_in: operator_in}, channel) do
    if channel in operator_in do
      :ok
    else
      {:error, "You must be a channel operator to ban users"}
    end
  end

  @impl true
  def category, do: :channel
end
