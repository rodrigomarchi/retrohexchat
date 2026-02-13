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
            "<pre>F1            — Open Help\nCtrl+F        — Find / Search\nEscape        — Close search bar / dialog</pre>" <>
            "<h4>Windows &amp; Dialogs</h4>" <>
            "<pre>Alt+B         — Address Book\nAlt+H         — Highlight Words\nAlt+I         — Ignore List\nAlt+L         — Log Viewer\nAlt+O         — Options\nAlt+P         — Perform Dialog\nAlt+U         — URL Catcher</pre>" <>
            "<h4>Clipboard</h4>" <>
            "<pre>Ctrl+C        — Copy selected text</pre>" <>
            "<h4>Text Formatting</h4>" <>
            "<pre>Ctrl+B        — Bold\nCtrl+I        — Italic\nCtrl+U        — Underline\nCtrl+K        — Color\nCtrl+R        — Reverse\nCtrl+O        — Reset formatting</pre>" <>
            "<h4>Input</h4>" <>
            "<pre>Enter         — Send message\nUp / Down     — Command history\nTab           — Tab-complete nicknames</pre>" <>
            "<h4>Emoji</h4>" <>
            "<pre>Emoji Picker  — Click smiley button in formatting toolbar</pre>" <>
            "<h4>Customization</h4>" <>
            "<p>All keyboard shortcuts (except Escape) can be customized in <strong>Options &gt; Key Bindings</strong> (Alt+O). " <>
            "See <a href=\"#\" data-help-topic=\"feature-key-bindings\">Key Bindings</a> for details.</p>"
      }
    ]
  end
end
