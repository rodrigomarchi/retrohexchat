defmodule RetroHexChat.Commands.Handlers.NoticeRouting do
  @moduledoc """
  Handler for the /notice_routing command.
  Notice routing is now hardcoded to active window.
  """

  @behaviour RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute(_, _context),
    do: {:ok, :ui_action, :notice_routing_show, %{}}

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "notice_routing",
      syntax: "/notice_routing",
      description: "Notices are always routed to the active window.",
      examples: ["/notice_routing"]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "notice_routing",
      syntax: "/notice_routing",
      description: "Notices are always routed to the active window.",
      category: :user,
      parameters: [],
      examples: ["/notice_routing"]
    }
  end
end
