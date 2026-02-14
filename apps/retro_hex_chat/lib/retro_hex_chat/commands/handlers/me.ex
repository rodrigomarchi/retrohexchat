defmodule RetroHexChat.Commands.Handlers.Me do
  @moduledoc "Handler for /me <action>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /me <action>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /me <action>"}

  def execute(args, context) do
    if context.active_channel == nil do
      {:error, "You are not in any channel"}
    else
      content = Enum.join(args, " ")
      {:ok, :action, %{content: content}}
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
      name: "me",
      syntax: "/me <action>",
      description: "Sends an action message.",
      examples: ["/me waves hello", "/me is away"]
    }
  end

  @impl true
  def category, do: :basics

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "me",
      syntax: "/me <action>",
      description: "Sends an action message.",
      category: :basics,
      parameters: [
        %Parameter{
          name: "action",
          required: true,
          type: :text,
          position: 0,
          description: "Texto da ação"
        }
      ],
      examples: ["/me waves hello", "/me is away"]
    }
  end
end
