defmodule RetroHexChatWeb.Components.UI.JoinCard do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :state, :atom, required: true, values: [:ready, :needs_session, :filled, :gone]
  attr :kind, :string, default: nil
  attr :creator_nick, :string, default: nil
  attr :subject, :map, default: nil, doc: "what was shared: %{name, tagline, icon}"

  attr :preview, :list,
    default: [],
    doc: "the last few visible lines of the room, oldest first"

  attr :enter_path, :string, default: nil

  attr :enter_patch?, :boolean,
    default: false,
    doc: "the way in is an address of the desktop (a channel, sign-in): a patch, not a load"

  attr :chat_path, :string, default: "/", doc: "where \"Open the chat\" goes"

  @doc """
  The card's body, inside the invite's document window on the desktop (the
  window's title is `title/2`, and `from/1` its meta).
  """
  @spec join_card(map()) :: Phoenix.LiveView.Rendered.t()
  def join_card(assigns) do
    ~H"""
    <div class="flex flex-col gap-3 p-4" data-testid="join-card">
      <.subject_row :if={@subject} subject={@subject} />
      <.preview_lines :if={@preview != []} lines={@preview} />

      <p class="text-center" data-testid={state_testid(@state)}>
        {body_text(@state, @creator_nick)}
      </p>

      <.button
        :if={@state in [:ready, :needs_session] && @enter_patch?}
        patch={@enter_path}
        class="justify-center"
        data-testid="join-enter"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {enter_label(@state)}
      </.button>

      <.button
        :if={@state in [:ready, :needs_session] && !@enter_patch?}
        href={@enter_path}
        class="justify-center"
        data-testid="join-enter"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {enter_label(@state)}
      </.button>

      <%!-- A card that stopped working still offers the next plausible
            thing, and for a full match that is the game itself: the person
            came to play, and the door they took happened to be taken. --%>
      <.button
        :if={@state == :filled && @subject}
        href="/play"
        class="justify-center"
        data-testid="join-play-instead"
      >
        <:icon><Icons.icon_game_pong class="h-4 w-4" /></:icon>
        {dgettext("share", "Play something else")}
      </.button>

      <.button
        :if={@state in [:gone, :filled]}
        patch={@chat_path}
        class="justify-center"
        data-testid="join-elsewhere"
      >
        <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
        {dgettext("share", "Open the chat")}
      </.button>
    </div>
    """
  end

  @doc "Who shared it, said after the window's title — nothing for a dead link."
  @spec from(map()) :: String.t() | nil
  def from(%{creator_nick: nick, state: state}) when is_binary(nick) and state != :gone,
    do: dgettext("share", "from %{nickname}", nickname: nick)

  def from(_card), do: nil

  attr :lines, :list, required: true

  # The difference between "somebody sent you a link" and "look what they are
  # talking about". Plain text on purpose: this is a public page, and running
  # the room's own formatting through it would let anybody who can type in the
  # channel decide how a stranger's screen looks.
  defp preview_lines(assigns) do
    ~H"""
    <ul class="shadow-retro-field bg-canvas flex flex-col gap-1 p-2" data-testid="join-preview">
      <li :for={line <- @lines} class="font-chat truncate text-sm">
        <span class="font-bold">{line.author}</span>
        <span class="text-muted-foreground">{line.content}</span>
      </li>
    </ul>
    """
  end

  attr :subject, :map, required: true

  # What was actually shared, drawn rather than described: a stranger decides
  # whether to follow a link by recognising the thing on the other side.
  defp subject_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3" data-testid="join-subject">
      <span class="shadow-retro-field bg-canvas shrink-0 p-2">
        {apply(Icons, subject_icon(@subject), [%{class: "h-8 w-8"}])}
      </span>
      <span class="min-w-0">
        <span class="block truncate font-bold">{@subject.name}</span>
        <span :if={@subject[:tagline]} class="text-muted-foreground block truncate text-sm">
          {@subject.tagline}
        </span>
      </span>
    </div>
    """
  end

  defp subject_icon(%{icon: icon}) when is_binary(icon) do
    name = :"icon_#{icon}"
    if function_exported?(Icons, name, 1), do: name, else: :icon_hex_stone
  end

  defp subject_icon(_subject), do: :icon_hex_stone

  @doc "The window's icon for a kind of link."
  @spec icon(String.t() | nil) :: atom()
  def icon("play"), do: :icon_game_pong
  def icon("call"), do: :icon_protocol_conference_compact
  def icon("space"), do: :icon_community
  def icon("channel"), do: :icon_channels
  def icon("p2p"), do: :icon_protocol_p2p_compact
  def icon(_kind), do: :icon_hex_stone

  @doc """
  The window's title. It says what kind of thing this is without naming where
  it lives: a channel name in a public preview leaks the existence of a
  channel the visitor could not have listed.
  """
  @spec title(atom(), String.t() | nil) :: String.t()
  def title(:gone, _kind), do: dgettext("share", "Link expired")
  def title(:filled, _kind), do: dgettext("share", "Seat taken")
  def title(_state, "play"), do: dgettext("share", "A game on RetroHexChat")
  def title(_state, "call"), do: dgettext("share", "A call on RetroHexChat")
  def title(_state, "p2p"), do: dgettext("share", "A P2P session on RetroHexChat")
  def title(_state, "channel"), do: dgettext("share", "A room on RetroHexChat")
  def title(_state, _kind), do: dgettext("share", "An invitation to RetroHexChat")

  defp body_text(:gone, _nick),
    do: dgettext("share", "This link is no longer active. The chat is still there.")

  # It says what happened and never who: naming the player who got there first
  # would turn a link anybody may hold into a way of learning who answered it.
  defp body_text(:filled, _nick),
    do: dgettext("share", "Somebody already took the seat. This match is full.")

  defp body_text(:needs_session, nick) when is_binary(nick),
    do:
      dgettext("share", "%{nickname} shared this with you. Pick a nickname to join.",
        nickname: nick
      )

  defp body_text(:needs_session, _nick),
    do: dgettext("share", "Pick a nickname to join.")

  defp body_text(_state, nick) when is_binary(nick),
    do: dgettext("share", "%{nickname} shared this with you.", nickname: nick)

  defp body_text(_state, _nick), do: dgettext("share", "Someone shared this with you.")

  defp enter_label(:needs_session), do: dgettext("share", "Connect and join")
  defp enter_label(_state), do: dgettext("share", "Join")

  defp state_testid(:gone), do: "join-gone"
  defp state_testid(:filled), do: "join-filled"
  defp state_testid(_state), do: nil
end
