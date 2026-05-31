defmodule RetroHexChat.Commands.Handlers.Motd do
  @moduledoc "Handler for /motd — view the current Message of the Day."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Motd

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context) do
    case Motd.get() do
      nil -> {:ok, :system, %{content: dgettext("commands", "No MOTD has been set.")}}
      content -> {:ok, :ui_action, :show_motd, %{content: content}}
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
      name: "motd",
      syntax: "/motd",
      description:
        dgettext(
          "commands",
          "View the server's Message of the Day, which is also shown automatically when you connect."
        ),
      examples: ["/motd"]
    }
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "motd",
      syntax: "/motd",
      description:
        dgettext(
          "commands",
          "View the server's Message of the Day, which is also shown automatically when you connect."
        ),
      category: :advanced,
      parameters: [],
      examples: ["/motd"]
    }
  end
end
