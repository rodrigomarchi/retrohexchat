defmodule RetroHexChatWeb.Components.UI.JoinCard do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Desktop

  alias RetroHexChatWeb.Icons

  attr :state, :atom, required: true, values: [:ready, :needs_session, :gone]
  attr :kind, :string, default: nil
  attr :creator_nick, :string, default: nil
  attr :subject, :map, default: nil, doc: "what was shared: %{name, tagline, icon}"
  attr :enter_path, :string, default: nil

  @spec join_card(map()) :: Phoenix.LiveView.Rendered.t()
  def join_card(assigns) do
    ~H"""
    <div class="bg-background text-text font-system flex h-screen flex-col">
      <%!-- The same desktop the landing pages run, on the same public manager:
            this is the first screen a stranger sees, and a bare centred box
            would be the one place the product does not look like itself. --%>
      <.desktop
        id="join-desktop"
        persist_key="join"
        persist={false}
        window_manager_hook="PublicWindowManagerHook"
        class="flex-1"
        data-testid="join-desktop"
      >
        <.desktop_window
          id="join"
          title={title(@state, @kind)}
          pinned
          controls={[]}
          resizable={false}
          default_centered
          width={420}
          body_class="flex flex-col gap-3 p-4"
          data-testid="join-card"
        >
          <:icon><.kind_icon kind={@kind} /></:icon>
          <:meta :if={@creator_nick && @state != :gone}>
            {dgettext("share", "from %{nickname}", nickname: @creator_nick)}
          </:meta>

          <.subject_row :if={@subject} subject={@subject} />

          <p class="text-center" data-testid={@state == :gone && "join-gone"}>
            {body_text(@state, @creator_nick)}
          </p>

          <.button
            :if={@state != :gone}
            navigate={@enter_path}
            class="justify-center"
            data-testid="join-enter"
          >
            <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
            {enter_label(@state)}
          </.button>

          <.button
            :if={@state == :gone}
            navigate="/chat"
            class="justify-center"
            data-testid="join-elsewhere"
          >
            <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
            {dgettext("share", "Open the chat")}
          </.button>
        </.desktop_window>
      </.desktop>
    </div>
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

  attr :kind, :string, default: nil

  defp kind_icon(%{kind: "play"} = assigns) do
    ~H"""
    <Icons.icon_game_pong class="h-4 w-4" />
    """
  end

  defp kind_icon(%{kind: "call"} = assigns) do
    ~H"""
    <Icons.icon_protocol_conference_compact class="h-4 w-4" />
    """
  end

  defp kind_icon(%{kind: "space"} = assigns) do
    ~H"""
    <Icons.icon_community class="h-4 w-4" />
    """
  end

  defp kind_icon(%{kind: "p2p"} = assigns) do
    ~H"""
    <Icons.icon_protocol_p2p_compact class="h-4 w-4" />
    """
  end

  defp kind_icon(assigns) do
    ~H"""
    <Icons.icon_hex_stone class="h-4 w-4" />
    """
  end

  # The title says what kind of thing this is without naming where it lives: a
  # channel name in a public preview leaks the existence of a channel the
  # visitor could not have listed.
  defp title(:gone, _kind), do: dgettext("share", "Link expired")
  defp title(_state, "play"), do: dgettext("share", "A game on RetroHexChat")
  defp title(_state, "call"), do: dgettext("share", "A call on RetroHexChat")
  defp title(_state, "p2p"), do: dgettext("share", "A P2P session on RetroHexChat")
  defp title(_state, _kind), do: dgettext("share", "An invitation to RetroHexChat")

  defp body_text(:gone, _nick),
    do: dgettext("share", "This link is no longer active. The chat is still there.")

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
end
