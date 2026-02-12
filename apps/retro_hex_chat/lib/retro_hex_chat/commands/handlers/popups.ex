defmodule RetroHexChat.Commands.Handlers.Popups do
  @moduledoc "Handler for /popups — opens the Custom Menus dialog"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_raw_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_custom_menus_dialog, %{}}
  end

  def execute(_, _context) do
    {:ok, :ui_action, :open_custom_menus_dialog, %{}}
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
      name: "popups",
      syntax: "/popups",
      description:
        "Open the Custom Menus dialog to manage nicklist and channel popup menu items.",
      examples: [
        "/popups"
      ]
    }
  end
end
