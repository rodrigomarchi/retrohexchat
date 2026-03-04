defmodule RetroHexChatWeb.Components.Diagrams.GameScreens do
  @moduledoc """
  Shared SVG helpers for game screen diagrams.

  This module provides the `win98_chrome/1` helper that renders
  a Win98-style window frame. Individual game diagrams live in
  their own modules under `Diagrams.Game*`.
  """
  use Phoenix.Component

  @doc false
  def win98_chrome(title, step \\ nil) do
    assigns = %{title: title, step: step}

    ~H"""
    <%!-- Shadow --%>
    <rect x="4" y="4" width="512" height="352" fill="#000" />
    <%!-- Frame --%>
    <rect x="0" y="0" width="512" height="352" fill="#c0c0c0" stroke="#000" stroke-width="1" />
    <%!-- Outer bevels --%>
    <polyline points="1,351 1,1 511,1" fill="none" stroke="#fff" stroke-width="1" />
    <polyline points="511,2 511,351 1,351" fill="none" stroke="#808080" stroke-width="1" />
    <%!-- Title bar --%>
    <rect x="3" y="3" width="506" height="16" fill="#000080" />
    <%= if @step do %>
      <rect x="5" y="5" width="14" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <text
        x="12"
        y="14"
        text-anchor="middle"
        fill="#fff"
        font-size="10"
        font-family="'Courier New',monospace"
        font-weight="bold"
      >
        {@step}
      </text>
    <% end %>
    <text
      x="256"
      y="15"
      text-anchor="middle"
      fill="#fff"
      font-size="9"
      font-family="Tahoma,sans-serif"
      font-weight="bold"
    >
      {@title}
    </text>
    <%!-- Canvas area (inner) --%>
    <rect x="6" y="22" width="500" height="326" fill="#000" stroke="#808080" stroke-width="1" />
    <polyline points="7,347 7,23 505,23" fill="none" stroke="#404040" stroke-width="1" />
    """
  end
end
