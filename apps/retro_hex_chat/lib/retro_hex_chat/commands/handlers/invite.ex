defmodule RetroHexChat.Commands.Handlers.Invite do
  @moduledoc "Handler for /invite <nickname> [#channel]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /invite <nickname> [#channel]"}
  end

  def execute(["auto"], _context) do
    {:ok, :ui_action, :toggle_auto_join_on_invite, %{}}
  end

  def execute([nickname], context) do
    with {:ok, channel} <- require_channel(context) do
      {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
    end
  end

  def execute([nickname, channel], _context) do
    {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
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
      name: "invite",
      syntax: "/invite <nickname> [#channel]",
      description: "Invite a user to an invite-only (+i) channel",
      examples: ["/invite Alice", "/invite Alice #private", "/invite auto"]
    }
  end

  @spec require_channel(Handler.context()) :: {:ok, String.t()} | {:error, String.t()}
  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: channel}), do: {:ok, channel}

  @impl true
  def category, do: :channel
end
