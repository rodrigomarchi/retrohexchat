defmodule RetroHexChatWeb.Components.MenuBar do
  @moduledoc """
  Menu bar with File, Edit, View, Favorites, Tools, Help dropdowns and phx-click handlers.
  """
  use Phoenix.Component

  attr :favorites, :list, default: []
  attr :joined_channels, :list, default: []

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
        <div class="menu-item" role="menuitem" tabindex="0">Favorites</div>
        <div class="menu-dropdown">
          <%= if @favorites == [] do %>
            <div
              class="menu-dropdown-item"
              style="color: #808080; pointer-events: none;"
              data-testid="menu-no-favorites"
            >
              No favorites
            </div>
          <% else %>
            <div
              :for={fav <- @favorites}
              class="menu-dropdown-item"
              data-testid={"menu-fav-#{fav.channel_name}"}
              phx-click="join_favorite"
              phx-value-channel={fav.channel_name}
            >
              <span
                :if={fav.channel_name in @joined_channels}
                class="fav-check"
                data-testid={"fav-check-#{fav.channel_name}"}
              >
                &#10003;&nbsp;
              </span>
              <span :if={fav.channel_name not in @joined_channels}>&nbsp;&nbsp;&nbsp;&nbsp;</span>
              {fav.channel_name}
              <span
                :if={fav.description != "" and fav.description != nil}
                style="color: #808080; margin-left: 8px;"
              >
                - {fav.description}
              </span>
            </div>
          <% end %>
          <div class="menu-dropdown-separator" style="border-top: 1px solid #808080; margin: 2px 0;">
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-organize-favorites"
            phx-click="open_organize_favorites"
          >
            Organize Favorites...
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
          <div
            class="menu-dropdown-item"
            data-testid="menu-log-viewer"
            phx-click="open_log_viewer"
          >
            Log Viewer
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-perform"
            phx-click="open_perform_dialog"
          >
            Perform
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-sounds"
            phx-click="open_sound_settings_dialog"
          >
            Sounds
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-ctcp-settings"
            phx-click="open_ctcp_settings_dialog"
          >
            CTCP Settings
          </div>
          <div
            class="menu-dropdown-item"
            data-testid="menu-flood-protection"
            phx-click="open_flood_protection_dialog"
          >
            Flood Protection
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
