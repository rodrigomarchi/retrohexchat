defmodule RetroHexChat.Arcade.Content.Quake2Shareware do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Quake II (1997) — \"The Invasion\" — the official shareware demo featuring Unit 1 of the single-player campaign. Earth's counterattack against the alien Strogg has gone wrong, and you crash-land alone on their planet Stroggos."
        ),
        gettext(
          "Quake II introduced mission-based level design with interconnected maps, colored lighting, and a more structured narrative. The Strogg are cybernetic aliens that harvest humans for parts — the body horror elements give the game a uniquely disturbing atmosphere."
        ),
        gettext(
          "This demo includes the complete first unit with multiple interconnected levels. The engine supports mouselook, crouching, and weapon reloading — features that were revolutionary for 1997."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / look")},
        {gettext("Left Click"), gettext("Fire weapon")},
        {"E", gettext("Use / interact")},
        {gettext("Space"), gettext("Jump")},
        {"C", gettext("Crouch")},
        {"R", gettext("Reload")},
        {"1–9", gettext("Select weapon")},
        {"Tab", gettext("Inventory")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "Unlike Quake 1, levels are interconnected — you'll revisit areas with new keys and equipment."
        ),
        gettext(
          "Crouching (C) lets you access vents and low passages — essential for progression."
        ),
        gettext(
          "The Strogg come in many varieties — learn which weapons work best against each type."
        ),
        gettext(
          "Colored lighting is used for environmental storytelling — red areas often signal danger."
        ),
        gettext("Reload during quiet moments — don't get caught mid-reload in a firefight.")
      ]
    }
  end
end
