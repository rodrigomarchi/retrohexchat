defmodule RetroHexChat.Commands.Handlers.Popups do
  @moduledoc "Handler for /popups — opens the Custom Menus dialog"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "popups",
    category: :config,
    syntax: "/popups",
    summary:
      dgettext(
        "commands",
        "Open the Custom Menus dialog to add, edit, or remove custom right-click menu items for the nick list and channels."
      ),
    description:
      dgettext(
        "commands",
        "Open the Custom Menus dialog to add, edit, or remove custom right-click menu items for the nick list and channels."
      ),
    examples: [
      "/popups"
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_custom_menus_dialog, %{}}
  end

  def execute(_, _context) do
    {:ok, :ui_action, :open_custom_menus_dialog, %{}}
  end
end
