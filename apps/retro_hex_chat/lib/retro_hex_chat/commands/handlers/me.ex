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
      description:
        "Send an action message that appears as '* YourNick does something' to everyone in the channel.\nMust be in a channel. Action text is required.",
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
      description:
        "Send an action message that appears as '* YourNick does something' to everyone in the channel.\nMust be in a channel. Action text is required.",
      category: :basics,
      parameters: [
        %Parameter{
          name: "action",
          required: true,
          type: :text,
          position: 0,
          description: "Action text"
        }
      ],
      examples: ["/me waves hello", "/me is away"]
    }
  end
end
