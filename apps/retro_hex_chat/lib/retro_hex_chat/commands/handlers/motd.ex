defmodule RetroHexChat.Commands.Handlers.Motd do
  @moduledoc "Handler for /motd — view the current Message of the Day."
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
      nil -> {:ok, :system, %{content: "No MOTD has been set."}}
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
      description: "Display the server Message of the Day.",
      examples: ["/motd"]
    }
  end
end
