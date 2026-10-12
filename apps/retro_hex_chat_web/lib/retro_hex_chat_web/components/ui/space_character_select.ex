defmodule RetroHexChatWeb.Components.UI.SpaceCharacterSelect do
  @moduledoc """
  Character picker shown when a player enters the virtual space, drawn in the
  space's pixel-art kit (`features/space-ui.css`): a parchment panel framed in
  wood, one parchment slot per character, gilded when chosen.

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
  antechamber owes a person standing in it. Below it goes whatever the screen
  offers at the door — sharing the address, most of all.

  `remember_key` makes the picker default to the character this browser chose
  last time. It is the browser's memory rather than the server's because
  nothing on the server outlives a visit: the surface is mounted afresh every
  time somebody walks in, and the chat that used to hold this no longer has a
  space in it.

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

  attr :remember_key, :string,
    default: nil,
    doc: "localStorage key the last chosen character is kept under; nil to not remember"

  slot :footer, doc: "What the screen offers at the door: a share link, most of all"

  @spec space_character_select(map()) :: Phoenix.LiveView.Rendered.t()
  def space_character_select(assigns) do
    ~H"""
    <div
      class="space-ui-veil absolute inset-0 z-20 flex items-center justify-center overflow-y-auto p-2"
      data-testid="space-character-select"
      id={@remember_key && "space-character-select"}
      phx-hook={@remember_key && "SpaceCharacterMemoryHook"}
      data-remember-key={@remember_key}
    >
      <div class="space-ui-panel m-auto w-full max-w-lg">
        <h2 class="space-ui-heading mb-3 text-center">
          {dgettext("chat", "Choose your character")}
        </h2>
        <div class="grid grid-cols-4 gap-1">
          <button
            :for={id <- @avatars}
            type="button"
            phx-click="space_select_avatar"
            phx-value-avatar={id}
            data-testid={"space-avatar-#{id}"}
            aria-pressed={to_string(id == @selected)}
            class="space-ui-slot flex flex-col items-center gap-1 px-1 py-2"
          >
            <span class="rh-charsel-preview">
              <span class={["rh-charsel-sprite", "rh-charsel-sprite--#{id}"]} aria-hidden="true" />
            </span>
            <span>{avatar_label(id)}</span>
          </button>
        </div>

        <div class="space-ui-rule mt-3 pt-2" data-testid="space-roster">
          <p class="space-panel-label mt-0">{dgettext("chat", "Inside right now")}</p>
          <p :if={@roster == []} class="space-panel-note">
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
