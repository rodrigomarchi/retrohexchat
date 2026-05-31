defmodule RetroHexChat.Chat.HelpTopics.TextFormatting do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "formatting-overview",
        title: dgettext("help", "Text Formatting Overview"),
        category: dgettext("help", "Text Formatting"),
        keywords: ["formatting", "bold", "italic", "underline", "color", "strip"],
        icon: :icon_notepad,
        description:
          dgettext(
            "help",
            "Format your messages with bold, italic, underline, strikethrough, and color codes."
          )
      },
      %{
        id: "formatting-colors",
        title: dgettext("help", "Colors"),
        category: dgettext("help", "Text Formatting"),
        keywords: ["color", "colour", "foreground", "background", "palette"],
        icon: :icon_palette,
        description:
          dgettext(
            "help",
            "Use the color palette to add foreground and background colors to your chat messages."
          )
      }
    ]
  end
end
