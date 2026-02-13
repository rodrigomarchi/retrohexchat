defmodule RetroHexChat.Commands.Handlers.SetMotd do
  @moduledoc "Handler for /setmotd <text> — admin sets the MOTD."
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

  def execute([], _context) do
    {:error, "Usage: /setmotd <text>"}
  end

  def execute(args, %{is_admin: true, nickname: nickname}) do
    content = Enum.join(args, " ")

    case Motd.set(content, nickname) do
      :ok -> {:ok, :system, %{content: "MOTD has been updated."}}
      {:error, msg} -> {:error, msg}
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
      name: "setmotd",
      syntax: "/setmotd <text>",
      description: "Set the server Message of the Day. Requires server administrator privileges.",
      examples: ["/setmotd Welcome to RetroHexChat!"]
    }
  end

  @impl true
  def category, do: :advanced
end
