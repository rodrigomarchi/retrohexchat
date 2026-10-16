defmodule RetroHexChatWeb.Site.Pages.Helpers do
  @moduledoc """
  What the page templates of the site share: the page intro, the menu bar and
  the illustrations, delegated to the components that draw them.
  """
  defdelegate landing_menu_bar(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingShell
  defdelegate landing_page_intro(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingShell

  defdelegate readme_text(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate chat_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate commands_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups

  defdelegate channel_list_mockup(assigns),
    to: RetroHexChatWeb.Components.UI.Landing.LandingMockups

  defdelegate bot_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate help_mockup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate step_clone(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate step_setup(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
  defdelegate step_run(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingMockups
end
