# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Radio do
  @moduledoc "Handler for /radio — opens the window its menu entry opens"
  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "radio",
    category: :basics,
    syntax: "/radio",
    summary:
      dgettext(
        "commands",
        "Open Hex Radio, the internet radio player, to listen to stations from around the world."
      ),
    description:
      dgettext(
        "commands",
        "Open Hex Radio, the internet radio player, to listen to stations from around the world."
      ),
    examples: ["/radio"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context), do: {:ok, :ui_action, :open_radio, %{}}
end
