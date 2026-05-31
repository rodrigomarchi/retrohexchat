defmodule RetroHexChat.Commands.Handlers.Query do
  @moduledoc "Handler for /query <nickname>"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /query <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /query <nickname>")}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :open_query, %{nickname: target}}
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
      name: "query",
      syntax: dgettext("commands", "/query <nickname>"),
      description:
        dgettext(
          "commands",
          "Open a private message tab with a user without sending any message, unlike /msg.\nNickname is required. If the PM tab already exists, switches to it."
        ),
      examples: [dgettext("commands", "/query Nick")]
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
      command: "query",
      syntax: dgettext("commands", "/query <nickname>"),
      description:
        dgettext(
          "commands",
          "Open a private message tab with a user without sending any message, unlike /msg."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "Open a PM tab with this user")
        }
      ],
      examples: [dgettext("commands", "/query Nick")]
    }
  end
end
