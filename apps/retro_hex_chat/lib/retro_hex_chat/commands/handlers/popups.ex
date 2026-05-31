defmodule RetroHexChat.Commands.Handlers.Popups do
  @moduledoc "Handler for /popups — opens the Custom Menus dialog"
  use Gettext, backend: RetroHexChat.Gettext
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
        gettext(
          "Open the Custom Menus dialog to add, edit, or remove custom right-click menu items for the nick list and channels."
        ),
      examples: [
        "/popups"
      ]
    }
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax

    %CommandSyntax{
      command: "popups",
      syntax: "/popups",
      description:
        gettext(
          "Open the Custom Menus dialog to add, edit, or remove custom right-click menu items for the nick list and channels."
        ),
      category: :config,
      parameters: [],
      examples: [
        "/popups"
      ]
    }
  end
end
