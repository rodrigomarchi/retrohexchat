# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Ascii do
  @moduledoc "Handler for /ascii — opens the window its menu entry opens"
  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "ascii",
    category: :basics,
    syntax: "/ascii",
    summary:
      dgettext(
        "commands",
        "Open ASCII Art, to turn a word, a picture or a Hex Paint drawing into text art in mIRC colours and post it to a channel."
      ),
    description:
      dgettext(
        "commands",
        "Open ASCII Art, to turn a word, a picture or a Hex Paint drawing into text art in mIRC colours and post it to a channel."
      ),
    examples: ["/ascii"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context), do: {:ok, :ui_action, :open_ascii_art, %{}}
end
