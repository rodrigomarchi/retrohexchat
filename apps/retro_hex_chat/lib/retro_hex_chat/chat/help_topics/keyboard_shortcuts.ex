defmodule RetroHexChat.Chat.HelpTopics.KeyboardShortcuts do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "keyboard-shortcuts.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "keyboard-shortcuts",
        title: "Keyboard Shortcuts",
        category: "Keyboard Shortcuts",
        keywords: ["keyboard", "shortcuts", "hotkeys", "keybindings", "keys"],
        content: File.read!(Path.join(@help_dir, "keyboard-shortcuts.html"))
      }
    ]
  end
end
