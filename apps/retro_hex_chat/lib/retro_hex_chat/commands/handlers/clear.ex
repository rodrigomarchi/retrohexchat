defmodule RetroHexChat.Commands.Handlers.Clear do
  @moduledoc "Handler for /clear"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context) do
    {:ok, :ui_action, :clear_chat, %{}}
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
      name: "clear",
      syntax: "/clear",
      description:
        gettext(
          "Clear all messages from the current chat window, giving you a fresh screen. Cannot be undone."
        ),
      examples: ["/clear"]
    }
  end

  @impl true
  def category, do: :basics

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "clear",
      syntax: "/clear",
      description:
        gettext(
          "Clear all messages from the current chat window, giving you a fresh screen. Cannot be undone."
        ),
      category: :basics,
      parameters: [],
      examples: ["/clear"]
    }
  end
end
