defmodule RetroHexChat.Commands.Handlers.Transfer do
  @moduledoc "Handler for /transfer <nickname> — transfer channel ownership."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /transfer <nickname>"}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_owner(context, channel) do
      {:ok, :ui_action, :transfer_ownership, %{channel: channel, target: nick}}
    end
  end

  @impl true
  def help do
    %{
      name: "transfer",
      syntax: "/transfer <nickname>",
      description:
        "Transfer channel ownership to another user.\nThe new owner gets +q (owner) and you are demoted to operator.\nRequires: channel owner.",
      examples: ["/transfer alice"]
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
      command: "transfer",
      syntax: "/transfer <nickname>",
      description: "Transfer channel ownership to another user.",
      category: :channel,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "New owner"
        }
      ],
      examples: ["/transfer alice"]
    }
  end

  defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
  defp require_channel(%{active_channel: ch}), do: {:ok, ch}

  defp require_owner(context, channel) do
    owner_in = Map.get(context, :owner_in, [])

    if channel in owner_in do
      :ok
    else
      {:error, "You must be the channel owner to use this command"}
    end
  end
end
