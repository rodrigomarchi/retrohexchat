defmodule RetroHexChat.Commands.Handlers.Unignore do
  @moduledoc "Handler for /unignore <nickname>"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, gettext("Usage: /unignore <nickname>")}
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
      syntax: gettext("/unignore <nickname>"),
      description:
        gettext(
          "Stop ignoring a user you previously blocked, making their messages visible again.\nNickname is required. Use /ignore with no args to see your ignore list first."
        ),
      examples: [
        gettext("/unignore SpamBot")
      ]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "unignore",
      syntax: gettext("/unignore <nickname>"),
      description:
        gettext(
          "Stop ignoring a user you previously blocked, making their messages visible again."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("Remove user from ignore list")
        }
      ],
      examples: [
        gettext("/unignore SpamBot")
      ]
    }
  end
end
