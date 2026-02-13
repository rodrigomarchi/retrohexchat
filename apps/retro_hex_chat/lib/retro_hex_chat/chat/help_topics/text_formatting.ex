defmodule RetroHexChat.Chat.HelpTopics.TextFormatting do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "formatting-overview",
        title: "Text Formatting Overview",
        category: "Text Formatting",
        keywords: ["formatting", "bold", "italic", "underline", "color", "strip"],
        content:
          "<h3>Text Formatting Overview</h3>" <>
            "<p>RetroHexChat supports IRC-compatible text formatting with bold, italic, underline, colors, and more.</p>" <>
            "<h4>Methods</h4>" <>
            "<p><strong>Toolbar:</strong> Use the formatting toolbar below the chat area (B, I, U, Color, Strip buttons).</p>" <>
            "<p><strong>Keyboard Shortcuts:</strong></p>" <>
            "<pre>Ctrl+Shift+B — Bold\nCtrl+Shift+Y — Italic\nCtrl+Shift+U — Underline\nCtrl+Shift+D — Color (opens color picker)\nCtrl+Shift+V — Reverse\nCtrl+Shift+X — Reset all formatting</pre>" <>
            "<h4>Strip Formatting</h4>" <>
            "<p>Click the <strong>S</strong> button in the formatting toolbar to strip all formatting from incoming messages.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"formatting-colors\">Colors</a></p>"
      },
      %{
        id: "formatting-colors",
        title: "Colors",
        category: "Text Formatting",
        keywords: ["color", "colour", "foreground", "background", "palette"],
        content:
          "<h3>Colors</h3>" <>
            "<p>RetroHexChat supports the standard 16-color IRC palette for both foreground and background text.</p>" <>
            "<h4>Using Colors</h4>" <>
            "<p>Press <strong>Ctrl+Shift+D</strong> or click the <strong>Color</strong> button in the formatting toolbar, then select a color from the 4×4 picker grid.</p>" <>
            "<h4>Color Palette</h4>" <>
            "<pre>0  White      8  Yellow\n1  Black      9  Light Green\n2  Navy       10 Teal\n3  Green      11 Cyan\n4  Red        12 Blue\n5  Maroon     13 Magenta\n6  Purple     14 Grey\n7  Orange     15 Light Grey</pre>"
      }
    ]
  end
end
