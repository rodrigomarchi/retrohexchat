defmodule RetroHexChat.Chat.HelpTopics.TextFormatting do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "formatting-overview",
        title: "Text Formatting Overview",
        category: "Text Formatting",
        keywords: ["formatting", "bold", "italic", "underline", "color", "strip"],
        icon: :icon_notepad,
        description:
          "Format your messages with bold, italic, underline, strikethrough, and color codes."
      },
      %{
        id: "formatting-colors",
        title: "Colors",
        category: "Text Formatting",
        keywords: ["color", "colour", "foreground", "background", "palette"],
        icon: :icon_palette,
        description:
          "Use the color palette to add foreground and background colors to your chat messages."
      }
    ]
  end
end
