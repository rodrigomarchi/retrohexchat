defmodule RetroHexChat.Chat.HelpTopics.KeyboardShortcuts do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "keyboard-shortcuts",
        title: gettext("Keyboard Shortcuts"),
        category: gettext("User Interface"),
        keywords: ["keyboard", "shortcuts", "hotkeys", "keybindings", "keys"],
        icon: :icon_dialog_cheatsheet,
        description:
          gettext(
            "Complete reference of keyboard shortcuts for navigation, messaging, and interface control."
          )
      }
    ]
  end
end
