defmodule RetroHexChatWeb.Components.MenuBar do
  @moduledoc """
  Menu bar with File, Edit, View, Help dropdowns and phx-click handlers.
  """
  use Phoenix.Component

  @spec menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_bar(assigns) do
    ~H"""
    <div class="menu-bar" role="menubar">
      <div class="menu-item-wrapper">
        <div class="menu-item" role="menuitem" tabindex="0">File</div>
        <div class="menu-dropdown">
          <div class="menu-dropdown-item" data-testid="menu-disconnect" phx-click="quit_chat">
            Disconnect
          </div>
        </div>
      </div>
      <div class="menu-item-wrapper">
        <div class="menu-item" role="menuitem" tabindex="0">Edit</div>
        <div class="menu-dropdown">
          <div class="menu-dropdown-item" data-testid="menu-find" phx-click="open_search">
            Find...
          </div>
        </div>
      </div>
      <div class="menu-item-wrapper">
        <div class="menu-item" role="menuitem" tabindex="0">View</div>
        <div class="menu-dropdown">
          <div class="menu-dropdown-item" data-testid="menu-toggle-treebar" phx-click="toggle_treebar">
            Toggle Treebar
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-toggle-nicklist"
            phx-click="toggle_nicklist"
          >
            Toggle Nicklist
          </div>
        </div>
      </div>
      <div class="menu-item-wrapper">
        <div class="menu-item" role="menuitem" tabindex="0">Tools</div>
        <div class="menu-dropdown">
          <div
            class="menu-dropdown-item"
            data-testid="menu-address-book"
            phx-click="toggle_address_book"
          >
            Address Book
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-highlight"
            phx-click="open_highlight_dialog"
          >
            Highlight Words
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-ignore-list"
            phx-click="open_ignore_dialog"
          >
            Ignore List
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-url-catcher"
            phx-click="toggle_url_catcher"
          >
            URL Catcher
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-channel-central"
            phx-click="open_channel_central"
          >
            Channel Central
          </div>
        </div>
      </div>
      <div class="menu-item-wrapper">
        <div class="menu-item" role="menuitem" tabindex="0">Help</div>
        <div class="menu-dropdown">
          <div
            class="menu-dropdown-item"
            data-testid="menu-help-topics"
            phx-click="toggle_help_dialog"
          >
            Help Topics
          </div>
          <div class="menu-dropdown-item" data-testid="menu-about" phx-click="show_about">About</div>
        </div>
      </div>
    </div>
    """
  end
end
