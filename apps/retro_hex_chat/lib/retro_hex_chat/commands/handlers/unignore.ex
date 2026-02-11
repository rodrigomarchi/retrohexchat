defmodule RetroHexChat.Commands.Handlers.Unignore do
  @moduledoc "Handler for /unignore <nickname>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /unignore <nickname>"}
  def validate(_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([nick | _], _context) do
    {:ok, :ui_action, :ignore_remove, %{nickname: nick}}
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
      name: "unignore",
      syntax: "/unignore <nickname>",
      description: "Remove a user from your ignore list.",
      examples: [
        "/unignore SpamBot"
      ]
    }
  end
end
