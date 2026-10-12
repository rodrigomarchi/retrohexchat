defmodule RetroHexChatWeb.Components.UI.SpaceBuildPalette do
  @moduledoc """
  The Construct's build palette: a tab per group of kinds (furniture,
  structure, the pieces that do something), one key per kind in the open tab,
  plus turn and remove, floating at the top-left of the canvas.

  Static markup inside the `phx-update="ignore"` space shell, like the virtual
  pad. `assets/js/lib/space/construct/palette.js` draws each kind's sprite into
  its key, marks the armed kind with `data-selected`, and enables turn and
  remove while a placed piece is picked. Why an edit was refused is said in the
  status line, from the translated sentences carried here as `data-` templates,
  because the server answers with a reason and never with a sentence.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Space.PixelIcon

  alias RetroHexChat.VirtualSpace

  attr :conversation, :string,
    default: "channel",
    doc: "the conversation the Construct belongs to: a board is a channel's alone"

  @spec space_build_palette(map()) :: Phoenix.LiveView.Rendered.t()
  def space_build_palette(assigns) do
    assigns = assign(assigns, :groups, groups(assigns.conversation))

    ~H"""
    <div
      data-construct-palette
      data-testid="construct-palette"
      role="toolbar"
      aria-label={dgettext("chat", "Build")}
      class="absolute left-3 top-3 z-10 flex max-w-[calc(100%-5rem)] flex-col gap-1 select-none"
      {refusal_templates()}
    >
      <div role="tablist" class="flex flex-wrap gap-1">
        <button
          :for={{{group, label, _kinds}, index} <- Enum.with_index(@groups)}
          type="button"
          tabindex="-1"
          role="tab"
          data-construct-tab={group}
          data-selected={if index == 0, do: "true", else: "false"}
          aria-selected={if index == 0, do: "true", else: "false"}
          data-testid={"construct-tab-#{group}"}
          class="space-build-tab"
        >
          {label}
        </button>
        <button
          type="button"
          tabindex="-1"
          role="tab"
          data-construct-tab="floor"
          data-selected="false"
          aria-selected="false"
          data-testid="construct-tab-floor"
          class="space-build-tab"
        >
          {dgettext("chat", "Floor")}
        </button>
      </div>
      <div class="flex max-w-full items-start gap-1">
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
          <span>{dgettext("chat", "Turn")}</span>
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
          <span>{dgettext("chat", "Remove")}</span>
        </button>
      </div>
      <p
        data-construct-status
        data-testid="construct-status"
        aria-live="polite"
        data-hint={
          dgettext(
            "chat",
            "Pick a piece, then click the floor. Drag a piece to move it, right-click to remove it."
          )
        }
        data-paint-hint={
          dgettext("chat", "Press on the floor and drag: the whole rectangle is painted.")
        }
        class="space-ui-plank space-build-status w-fit max-w-full"
      >
        {dgettext(
          "chat",
          "Pick a piece, then click the floor. Drag a piece to move it, right-click to remove it."
        )}
      </p>
    </div>
    """
  end

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
      {"eot", dgettext("chat", "End of Time")}
    ]
  end

  # Every placeable kind and its name on its key. The End of Time's people
  # are called by their own names, which no language translates.
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
      {"wall", dgettext("chat", "Wall")},
      {"corner", dpgettext("chat", "wall", "Corner")},
      {"door", dgettext("chat", "Door")},
      {"teleporter", dgettext("chat", "Teleporter")},
      {"die", dpgettext("chat", "game piece", "Die")},
      {"coin", dgettext("chat", "Coin")},
      {"sign", dpgettext("chat", "signpost", "Sign")},
      {"arcade", dgettext("chat", "Arcade cabinet")},
      {"board", dpgettext("chat", "notice board", "Board")},
      {"screen", dpgettext("chat", "television", "Screen")},
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
