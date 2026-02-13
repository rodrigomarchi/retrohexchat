defmodule RetroHexChat.Commands.Handlers.Ctcp do
  @moduledoc """
  Handler for the /ctcp command.
  Sends a CTCP request to query information about another user's client.
  Supports PING, VERSION, TIME, and FINGER types.
  """

  @behaviour RetroHexChat.Commands.Handler

  @valid_types ~w(ping version time finger)
  @valid_type_atoms %{
    "ping" => :ping,
    "version" => :version,
    "time" => :time,
    "finger" => :finger
  }

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute([], _context) do
    {:error, "Usage: /ctcp <target> <type>  —  Valid types: #{Enum.join(@valid_types, ", ")}"}
  end

  def execute([_target], _context) do
    {:error, "Usage: /ctcp <target> <type>  —  Valid types: #{Enum.join(@valid_types, ", ")}"}
  end

  def execute([target, raw_type | _rest], _context) do
    type_lower = String.downcase(raw_type)

    case Map.fetch(@valid_type_atoms, type_lower) do
      {:ok, type_atom} ->
        {:ok, :ctcp, %{target: target, type: type_atom}}

      :error ->
        {:error, "Unknown CTCP type: #{raw_type}. Valid types: #{Enum.join(@valid_types, ", ")}"}
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
      name: "ctcp",
      syntax: "/ctcp <target> <ping|version|time|finger>",
      description:
        "Send a CTCP request to query information about another user's client or measure latency.",
      examples: [
        "/ctcp Alice ping",
        "/ctcp Bob version",
        "/ctcp Alice time",
        "/ctcp Bob finger"
      ]
    }
  end

  @impl true
  def category, do: :user
end
