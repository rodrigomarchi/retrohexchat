defmodule RetroHexChatWeb.Components.UI.SpaceBuildPalette do
  @moduledoc """
  The Construct's build palette, kept off the map until it is wanted: a Build
  key at the top-left opens a drawer (a side panel on a desktop, a sheet from
  the bottom on a phone) with a tab per group of kinds and one key per kind;
  a card beside the Build key says what is in hand — the kind armed, the floor
  armed, or the piece picked — with turn, remove and drop.

  Static markup inside the `phx-update="ignore"` space shell, like the virtual
  pad. `assets/js/lib/space/construct/palette.js` opens and closes the drawer
  (`data-open` on the root), draws each kind's sprite into its key and into the
  card, marks the armed kind with `data-selected`, and enables turn and remove
  while they apply. Why an edit was refused is said in the status line, from
  the translated sentences carried here as `data-` templates, because the
  server answers with a reason and never with a sentence.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Space.PixelIcon
  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChat.VirtualSpace

  attr :conversation, :string,
    default: "channel",
    doc: "the conversation the Construct belongs to: a board is a channel's alone"

  @spec space_build_palette(map()) :: Phoenix.LiveView.Rendered.t()
  def space_build_palette(assigns) do
    assigns = assign(assigns, :groups, groups(assigns.conversation))

    ~H"""
    <%!-- The palette is a layer over the map holding three things: the Build key,
          the drawer it opens (every kind, in tabs) and the card that says what
          is in hand. Only they take the pointer; the floor between them stays
          the map's. --%>
    <div
      data-construct-palette
      data-open="false"
      data-testid="construct-palette"
      class="space-build pointer-events-none absolute inset-0 z-10 select-none"
      {refusal_templates()}
    >
      <.tool_button
        label={dgettext("chat", "Build") <> " (B)"}
        variant="pixel"
        size="md"
        tabindex="-1"
        data-construct-toggle
        aria-expanded="false"
        aria-keyshortcuts="B"
        aria-controls="construct-drawer"
        data-testid="construct-toggle"
        class="pointer-events-auto absolute left-3 top-3 h-11 min-h-11 w-11 min-w-11"
      >
        <.pixel_icon name={:build} />
      </.tool_button>

      <section
        id="construct-drawer"
        data-construct-drawer
        aria-label={dgettext("chat", "Build")}
        data-testid="construct-drawer"
        class="space-build-drawer pointer-events-auto"
      >
        <div class="flex items-start gap-1">
          <div role="tablist" class="space-build-tabs flex min-w-0 flex-1 gap-1">
            <.build_tab
              :for={{{group, label, _kinds}, index} <- Enum.with_index(@groups)}
              group={group}
              label={label}
              icon={tab_icon(group)}
              selected={index == 0}
            />
            <.build_tab group="floor" label={dgettext("chat", "Floor")} icon={:tab_floor} />
          </div>
          <.tool_button
            label={dgettext("chat", "Close")}
            variant="pixel"
            size="md"
            tabindex="-1"
            data-construct-close
            data-testid="construct-close"
            class="h-11 min-h-11 w-11 min-w-11 shrink-0"
          >
            <.pixel_icon name={:cancel} />
          </.tool_button>
        </div>
        <div
          :for={{{group, _label, kinds}, index} <- Enum.with_index(@groups)}
          data-construct-group={group}
          hidden={index != 0}
          class="space-build-group"
        >
          <.build_kind :for={{kind, label} <- kinds} kind={kind} label={label} />
        </div>
        <div data-construct-group="floor" hidden class="space-build-group">
          <.build_material
            :for={{material, tile, label} <- materials()}
            material={material}
            tile={tile}
            label={label}
          />
        </div>
        <p
          data-construct-hint
          data-hint={hint()}
          data-touch-hint={touch_hint()}
          data-paint-hint={
            dgettext("chat", "Press on the floor and drag: the whole rectangle is painted.")
          }
          class="space-ui-plank space-build-status"
        >
          {hint()}
        </p>
      </section>

      <%!-- Why an edit was refused, over the room whether the menu is open or
            not: on a phone the menu shuts on every choice, and a refusal said
            inside it would be said to nobody. It only says; a click through it
            still reaches the floor. --%>
      <p
        data-construct-status
        data-testid="construct-status"
        data-refused="false"
        role="status"
        aria-live="polite"
        hidden
        class="space-ui-plank space-build-refusal"
      >
      </p>

      <%!-- What is in hand: the kind armed to place, the floor armed to paint, or
            the piece picked on the floor, with what can be done to it — and the
            way to let go of it, which a touch screen has no Esc or right-click for. --%>
      <div
        data-construct-holding
        hidden
        role="group"
        data-testid="construct-holding"
        class="space-build-holding pointer-events-auto"
      >
        <canvas
          data-construct-holding-thumb
          width="40"
          height="40"
          class="space-build-thumb h-10 w-10"
        >
        </canvas>
        <span data-construct-holding-name class="space-build-holding__name"></span>
        <button
          type="button"
          tabindex="-1"
          disabled
          data-construct-rotate
          data-testid="construct-rotate"
          aria-label={dgettext("chat", "Turn")}
          title={dgettext("chat", "Turn") <> " (R)"}
          class="space-build-tool space-build-tool--action"
        >
          <.pixel_icon name={:turn} />
        </button>
        <button
          type="button"
          tabindex="-1"
          disabled
          data-construct-remove
          data-testid="construct-remove"
          aria-label={dgettext("chat", "Remove")}
          title={dgettext("chat", "Remove") <> " (Delete)"}
          class="space-build-tool space-build-tool--action"
        >
          <.pixel_icon name={:remove} />
        </button>
        <button
          type="button"
          tabindex="-1"
          data-construct-drop
          data-testid="construct-drop"
          aria-label={dpgettext("chat", "let go of a piece", "Drop")}
          title={dpgettext("chat", "let go of a piece", "Drop") <> " (Esc)"}
          class="space-build-tool space-build-tool--action"
        >
          <.pixel_icon name={:cancel} />
        </button>
      </div>
    </div>
    """
  end

  attr :group, :string, required: true
  attr :label, :string, required: true
  attr :icon, :atom, required: true
  attr :selected, :boolean, default: false

  # A tab says its group by an icon; its name is beside it where there is
  # room, and always its accessible name and tooltip.
  defp build_tab(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      role="tab"
      data-construct-tab={@group}
      data-selected={to_string(@selected)}
      aria-selected={to_string(@selected)}
      aria-label={@label}
      title={@label}
      data-testid={"construct-tab-#{@group}"}
      class="space-build-tab"
    >
      <.pixel_icon name={@icon} />
      <span class="space-build-tab__label">{@label}</span>
    </button>
    """
  end

  defp hint do
    dgettext(
      "chat",
      "Pick a piece, then click the floor. Drag a piece to move it, right-click to remove it."
    )
  end

  defp touch_hint do
    dgettext(
      "chat",
      "Choose a piece, then tap the floor to place it. Tap a piece on the floor to use %{turn} or %{remove} at the top.",
      turn: dgettext("chat", "Turn"),
      remove: dgettext("chat", "Remove")
    )
  end

  defp tab_icon("furniture"), do: :tab_furniture
  defp tab_icon("office"), do: :tab_office
  defp tab_icon("garden"), do: :tab_garden
  defp tab_icon("gamer"), do: :tab_gamer
  defp tab_icon("structure"), do: :tab_structure
  defp tab_icon("fun"), do: :tab_fun
  defp tab_icon("eot"), do: :tab_eot
  defp tab_icon("fair"), do: :tab_fair
  defp tab_icon("fantasy"), do: :tab_fantasy

  attr :kind, :string, required: true
  attr :label, :string, required: true

  defp build_kind(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-construct-kind={@kind}
      data-selected="false"
      data-testid={"construct-kind-#{@kind}"}
      aria-label={@label}
      class="space-build-tool"
    >
      <canvas data-construct-thumb width="40" height="40" class="space-build-thumb h-10 w-10">
      </canvas>
      <span>{@label}</span>
    </button>
    """
  end

  attr :material, :string, required: true
  attr :tile, :string, required: true
  attr :label, :string, required: true

  defp build_material(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-construct-material={@material}
      data-construct-tile={@tile}
      data-selected="false"
      data-testid={"construct-material-#{@material}"}
      aria-label={@label}
      class="space-build-tool"
    >
      <canvas data-construct-thumb width="40" height="40" class="space-build-thumb h-10 w-10">
      </canvas>
      <span>{@label}</span>
    </button>
    """
  end

  # The floor's paints, each drawn from its own floor tile, and the eraser
  # (the white floor itself, "none" to the server).
  defp materials do
    names = %{
      "wood" => dgettext("chat", "Wood"),
      "stone" => dgettext("chat", "Stone"),
      "grass" => dgettext("chat", "Grass"),
      "carpet_red" => dgettext("chat", "Red carpet"),
      "carpet_blue" => dgettext("chat", "Blue carpet"),
      "checker" => dgettext("chat", "Checkerboard")
    }

    {:ok, map} = VirtualSpace.get_map("construct")

    Enum.map(map.materials, &{&1.id, &1.tile, Map.get(names, &1.id, &1.id)}) ++
      [{"none", white_tile(map), dgettext("chat", "Erase")}]
  end

  # The white floor's own tile: whatever the middle of the island is made of.
  defp white_tile(map) do
    map.layers.floor
    |> Enum.at(div(map.height, 2))
    |> String.at(div(map.width, 2))
  end

  # The tabs, in palette order. Each kind sits in the tab its catalog entry
  # names (`priv/maps/construct.json`), in the order `kinds/0` lists them; a
  # kind built only in channels is left out of a private Construct's palette.
  defp groups(conversation) do
    {:ok, map} = VirtualSpace.get_map("construct")

    for {group, label} <- tabs() do
      kinds =
        for {kind, kind_label} <- kinds(),
            entry = map.catalog[kind],
            entry.group == group,
            entry.only in [nil] or conversation in entry.only,
            do: {kind, kind_label}

      {group, label, kinds}
    end
  end

  defp tabs do
    [
      {"furniture", dgettext("chat", "Furniture")},
      {"office", dpgettext("chat", "construct palette", "Office")},
      {"garden", dgettext("chat", "Garden")},
      {"gamer", dgettext("chat", "Gamer")},
      {"structure", dgettext("chat", "Structure")},
      {"fun", dpgettext("chat", "construct palette", "Fun")},
      {"fair", dpgettext("chat", "construct palette", "Fair")},
      {"fantasy", dpgettext("chat", "construct palette", "Fantasy")},
      {"eot", dgettext("chat", "End of Time")}
    ]
  end

  # Every placeable kind and its name on its key. The End of Time's people,
  # Chrono Trigger's Nu and Lucca's Telepod are called by their own names,
  # which no language translates.
  defp kinds do
    [
      {"chair", dgettext("chat", "Chair")},
      {"armchair", dgettext("chat", "Armchair")},
      {"sofa", dgettext("chat", "Sofa")},
      {"table", dpgettext("chat", "furniture", "Table")},
      {"long_table", dgettext("chat", "Long table")},
      {"coffee_table", dgettext("chat", "Coffee table")},
      {"bed", dgettext("chat", "Bed")},
      {"nightstand", dgettext("chat", "Nightstand")},
      {"wardrobe", dgettext("chat", "Wardrobe")},
      {"dresser", dgettext("chat", "Dresser")},
      {"bookshelf", dgettext("chat", "Bookshelf")},
      {"tv_stand", dgettext("chat", "TV stand")},
      {"fridge", dgettext("chat", "Fridge")},
      {"stove", dpgettext("chat", "kitchen", "Stove")},
      {"kitchen_counter", dgettext("chat", "Kitchen counter")},
      {"piano", dgettext("chat", "Piano")},
      {"fireplace", dgettext("chat", "Fireplace")},
      {"grandfather_clock", dgettext("chat", "Grandfather clock")},
      {"lamp", dgettext("chat", "Lamp")},
      {"table_lamp", dgettext("chat", "Table lamp")},
      {"big_vase", dgettext("chat", "Vase")},
      {"plant", dgettext("chat", "Plant")},
      {"tree", dgettext("chat", "Tree")},
      {"wingback_chair", dgettext("chat", "Wingback chair")},
      {"office_desk", dgettext("chat", "Office desk")},
      {"office_chair", dgettext("chat", "Office chair")},
      {"meeting_table", dgettext("chat", "Meeting table")},
      {"file_cabinet", dgettext("chat", "File cabinet")},
      {"printer", dgettext("chat", "Printer")},
      {"whiteboard", dgettext("chat", "Whiteboard")},
      {"water_cooler", dgettext("chat", "Water cooler")},
      {"coffee_machine", dgettext("chat", "Coffee machine")},
      {"vending_machine", dgettext("chat", "Vending machine")},
      {"coat_rack", dgettext("chat", "Coat rack")},
      {"cactus", dgettext("chat", "Cactus")},
      {"bush", dgettext("chat", "Bush")},
      {"flower_bed", dgettext("chat", "Flower bed")},
      {"boulder", dgettext("chat", "Boulder")},
      {"park_bench", dgettext("chat", "Park bench")},
      {"fountain", dgettext("chat", "Fountain")},
      {"fence", dgettext("chat", "Fence")},
      {"street_lamp", dgettext("chat", "Street lamp")},
      {"pond", dgettext("chat", "Pond")},
      {"palm_tree", dgettext("chat", "Palm tree")},
      {"pine_tree", dgettext("chat", "Pine tree")},
      {"giant_mushroom", dgettext("chat", "Giant mushroom")},
      {"mailbox", dpgettext("chat", "garden", "Mailbox")},
      {"victorian_lamp", dgettext("chat", "Victorian lamp")},
      {"water_bucket", dgettext("chat", "Bucket")},
      {"signpost", dgettext("chat", "Signpost")},
      {"pool_table", dgettext("chat", "Pool table")},
      {"ping_pong_table", dgettext("chat", "Ping-pong table")},
      {"beanbag", dgettext("chat", "Beanbag")},
      {"gaming_chair", dgettext("chat", "Gaming chair")},
      {"neon_sign", dgettext("chat", "Neon sign")},
      {"server_rack", dgettext("chat", "Server rack")},
      {"robot", dgettext("chat", "Robot")},
      {"retro_console", dgettext("chat", "Retro console")},
      {"jukebox", dgettext("chat", "Jukebox")},
      {"cryo_pod", dgettext("chat", "Cryo pod")},
      {"hologram", dgettext("chat", "Hologram")},
      {"racing_arcade", dgettext("chat", "Racing arcade")},
      {"neon_totem", dgettext("chat", "Neon totem")},
      {"crt_tv", dgettext("chat", "CRT TV")},
      {"wall", dgettext("chat", "Wall")},
      {"corner", dpgettext("chat", "wall", "Corner")},
      {"door", dgettext("chat", "Door")},
      {"golden_gate", dgettext("chat", "Golden gate")},
      {"golden_railing", dgettext("chat", "Golden railing")},
      {"iron_fence", dgettext("chat", "Iron fence")},
      {"teleporter", dgettext("chat", "Teleporter")},
      {"die", dpgettext("chat", "game piece", "Die")},
      {"coin", dgettext("chat", "Coin")},
      {"sign", dpgettext("chat", "signpost", "Sign")},
      {"arcade", dgettext("chat", "Arcade cabinet")},
      {"board", dpgettext("chat", "notice board", "Board")},
      {"screen", dpgettext("chat", "television", "Screen")},
      {"big_top", dgettext("chat", "Big top")},
      {"fortune_tent", dgettext("chat", "Fortune-teller's tent")},
      {"circus_tent", dgettext("chat", "Circus tent")},
      {"purple_tent", dgettext("chat", "Purple tent")},
      {"pennant_tent", dgettext("chat", "Pennant tent")},
      {"striped_tent", dgettext("chat", "Striped tent")},
      {"weapon_stall", dgettext("chat", "Weapon stall")},
      {"snack_stall", dgettext("chat", "Snack stall")},
      {"fair_gate", dgettext("chat", "Fair gate")},
      {"bunting", dgettext("chat", "Bunting")},
      {"flag_pole", dgettext("chat", "Flagpole")},
      {"paper_lantern", dgettext("chat", "Paper lantern")},
      {"splash_fountain", dgettext("chat", "Fair fountain")},
      {"crates", dgettext("chat", "Crates")},
      {"planter", dgettext("chat", "Planter")},
      {"fair_bench", dgettext("chat", "Wooden bench")},
      {"notice_board", dgettext("chat", "Fair notice board")},
      {"hedge", dgettext("chat", "Hedge")},
      {"potted_tree", dgettext("chat", "Potted tree")},
      {"bell_tower", dgettext("chat", "Bell tower")},
      {"brazier", dgettext("chat", "Brazier")},
      {"magic_portal", dgettext("chat", "Magic portal")},
      {"sparkle", dgettext("chat", "Sparkle")},
      {"ancient_gate", dgettext("chat", "Ancient gate")},
      {"stone_altar", dgettext("chat", "Stone altar")},
      {"stone_totem", dgettext("chat", "Stone totem")},
      {"stone_arch", dgettext("chat", "Stone arch")},
      {"glowing_arch", dgettext("chat", "Glowing arch")},
      {"stone_column", dgettext("chat", "Stone column")},
      {"eot_lamp", dgettext("chat", "End of Time lamppost")},
      {"eot_portal", dgettext("chat", "Code gate")},
      {"telepod", "Telepod"},
      {"nu", "Nu"},
      {"eot_tv", dgettext("chat", "Old TV")},
      {"eot_fire", dgettext("chat", "Campfire")},
      {"eot_dama", dgettext("chat", "Spirit Bomb")},
      {"eot_morpheus", "Morpheus"},
      {"eot_neo", "Neo"},
      {"eot_gandalf", "Gandalf"},
      {"eot_balrog", "Balrog"},
      {"eot_goku", "Goku"},
      {"eot_delorean", "DeLorean"}
    ]
  end

  # One sentence per reason the server can refuse an edit with, keyed the way
  # the reply names it.
  defp refusal_templates do
    %{
      "data-refused-occupied" => dgettext("chat", "There is already a piece on that spot."),
      "data-refused-someone_there" => dgettext("chat", "Somebody is standing on that spot."),
      "data-refused-reserved" => dgettext("chat", "Keep the way to the gate clear."),
      "data-refused-would_trap" =>
        dgettext("chat", "That would leave somebody with no way back to the gate."),
      "data-refused-seat_taken" => dgettext("chat", "Somebody is sitting in it."),
      "data-refused-full" => dgettext("chat", "The Construct is full."),
      "data-refused-out_of_bounds" => dgettext("chat", "That is off the floor."),
      "data-refused-cooldown" => dgettext("chat", "Only one piece at a time, please wait."),
      "data-refused-not_allowed" =>
        dgettext("chat", "Only whoever put up this sign can change it."),
      "data-refused-too_long" => dgettext("chat", "That line is too long for the signboard."),
      "data-refused-muted" => dgettext("chat", "You are muted by an administrator"),
      "data-refused-unknown_material" => dgettext("chat", "That floor cannot be painted."),
      "data-refused-unknown_kind" => dgettext("chat", "That piece cannot be built here."),
      "data-refused-default" => dgettext("chat", "That piece cannot go there.")
    }
  end
end
