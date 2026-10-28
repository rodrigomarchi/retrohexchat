defmodule RetroHexChatWeb.Components.UI.Games.GameStage do
  @moduledoc """
  The stage a Retro Game is played on, wherever it is played: against the
  computer (`/play/<game>`), with somebody (the P2P room) or watched
  (`/watch/<token>`).

  The game's canvas fills the stage. Everything chosen around a match — the
  mode, the difficulty, a partner, a link, the result — is the `:menu`, a neon
  panel over the game (`Dialog skin="arcade"`, scoped to the stage). While a
  match runs nothing is drawn over the picture but a dim key in the corner
  that opens the menu (`on_menu`), and, on a touch screen only, the on-screen
  pad over the bottom of the game (`features/arcade-ui.css`).

  The page owns the state: whether the menu is open (`menu_open`), whether it
  may be dismissed (`menu_lock` — before a match and after it, there is
  nothing to go back to), and what Esc or a click outside does (`on_close`).
  The look is the arcade kit (`.arcade-ui`); the pad is the space's pad
  (`VirtualPad`, `lib/virtual_pad.js`) in that kit.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Games.ArcadeIcon
  import RetroHexChatWeb.Components.UI.VirtualPad

  attr :id, :string, required: true
  attr :menu_open, :boolean, default: false
  attr :menu_lock, :boolean, default: false, doc: "the menu takes no Esc and no click outside"
  attr :on_close, :any, default: nil, doc: "what dismissing the menu does"
  attr :on_menu, :any, default: nil, doc: "what the corner key does; no key without it"
  attr :pad, :map, default: nil, doc: "`RetroGamesPanel.game_pad/1`, or nil for no pad"
  attr :pad_idle, :boolean, default: false, doc: "no match running: the pad takes no press"
  attr :game_id, :string, default: nil, doc: "names the pad's keys, so another game's are new"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true, doc: "the game's canvas"
  slot :menu, doc: "what the menu holds"

  @spec game_stage(map()) :: Phoenix.LiveView.Rendered.t()
  def game_stage(assigns) do
    ~H"""
    <div id={@id} class={["arcade-ui game-stage", @class]} {@rest}>
      {render_slot(@inner_block)}

      <button
        :if={@on_menu && !@menu_open}
        type="button"
        class="arcade-corner-key game-stage__menu-key"
        phx-click={@on_menu}
        aria-label={dgettext("games", "Menu")}
        title={dgettext("games", "Menu (Esc)")}
        data-testid="game-stage-menu-key"
      >
        <.arcade_icon name={:pause} />
      </button>

      <.stage_pad
        :if={@pad}
        id={"#{@id}-pad"}
        pad={@pad}
        game_id={@game_id}
        idle={@pad_idle}
        hidden={@menu_open}
      />

      <.dialog
        id={"#{@id}-menu"}
        show={@menu_open}
        scope={:window}
        skin="arcade"
        lock={@menu_lock}
        on_cancel={@on_close}
      >
        <div
          class="flex min-h-0 flex-col gap-retro-10 overflow-y-auto text-center"
          data-testid="game-stage-menu"
        >
          {render_slot(@menu)}
        </div>
      </.dialog>
    </div>
    """
  end

  @doc """
  The menu's key that presents the whole stage fullscreen, and back.
  """
  attr :stage, :string, required: true, doc: "the stage's id"

  @spec stage_fullscreen_button(map()) :: Phoenix.LiveView.Rendered.t()
  def stage_fullscreen_button(assigns) do
    ~H"""
    <button
      id={"#{@stage}-fullscreen"}
      type="button"
      phx-hook="StageFullscreenHook"
      data-stage={@stage}
      class="arcade-button arcade-button--secondary group inline-flex items-center justify-center gap-retro-4"
      data-testid="game-stage-fullscreen"
    >
      <.arcade_icon name={:fullscreen_enter} class="group-data-[fullscreen]:hidden" />
      <.arcade_icon name={:fullscreen_exit} class="hidden group-data-[fullscreen]:inline-block" />
      <span class="group-data-[fullscreen]:hidden">{dgettext("games", "Full screen")}</span>
      <span class="hidden group-data-[fullscreen]:inline">
        {dgettext("games", "Leave full screen")}
      </span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :pad, :map, required: true
  attr :game_id, :string, default: nil
  attr :idle, :boolean, default: false
  attr :hidden, :boolean, default: false, doc: "the menu is open: nothing beside it"

  # Over the bottom of the game, as a handheld is held: the actions under the
  # left thumb, the cross under the right.
  defp stage_pad(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="RetroGamePadHook"
      data-pad
      data-idle={@idle}
      data-hidden={@hidden}
      data-testid="retro-game-pad"
      role="group"
      aria-label={dgettext("games", "On-screen controls")}
      class="game-stage__pad select-none items-end justify-between gap-retro-8 touch-none"
    >
      <%!-- The keys are left alone by later renders: a finger holding one keeps
            its pressed look (`data-pressed`, set by the pad's script). Their id
            names the game, so another game's pad is drawn anew. --%>
      <div
        id={"#{@id}-keys-#{@game_id}"}
        phx-update="ignore"
        class="flex min-w-0 flex-1 items-end justify-between gap-retro-8"
      >
        <%!-- Two columns: four actions at most, two rows, a long name on two lines. --%>
        <div class="grid min-w-0 max-w-[280px] flex-1 grid-cols-2 gap-retro-6">
          <.pad_button
            :for={action <- @pad.actions}
            action={action.key}
            label={action.label}
            class="pad-button--label h-14 w-full"
          >
            {action.label}
          </.pad_button>
        </div>
        <.pad_cross
          dirs={@pad.dirs}
          skin="arcade"
          labels={
            %{
              "up" => dgettext("games", "Up"),
              "down" => dgettext("games", "Down"),
              "left" => dgettext("games", "Left"),
              "right" => dgettext("games", "Right")
            }
          }
        />
      </div>
    </div>
    """
  end
end
