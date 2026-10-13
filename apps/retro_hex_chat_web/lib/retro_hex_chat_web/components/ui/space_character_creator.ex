defmodule RetroHexChatWeb.Components.UI.SpaceCharacterCreator do
  @moduledoc """
  The Space's character creator, drawn in the space's pixel-art kit: a turning,
  walking preview of the character beside a tab per part — body, skin, outfit,
  hair, headwear, face — each a row of pieces and, where the piece can be
  dyed, a row of colours.

  This is the space's antechamber: the door to a place that is already open is
  the moment you decide who to be, so making the character *is* the door, and
  the same creator opens over the map to change clothes without leaving.

  Every choice is made from art that already exists — the pieces are built
  offline (`virtual.space/tools/build_creator.py`) and composed in the browser
  — so trying things costs nothing and nothing waits on a server. Each click
  sends `creator_set` with a field and a choice, and the LiveView answers with
  the new recipe (`RetroHexChat.VirtualSpace.CharacterRecipe.put/3`), which the
  preview hook (`SpaceCreatorPreviewHook`) composes and draws. `creator_tab`
  switches the part shown and `creator_randomize` makes somebody new. Only the
  open tab is rendered: the rest are a click away and cost no markup.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Space.PixelIcon

  alias RetroHexChat.VirtualSpace.CharacterCatalog, as: Catalog
  alias RetroHexChat.VirtualSpace.CharacterRecipe
  alias RetroHexChatWeb.SpaceAssets

  @tabs ~w(body skin outfit hair hat face)

  attr :id, :string, required: true

  attr :recipe, :string,
    required: true,
    doc: "the character being made (a CharacterRecipe string)"

  attr :tab, :string, default: "body", doc: "the part whose choices are shown"
  attr :title, :string, required: true

  attr :roster, :list,
    default: nil,
    doc: "nicknames inside right now, said at the door; nil to say nothing"

  slot :footer, doc: "What the screen offers beside the character: entering, sharing, cancelling"

  @spec space_character_creator(map()) :: Phoenix.LiveView.Rendered.t()
  def space_character_creator(assigns) do
    {:ok, recipe} = assigns.recipe |> CharacterRecipe.coerce() |> CharacterRecipe.parse()

    assigns =
      assigns
      |> assign(:parsed, recipe)
      |> assign(:recipe, CharacterRecipe.to_string(recipe))
      |> assign(:tabs, Enum.filter(@tabs, &tab_available?/1))

    ~H"""
    <div
      class="space-ui-veil absolute inset-0 z-20 flex items-center justify-center overflow-y-auto p-2"
      data-testid="space-character-creator"
    >
      <div class="space-ui-panel m-auto w-full max-w-2xl">
        <h2 class="space-ui-heading mb-2 text-center">{@title}</h2>
        <div class="space-creator">
          <div
            id={"#{@id}-preview"}
            phx-hook="SpaceCreatorPreviewHook"
            data-recipe={@recipe}
            data-character-catalog={SpaceAssets.character_catalog_url()}
            data-testid="space-creator-preview"
            class="space-creator__preview"
          >
            <div id={"#{@id}-stage"} phx-update="ignore" class="space-creator__stage">
              <canvas data-creator-canvas aria-hidden="true"></canvas>
            </div>
            <div class="flex justify-center gap-1">
              <button
                type="button"
                data-creator-turn="-1"
                class="space-build-tool space-build-tool--action"
                aria-label={dgettext("chat", "Turn left")}
                title={dgettext("chat", "Turn left")}
                data-testid="space-creator-turn-left"
              >
                <.pixel_icon name={:turn} class="-scale-x-100" />
              </button>
              <button
                type="button"
                data-creator-turn="1"
                class="space-build-tool space-build-tool--action"
                aria-label={dgettext("chat", "Turn right")}
                title={dgettext("chat", "Turn right")}
                data-testid="space-creator-turn-right"
              >
                <.pixel_icon name={:turn} />
              </button>
            </div>
          </div>

          <div class="min-w-0 flex-1">
            <div
              role="tablist"
              class="flex flex-wrap gap-1"
              aria-label={dgettext("chat", "Character")}
            >
              <button
                :for={tab <- @tabs}
                type="button"
                role="tab"
                aria-selected={to_string(tab == @tab)}
                data-selected={to_string(tab == @tab)}
                phx-click="creator_tab"
                phx-value-tab={tab}
                class="space-build-tab"
                data-testid={"space-creator-tab-#{tab}"}
              >
                {tab_label(tab)}
              </button>
            </div>
            <div
              role="tabpanel"
              class="space-creator__panel"
              data-testid={"space-creator-panel-#{@tab}"}
            >
              <.part tab={@tab} recipe={@parsed} />
            </div>
            <div class="mt-2 flex justify-end">
              <.button
                type="button"
                size="sm"
                variant="pixel-secondary"
                phx-click="creator_randomize"
                data-testid="space-creator-randomize"
              >
                <:icon><.pixel_icon name={:dice} /></:icon>
                {dgettext("chat", "Surprise me")}
              </.button>
            </div>
          </div>
        </div>

        <div :if={@roster} class="space-ui-rule mt-3 pt-2" data-testid="space-roster">
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

  attr :tab, :string, required: true
  attr :recipe, :map, required: true

  defp part(%{tab: "body"} = assigns) do
    ~H"""
    <.choices
      field="body"
      options={for id <- Catalog.bodies(), do: {id, body_label(id)}}
      current={@recipe.body}
    />
    """
  end

  defp part(%{tab: "skin"} = assigns) do
    ~H"""
    <.swatches field="skin" palette="skin" current={@recipe.skin} label={dgettext("chat", "Skin")} />
    """
  end

  defp part(%{tab: "outfit"} = assigns) do
    assigns = assign(assigns, :channels, Map.get(Catalog.outfits(), assigns.recipe.outfit, 0))

    ~H"""
    <.choices
      field="outfit"
      options={for id <- Catalog.outfits_for(@recipe.body), do: {id, outfit_label(id)}}
      current={@recipe.outfit}
    />
    <.swatches
      :if={@channels > 0}
      field="primary"
      palette="fabric"
      current={@recipe.primary}
      label={dgettext("chat", "Main colour")}
    />
    <.swatches
      :if={@channels > 1}
      field="secondary"
      palette="fabric"
      current={@recipe.secondary}
      label={dgettext("chat", "Trim colour")}
    />
    """
  end

  defp part(%{tab: "hair"} = assigns) do
    ~H"""
    <.choices
      field="hair"
      options={[{"0", dgettext("chat", "Bald")} | for(id <- Catalog.hair(), do: {id, hair_label(id)})]}
      current={@recipe.hair || "0"}
    />
    <.swatches
      :if={@recipe.hair}
      field="hair_colour"
      palette="hair"
      current={@recipe.hair_colour}
      label={dgettext("chat", "Hair colour")}
    />
    """
  end

  defp part(%{tab: "hat"} = assigns) do
    assigns = assign(assigns, :channels, Map.get(Catalog.headwear(), assigns.recipe.hat, 0))

    ~H"""
    <.choices
      field="hat"
      options={[
        {"0", dpgettext("chat", "no headwear", "None")}
        | for(id <- Catalog.headwear() |> Map.keys() |> Enum.sort(), do: {id, headwear_label(id)})
      ]}
      current={@recipe.hat || "0"}
    />
    <.swatches
      :if={@channels > 0}
      field="hat_primary"
      palette="fabric"
      current={@recipe.hat_primary}
      label={dgettext("chat", "Main colour")}
    />
    <.swatches
      :if={@channels > 1}
      field="hat_secondary"
      palette="fabric"
      current={@recipe.hat_secondary}
      label={dgettext("chat", "Trim colour")}
    />
    """
  end

  defp part(%{tab: "face"} = assigns) do
    ~H"""
    <.choices
      field="face"
      options={[
        {"0", dpgettext("chat", "no face item", "None")}
        | for(id <- Catalog.face(), do: {id, face_label(id)})
      ]}
      current={@recipe.face || "0"}
    />
    """
  end

  attr :field, :string, required: true
  attr :options, :list, required: true
  attr :current, :string, required: true

  defp choices(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1">
      <button
        :for={{value, label} <- @options}
        type="button"
        phx-click="creator_set"
        phx-value-field={@field}
        phx-value-choice={value}
        aria-pressed={to_string(value == @current)}
        class="space-ui-slot px-2 py-1"
        data-testid={"space-creator-option-#{@field}-#{value}"}
      >
        {label}
      </button>
    </div>
    """
  end

  attr :field, :string, required: true
  attr :palette, :string, required: true
  attr :current, :integer, required: true
  attr :label, :string, required: true

  defp swatches(assigns) do
    assigns = assign(assigns, :names, colour_labels(assigns.palette))

    ~H"""
    <fieldset class="mt-2">
      <legend class="space-panel-label mt-0">{@label}</legend>
      <div class="flex flex-wrap gap-1">
        <button
          :for={{name, i} <- Enum.with_index(@names)}
          type="button"
          phx-click="creator_set"
          phx-value-field={@field}
          phx-value-choice={i}
          aria-pressed={to_string(i == @current)}
          aria-label={name}
          title={name}
          class={["space-creator-swatch", "rh-creator-swatch--#{@palette}-#{i}"]}
          data-testid={"space-creator-swatch-#{@field}-#{i}"}
        >
        </button>
      </div>
    </fieldset>
    """
  end

  defp tab_available?("face"), do: Catalog.face() != []
  defp tab_available?(_tab), do: true

  @doc "The name of a creator tab."
  @spec tab_label(String.t()) :: String.t()
  def tab_label("body"), do: dpgettext("chat", "character creator", "Body")
  def tab_label("skin"), do: dpgettext("chat", "character creator", "Skin")
  def tab_label("outfit"), do: dpgettext("chat", "character creator", "Outfit")
  def tab_label("hair"), do: dpgettext("chat", "character creator", "Hair")
  def tab_label("hat"), do: dpgettext("chat", "character creator", "Headwear")
  def tab_label("face"), do: dpgettext("chat", "character creator", "Face")

  @doc "The name of a body type."
  @spec body_label(String.t()) :: String.t()
  def body_label("av"), do: dpgettext("chat", "character body", "Average")
  def body_label(id), do: id

  @doc "The name of an outfit."
  @spec outfit_label(String.t()) :: String.t()
  def outfit_label("bas"), do: dpgettext("chat", "character outfit", "Undershirt")
  def outfit_label("tun"), do: dpgettext("chat", "character outfit", "Tunic")
  def outfit_label(id), do: id

  @doc "The name of a hairstyle."
  @spec hair_label(String.t()) :: String.t()
  def hair_label("lng"), do: dpgettext("chat", "character hair", "Long")
  def hair_label(id), do: id

  @doc "The name of a hat."
  @spec headwear_label(String.t()) :: String.t()
  def headwear_label("adv"), do: dpgettext("chat", "character headwear", "Adventurer hat")
  def headwear_label(id), do: id

  @doc "The name of a face item."
  @spec face_label(String.t()) :: String.t()
  def face_label(id), do: id

  @doc "The colour names of a palette, in the catalog's order."
  @spec colour_labels(String.t()) :: [String.t()]
  def colour_labels("skin") do
    [
      dpgettext("chat", "skin colour", "Porcelain"),
      dpgettext("chat", "skin colour", "Fair"),
      dpgettext("chat", "skin colour", "Light tan"),
      dpgettext("chat", "skin colour", "Olive"),
      dpgettext("chat", "skin colour", "Tan"),
      dpgettext("chat", "skin colour", "Brown"),
      dpgettext("chat", "skin colour", "Deep brown"),
      dpgettext("chat", "skin colour", "Ebony")
    ]
  end

  def colour_labels("hair") do
    [
      dpgettext("chat", "hair colour", "Black"),
      dpgettext("chat", "hair colour", "Dark brown"),
      dpgettext("chat", "hair colour", "Brown"),
      dpgettext("chat", "hair colour", "Auburn"),
      dpgettext("chat", "hair colour", "Copper"),
      dpgettext("chat", "hair colour", "Blonde"),
      dpgettext("chat", "hair colour", "Platinum"),
      dpgettext("chat", "hair colour", "Grey"),
      dpgettext("chat", "hair colour", "White"),
      dpgettext("chat", "hair colour", "Blue"),
      dpgettext("chat", "hair colour", "Green"),
      dpgettext("chat", "hair colour", "Pink")
    ]
  end

  def colour_labels("fabric") do
    [
      dpgettext("chat", "cloth colour", "Crimson"),
      dpgettext("chat", "cloth colour", "Scarlet"),
      dpgettext("chat", "cloth colour", "Orange"),
      dpgettext("chat", "cloth colour", "Gold"),
      dpgettext("chat", "cloth colour", "Lime"),
      dpgettext("chat", "cloth colour", "Forest"),
      dpgettext("chat", "cloth colour", "Teal"),
      dpgettext("chat", "cloth colour", "Sky"),
      dpgettext("chat", "cloth colour", "Navy"),
      dpgettext("chat", "cloth colour", "Royal blue"),
      dpgettext("chat", "cloth colour", "Violet"),
      dpgettext("chat", "cloth colour", "Plum"),
      dpgettext("chat", "cloth colour", "Rose"),
      dpgettext("chat", "cloth colour", "Leather"),
      dpgettext("chat", "cloth colour", "Charcoal"),
      dpgettext("chat", "cloth colour", "Ivory")
    ]
  end
end
