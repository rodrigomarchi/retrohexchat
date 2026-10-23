defmodule RetroHexChat.Arcade.Content.Quake2Shareware do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade.Content.Controls

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Quake II (1997) — \"The Invasion\" — the official shareware demo featuring Unit 1 of the single-player campaign. Earth's counterattack against the alien Strogg has gone wrong, and you crash-land alone on their planet Stroggos."
        ),
        dgettext(
          "arcade",
          "Quake II introduced mission-based level design with interconnected maps, colored lighting, and a more structured narrative. The Strogg are cybernetic aliens that harvest humans for parts — the body horror elements give the game a uniquely disturbing atmosphere."
        ),
        dgettext(
          "arcade",
          "This demo includes the complete first unit with multiple interconnected levels. The engine supports mouselook, crouching, and weapon reloading — features that were revolutionary for 1997."
        )
      ],
      controls:
        Controls.adapt(Controls.quake(),
          weapons: [
            {"C", dgettext("arcade", "Crouch")},
            {"R", dgettext("arcade", "Reload")},
            {"1–9", dgettext("arcade", "Select weapon")}
          ],
          scores: {"Tab", dgettext("arcade", "Inventory")}
        ),
      tips: [
        dgettext(
          "arcade",
          "Unlike Quake 1, levels are interconnected — you'll revisit areas with new keys and equipment."
        ),
        dgettext(
          "arcade",
          "Crouching (C) lets you access vents and low passages — essential for progression."
        ),
        dgettext(
          "arcade",
          "The Strogg come in many varieties — learn which weapons work best against each type."
        ),
        dgettext(
          "arcade",
          "Colored lighting is used for environmental storytelling — red areas often signal danger."
        ),
        dgettext(
          "arcade",
          "Reload during quiet moments — don't get caught mid-reload in a firefight."
        )
      ]
    }
  end
end
