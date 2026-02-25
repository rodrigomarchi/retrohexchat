defmodule RetroHexChatWeb.LandingHTML do
  @moduledoc """
  HTML module for the landing page templates.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Icons
  import RetroHexChatWeb.Components.Diagrams

  embed_templates "landing_html/*"
end
