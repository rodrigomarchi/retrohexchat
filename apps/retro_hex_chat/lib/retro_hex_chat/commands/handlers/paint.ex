# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Paint do
  @moduledoc "Handler for /paint — opens the window its menu entry opens"
  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "paint",
    category: :basics,
    syntax: "/paint",
    summary:
      dgettext(
        "commands",
        "Open Hex Paint, the pixel drawing program, to draw a picture and post it to a channel."
      ),
    description:
      dgettext(
        "commands",
        "Open Hex Paint, the pixel drawing program, to draw a picture and post it to a channel."
      ),
    examples: ["/paint"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context), do: {:ok, :ui_action, :open_paint, %{}}
end
