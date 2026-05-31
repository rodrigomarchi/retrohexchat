defmodule RetroHexChat.Commands.Handlers.List do
  @moduledoc "Handler for /list"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context) do
    {:ok, :ui_action, :open_channel_list, %{}}
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
      name: "list",
      syntax: "/list",
      description:
        gettext("Browse all public channels on the server in a sortable, filterable dialog."),
      examples: ["/list"]
    }
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "list",
      syntax: "/list",
      description:
        gettext("Browse all public channels on the server in a sortable, filterable dialog."),
      category: :channel,
      parameters: [],
      examples: ["/list"]
    }
  end
end
