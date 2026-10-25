defmodule RetroHexChat.Commands.Handlers.Bio do
  @moduledoc "Handler for /bio [text|clear]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "bio",
    category: :basics,
    syntax: dgettext("commands", "/bio [<text>|clear]"),
    summary:
      dgettext(
        "commands",
        "Set a short 'about me' text visible when others look you up with /whois."
      ),
    description:
      dgettext(
        "commands",
        "Set a short 'about me' text visible when others look you up with /whois.\nMax 200 characters (text beyond this limit is silently truncated). Use /bio to view, /bio clear to remove."
      ),
    examples: [
      dgettext("commands", "/bio Elixir enthusiast from Brazil"),
      "/bio",
      dgettext("commands", "/bio clear")
    ],
    parameters: [
      Parameter.optional(:text, "text", dgettext("commands", "Bio text (or 'clear' to remove)"))
    ]

  @max_bio_graphemes 200

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :view_bio, %{}}
  end

  def execute(["clear"], _context) do
    {:ok, :ui_action, :clear_bio, %{}}
  end

  def execute(args, _context) do
    text = Enum.join(args, " ")
    grapheme_count = String.length(text)

    if grapheme_count > @max_bio_graphemes do
      truncated = String.slice(text, 0, @max_bio_graphemes)
      {:ok, :ui_action, :set_bio, %{text: truncated, truncated: true}}
    else
      {:ok, :ui_action, :set_bio, %{text: text, truncated: false}}
    end
  end
end
