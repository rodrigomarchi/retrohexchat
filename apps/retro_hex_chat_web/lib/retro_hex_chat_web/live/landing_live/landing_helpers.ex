defmodule RetroHexChatWeb.LandingLive.LandingHelpers do
  @moduledoc """
  Landing LiveView adapter for shared UI components.

  The public page templates keep importing this module, but the visual chrome
  lives in `RetroHexChatWeb.Components.UI.Landing.LandingShell`.
  """
  use Phoenix.Component

  defdelegate landing_layout(assigns), to: RetroHexChatWeb.Components.UI.Landing.LandingShell
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
