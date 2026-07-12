defmodule RetroHexChatWeb.Components.UI.SpaceCharacterSelect do
  @moduledoc """
  Character picker shown when a player enters the virtual space.

  A pure function component: it renders the roster of selectable avatars (the
  legacy hero plus the PixelLab-authored classes) as an animated preview grid.
  Clicking a card emits `space_select_avatar` with the chosen id, which the
  `ChatLive` host stores as `space_avatar` — that assign gates the mounting of
  the `SpaceCanvasHook` canvas, so the world only boots once a character is
  chosen. The animated previews are CSS sprites (`.rh-charsel-sprite`, defined in
  `retrohex.css`); the avatar id list is the server's `VirtualSpace.avatars/0`,
  kept in sync with the JS atlas `AVATAR_IDS`.
  """
  use RetroHexChatWeb, :html

  @labels %{
    "redtunic_hero" => "Hero",
    "sorceress" => "Sorceress",
    "knight" => "Knight",
    "archer" => "Archer",
    "barbarian" => "Barbarian",
    "rogue" => "Rogue",
    "cleric" => "Cleric",
    "monk" => "Monk",
    "iso_knight" => "Knight ⚔"
  }

  attr :avatars, :list, required: true, doc: "Selectable avatar ids (VirtualSpace.avatars/0)"
  attr :selected, :string, default: nil, doc: "Avatar id to highlight as the default choice"

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
      </div>
    </div>
    """
  end

  # Class names are proper nouns kept identical across locales, so they are not
  # run through gettext (avoids a per-name catalog entry for no translation).
  @spec avatar_label(String.t()) :: String.t()
  defp avatar_label(id), do: Map.get(@labels, id, id)
end
