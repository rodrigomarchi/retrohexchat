defmodule RetroHexChatWeb.Components.Diagrams.DialogAccount do
  @moduledoc """
  The Account window's banner illustration: a NickServ identity card whose
  drawing changes with where the reader actually stands.

  A guest holds a blank card and no key. A registered nickname holds a card
  with a name on it and a closed padlock — the registration exists, this
  session has not proved it owns it. An identified session holds the same card
  with the padlock open and the key turned in it.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  @doc "Renders the identity card for one of the three account states."
  attr :class, :string, default: nil
  attr :nickname, :string, default: ""
  attr :state, :atom, default: :guest, values: [:guest, :registered, :identified]

  @spec diagram_account_card(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_account_card(assigns) do
    assigns = assign(assigns, :name, truncate(assigns.nickname))

    ~H"""
    <svg
      class={@class}
      viewBox="0 0 128 96"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={card_label(@state)}
    >
      <!-- Card, drop shadow first -->
      <rect x="9" y="5" width="114" height="44" fill="#808080" />
      <rect x="6" y="2" width="114" height="44" fill="#ffffff" stroke="#000000" stroke-width="1" />
      <rect x="7" y="3" width="112" height="11" fill="#000080" />
      <text
        x="11"
        y="12"
        fill="#ffffff"
        font-size="8"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        NICKSERV
      </text>
      
    <!-- Portrait well -->
      <rect x="11" y="18" width="24" height="24" fill="#c0c0c0" />
      <polyline points="11,41 11,18 34,18" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="35,19 35,42 12,42" fill="none" stroke="#ffffff" stroke-width="1" />
      
    <!-- An unclaimed card carries no face -->
      <text
        :if={@state == :guest}
        x="23"
        y="37"
        text-anchor="middle"
        fill="#808080"
        font-size="20"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        ?
      </text>

      <g :if={@state != :guest}>
        <rect x="19" y="22" width="8" height="8" fill="#000080" />
        <rect x="15" y="32" width="16" height="8" fill="#000080" />
      </g>
      
    <!-- Name line -->
      <g :if={@name == ""}>
        <rect x="41" y="22" width="70" height="6" fill="#c0c0c0" />
        <rect x="41" y="33" width="48" height="4" fill="#e0e0e0" />
      </g>
      <text
        :if={@name != ""}
        x="41"
        y="30"
        fill="#000000"
        font-size="10"
        font-family="'Source Code Pro',monospace"
        font-weight="bold"
      >
        {@name}
      </text>
      <rect :if={@name != ""} x="41" y="34" width="70" height="1" fill="#c0c0c0" />
      <text
        :if={@name != ""}
        x="41"
        y="43"
        fill="#808080"
        font-size="7"
        font-family="Tahoma,sans-serif"
      >
        {state_caption(@state)}
      </text>
      
    <!-- Padlock body. It is drawn in every state: the registration exists as
           a thing whether or not this session is allowed to open it -->
      <rect
        x="34"
        y="70"
        width="32"
        height="24"
        fill={lock_fill(@state)}
        stroke="#000000"
        stroke-width="1"
      />
      <polyline points="35,93 35,71 65,71" fill="none" stroke="#ffffff" stroke-width="1" />
      <polyline points="65,72 65,93 35,93" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="46" y="76" width="7" height="7" fill="#000000" />
      <rect x="48" y="82" width="3" height="7" fill="#000000" />
      
    <!-- Shut: both legs seated in the body -->
      <g :if={@state != :identified}>
        <rect x="40" y="58" width="5" height="12" fill={shackle_fill(@state)} />
        <rect x="55" y="58" width="5" height="12" fill={shackle_fill(@state)} />
        <rect x="40" y="53" width="20" height="5" fill={shackle_fill(@state)} />
      </g>
      
    <!-- Swung open: the left leg holds, the arc lifts clear of the body -->
      <g :if={@state == :identified}>
        <rect x="40" y="53" width="5" height="17" fill="#000080" />
        <rect x="40" y="48" width="26" height="5" fill="#000080" />
        <rect x="61" y="53" width="5" height="11" fill="#000080" />
      </g>
      
    <!-- The key that turned it -->
      <g :if={@state == :identified}>
        <rect x="72" y="78" width="30" height="6" fill="#808000" />
        <rect x="78" y="84" width="4" height="6" fill="#808000" />
        <rect x="88" y="84" width="4" height="6" fill="#808000" />
        <rect x="102" y="73" width="16" height="16" fill="#808000" />
        <rect x="106" y="77" width="8" height="8" fill="#ffffff" />
      </g>
      
    <!-- A guest has no key to offer: the shape of one, drained of colour -->
      <g :if={@state == :guest}>
        <rect x="72" y="78" width="30" height="6" fill="#e0e0e0" />
        <rect x="102" y="73" width="16" height="16" fill="#e0e0e0" />
        <rect x="106" y="77" width="8" height="8" fill="#ffffff" />
      </g>
    </svg>
    """
  end

  @spec lock_fill(atom()) :: String.t()
  defp lock_fill(:guest), do: "#e0e0e0"
  defp lock_fill(_), do: "#c0c0c0"

  @spec shackle_fill(atom()) :: String.t()
  defp shackle_fill(:guest), do: "#c0c0c0"
  defp shackle_fill(_), do: "#808080"

  @spec truncate(String.t()) :: String.t()
  defp truncate(nickname) when is_binary(nickname) do
    if String.length(nickname) > 9, do: String.slice(nickname, 0, 8) <> "…", else: nickname
  end

  defp truncate(_), do: ""

  @spec state_caption(atom()) :: String.t()
  defp state_caption(:identified), do: dgettext("diagrams", "verified")
  defp state_caption(:registered), do: dgettext("diagrams", "not verified")
  defp state_caption(_), do: dgettext("diagrams", "unclaimed")

  @spec card_label(atom()) :: String.t()
  defp card_label(:identified),
    do: dgettext("diagrams", "A NickServ identity card with the padlock open and the key turned")

  defp card_label(:registered),
    do: dgettext("diagrams", "A NickServ identity card with the padlock still closed")

  defp card_label(_),
    do: dgettext("diagrams", "A blank NickServ identity card with no key beside it")
end
