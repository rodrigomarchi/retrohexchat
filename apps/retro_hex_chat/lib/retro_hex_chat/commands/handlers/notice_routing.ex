defmodule RetroHexChat.Commands.Handlers.NoticeRouting do
  @moduledoc """
  Handler for the /notice_routing command.
  Configures where incoming user-targeted notices appear.
  """

  @behaviour RetroHexChat.Commands.Handler

  @valid_routings ~w(active status sender)

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute([], _context),
    do: {:ok, :ui_action, :notice_routing_show, %{}}

  def execute([value], _context) when value in @valid_routings do
    {:ok, :ui_action, :notice_routing_set, %{routing: String.to_existing_atom(value)}}
  end

  def execute([_invalid], _context) do
    {:error,
     "Invalid routing. Valid options: active, status, sender. Usage: /notice_routing <option>"}
  end

  def execute(_, _context) do
    {:error, "Usage: /notice_routing [active|status|sender]"}
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
      name: "notice_routing",
      syntax: "/notice_routing [active|status|sender]",
      description:
        "Configure where incoming notices appear. 'active' shows in current window (default), " <>
          "'status' shows in Status Window, 'sender' shows in sender's PM window. " <>
          "Without arguments, shows current setting.",
      examples: [
        "/notice_routing",
        "/notice_routing active",
        "/notice_routing status",
        "/notice_routing sender"
      ]
    }
  end

  @impl true
  def category, do: :user
end
