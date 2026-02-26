defmodule RetroHexChat.Arcade.Content.Quake2Shareware do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Quake II (1997) — \"The Invasion\" — the official shareware demo featuring Unit 1 of the single-player campaign. Earth's counterattack against the alien Strogg has gone wrong, and you crash-land alone on their planet Stroggos.",
        "Quake II introduced mission-based level design with interconnected maps, colored lighting, and a more structured narrative. The Strogg are cybernetic aliens that harvest humans for parts — the body horror elements give the game a uniquely disturbing atmosphere.",
        "This demo includes the complete first unit with multiple interconnected levels. The engine supports mouselook, crouching, and weapon reloading — features that were revolutionary for 1997."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / look"},
        {"Left Click", "Fire weapon"},
        {"E", "Use / interact"},
        {"Space", "Jump"},
        {"C", "Crouch"},
        {"R", "Reload"},
        {"1–9", "Select weapon"},
        {"Tab", "Inventory"},
        {"Esc", "Menu"}
      ],
      tips: [
        "Unlike Quake 1, levels are interconnected — you'll revisit areas with new keys and equipment.",
        "Crouching (C) lets you access vents and low passages — essential for progression.",
        "The Strogg come in many varieties — learn which weapons work best against each type.",
        "Colored lighting is used for environmental storytelling — red areas often signal danger.",
        "Reload during quiet moments — don't get caught mid-reload in a firefight."
      ]
    }
  end
end
