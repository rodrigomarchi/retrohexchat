defmodule RetroHexChat.Chat.HelpTopics.TextFormatting do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "formatting-overview.html")
  @external_resource Path.join(@help_dir, "formatting-colors.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "formatting-overview",
        title: "Text Formatting Overview",
        category: "Text Formatting",
        keywords: ["formatting", "bold", "italic", "underline", "color", "strip"],
        content: File.read!(Path.join(@help_dir, "formatting-overview.html"))
      },
      %{
        id: "formatting-colors",
        title: "Colors",
        category: "Text Formatting",
        keywords: ["color", "colour", "foreground", "background", "palette"],
        content: File.read!(Path.join(@help_dir, "formatting-colors.html"))
      }
    ]
  end
end
