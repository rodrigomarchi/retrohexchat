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
        keywords: ["formatting", "bold", "italic", "underline", "color", "strip", "markdown"],
        icon: :icon_notepad,
        description:
          dgettext(
            "help",
            "Format your messages with IRC controls, Markdown, or plain text."
          )
      },
      %{
        id: "formatting-message-formats",
        title: dgettext("help", "Message Formats"),
        category: dgettext("help", "Text Formatting"),
        keywords: ["irc", "markdown", "md", "plain", "txt", "format selector", "preview"],
        icon: :icon_terminal,
        description:
          dgettext(
            "help",
            "Choose whether new messages are sent as IRC formatting, Markdown, or plain text."
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
