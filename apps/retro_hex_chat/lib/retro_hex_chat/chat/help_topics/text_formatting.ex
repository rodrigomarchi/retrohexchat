defmodule RetroHexChat.Chat.HelpTopics.TextFormatting do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "formatting-overview",
        title: gettext("Text Formatting Overview"),
        category: gettext("Text Formatting"),
        keywords: ["formatting", "bold", "italic", "underline", "color", "strip"],
        icon: :icon_notepad,
        description:
          gettext(
            "Format your messages with bold, italic, underline, strikethrough, and color codes."
          )
      },
      %{
        id: "formatting-colors",
        title: gettext("Colors"),
        category: gettext("Text Formatting"),
        keywords: ["color", "colour", "foreground", "background", "palette"],
        icon: :icon_palette,
        description:
          gettext(
            "Use the color palette to add foreground and background colors to your chat messages."
          )
      }
    ]
  end
end
