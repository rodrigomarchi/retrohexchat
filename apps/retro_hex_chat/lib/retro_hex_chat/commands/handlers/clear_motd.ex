defmodule RetroHexChat.Commands.Handlers.ClearMotd do
  @moduledoc "Handler for /clearmotd — admin clears the MOTD."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Motd

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, "Permission denied: you must be a server administrator."}
  end

  def execute(_args, %{is_admin: true, nickname: nickname}) do
    Motd.clear(nickname)
    {:ok, :system, %{content: "MOTD has been cleared."}}
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
      name: "clearmotd",
      syntax: "/clearmotd",
      description:
        "Clear the server Message of the Day. Requires server administrator privileges.",
      examples: ["/clearmotd"]
    }
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "clearmotd",
      syntax: "/clearmotd",
      description:
        "Clear the server Message of the Day. Requires server administrator privileges.",
      category: :advanced,
      parameters: [],
      examples: ["/clearmotd"]
    }
  end
end
