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
        "Choose where incoming notices appear on your screen.\nOptions: active (current window, default), status (Status tab), sender (sender's PM tab).\nNo args: shows current setting. Persisted for registered users.",
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

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "notice_routing",
      syntax: "/notice_routing [active|status|sender]",
      description:
        "Choose where incoming notices appear: in your active window, the Status tab, or the sender's PM tab.",
      category: :user,
      parameters: [
        %Parameter{
          name: "routing",
          required: false,
          type: :text,
          position: 0,
          description: "Destination: active, status, sender"
        }
      ],
      examples: [
        "/notice_routing",
        "/notice_routing active",
        "/notice_routing status",
        "/notice_routing sender"
      ]
    }
  end
end
