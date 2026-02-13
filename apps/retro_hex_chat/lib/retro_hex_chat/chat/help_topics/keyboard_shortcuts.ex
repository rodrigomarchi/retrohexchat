defmodule RetroHexChat.Chat.HelpTopics.KeyboardShortcuts do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "keyboard-shortcuts",
        title: "Keyboard Shortcuts",
        category: "Keyboard Shortcuts",
        keywords: ["keyboard", "shortcuts", "hotkeys", "keybindings", "keys"],
        content:
          "<h3>Keyboard Shortcuts</h3>" <>
            "<h4>Navigation</h4>" <>
            "<pre>Ctrl+Shift+/  — Open Help\nCtrl+Shift+F  — Find / Search\nEscape        — Close search bar / dialog</pre>" <>
            "<h4>Windows &amp; Dialogs</h4>" <>
            "<pre>Ctrl+Shift+A  — Address Book\nCtrl+Shift+H  — Highlight Words\nCtrl+Shift+G  — Ignore List\nCtrl+Shift+L  — Log Viewer\nCtrl+Shift+O  — Options\nCtrl+Shift+E  — Perform Dialog\nCtrl+Shift+S  — URL Catcher</pre>" <>
            "<h4>Clipboard</h4>" <>
            "<pre>Ctrl+C        — Copy selected text</pre>" <>
            "<h4>Text Formatting</h4>" <>
            "<pre>Ctrl+Shift+B  — Bold\nCtrl+Shift+Y  — Italic\nCtrl+Shift+U  — Underline\nCtrl+Shift+D  — Color\nCtrl+Shift+V  — Reverse\nCtrl+Shift+X  — Reset formatting</pre>" <>
            "<h4>Input</h4>" <>
            "<pre>Enter         — Send message\nUp / Down     — Command history\nTab           — Tab-complete nicknames</pre>" <>
            "<h4>Emoji</h4>" <>
            "<pre>Emoji Picker  — Click smiley button in formatting toolbar</pre>" <>
            "<h4>Customization</h4>" <>
            "<p>All keyboard shortcuts (except Escape) can be customized in <strong>Options &gt; Key Bindings</strong> (Ctrl+Shift+O). " <>
            "See <a href=\"#\" data-help-topic=\"feature-key-bindings\">Key Bindings</a> for details.</p>"
      }
    ]
  end
end
