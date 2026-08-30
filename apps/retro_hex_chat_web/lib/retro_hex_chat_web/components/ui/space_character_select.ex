defmodule RetroHexChatWeb.Components.UI.SpaceCharacterSelect do
  @moduledoc """
  Character picker shown when a player enters the virtual space.

  This is the space's antechamber, and the only one in the app that was already
  there: a space is a place rather than an event, so it never starts and never
  ends, and the door to it is the moment you decide who to be. A waiting room in
  front of it would be ceremony for walking into somewhere already open.

  A pure function component: it renders the roster of selectable avatars (the
  legacy hero plus the PixelLab-authored classes) as an animated preview grid.
  Clicking a card emits `space_select_avatar` with the chosen id, which
  `SpaceLive` stores as its `avatar` — that assign gates the mounting of the
  `SpaceCanvasHook` canvas, so the world only boots once a character is chosen.
  Choosing is entering; there is no second confirmation, because the card is the
  door.

  Above the grid it says who is inside right now, which is the one thing an
  antechamber owes a person standing in it. Below it, the host puts whatever it
  offers there — sharing the address, opening the space in a tab of its own —
  because those differ between the chat and a tab of its own and the picker
  does not.

  The animated previews are CSS sprites (`.rh-charsel-sprite`, defined in
  `retrohex.css`); the avatar id list is the server's `VirtualSpace.avatars/0`,
  kept in sync with the JS atlas `AVATAR_IDS`.
  """
  use RetroHexChatWeb, :html

  @labels %{
    "hero" => "Hero",
    "knight" => "Knight",
    "sorceress" => "Sorceress",
    "archer" => "Archer",
    "barbarian" => "Barbarian",
    "rogue" => "Rogue",
    "cleric" => "Cleric",
    "monk" => "Monk"
  }

  attr :avatars, :list, required: true, doc: "Selectable avatar ids (VirtualSpace.avatars/0)"
  attr :selected, :string, default: nil, doc: "Avatar id to highlight as the default choice"

  attr :roster, :list,
    default: [],
    doc: "Nicknames standing in the space right now (VirtualSpace.roster/1)"

  slot :footer, doc: "What the host offers at the door: a share link, a tab of its own"

  @spec space_character_select(map()) :: Phoenix.LiveView.Rendered.t()
  def space_character_select(assigns) do
    ~H"""
    <div
      class="absolute inset-0 z-20 flex items-center justify-center bg-background/95 p-4"
      data-testid="space-character-select"
    >
      <div class="bg-canvas shadow-retro-field p-4 w-full max-w-lg">
        <h2 class="mb-3 text-center text-sm font-bold">
          {dgettext("chat", "Choose your character")}
        </h2>
        <div class="grid grid-cols-4 gap-2">
          <button
            :for={id <- @avatars}
            type="button"
            phx-click="space_select_avatar"
            phx-value-avatar={id}
            data-testid={"space-avatar-#{id}"}
            aria-pressed={to_string(id == @selected)}
            class={[
              "flex flex-col items-center gap-1 p-2 bg-surface hover:bg-surface-hover",
              "focus:outline-none focus-visible:shadow-retro-sunken",
              if(id == @selected,
                do: "shadow-retro-sunken bg-surface-hover",
                else: "shadow-retro-raised"
              )
            ]}
          >
            <span class="rh-charsel-preview">
              <span class={["rh-charsel-sprite", "rh-charsel-sprite--#{id}"]} aria-hidden="true" />
            </span>
            <span class="text-xs">{avatar_label(id)}</span>
          </button>
        </div>

        <div class="mt-3 border-t border-border pt-2 text-xs" data-testid="space-roster">
          <p class="font-bold">{dgettext("chat", "Inside right now")}</p>
          <p :if={@roster == []} class="text-muted-foreground">
            {dgettext("chat", "Nobody is in here yet.")}
          </p>
          <p :if={@roster != []} class="truncate" data-testid="space-roster-names">
            {Enum.join(@roster, " · ")}
          </p>
        </div>

        <div :if={@footer != []} class="mt-3 flex flex-wrap items-center gap-2">
          {render_slot(@footer)}
        </div>
      </div>
    </div>
    """
  end

  # Class names are proper nouns kept identical across locales, so they are not
  # run through gettext (avoids a per-name catalog entry for no translation).
  @spec avatar_label(String.t()) :: String.t()
  defp avatar_label(id), do: Map.get(@labels, id, id)
end
