defmodule RetroHexChat.Arcade.Content.Freedoom2 do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Freedoom: Phase 2 is a complete free replacement for DOOM II: Hell on Earth — 32 levels of intense FPS action with the legendary Super Shotgun. All assets are original community creations under the BSD license."
        ),
        dgettext(
          "arcade",
          "Like DOOM II, Phase 2 features larger, more complex levels with tougher enemy encounters. The Super Shotgun (weapon slot 3, alternate) makes its appearance here, and the level design takes full advantage of DOOM II's expanded monster roster."
        ),
        dgettext(
          "arcade",
          "Phase 2 is fully compatible with the massive library of DOOM II PWADs — thousands of community-made map packs and total conversions work seamlessly with this free IWAD."
        )
      ],
      controls: [
        {dgettext("arcade", "W / ↑"), dgettext("arcade", "Move forward")},
        {dgettext("arcade", "S / ↓"), dgettext("arcade", "Move backward")},
        {"A", dgettext("arcade", "Strafe left")},
        {"D", dgettext("arcade", "Strafe right")},
        {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / turn")},
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire weapon")},
        {"E", dgettext("arcade", "Use / open doors")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Jump (PrBoom+)")},
        {"1–7", dgettext("arcade", "Select weapon")},
        {"Tab", dgettext("arcade", "Toggle automap")},
        {dgettext("arcade", "Shift"), dgettext("arcade", "Run (hold)")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ],
      tips: [
        dgettext(
          "arcade",
          "The Super Shotgun is your best friend — devastating at close range with its double-barrel blast."
        ),
        dgettext(
          "arcade",
          "Phase 2 levels are more open and complex than Phase 1 — explore thoroughly for secrets."
        ),
        dgettext("arcade", "This IWAD works with most DOOM II community mods and megaWADs."),
        dgettext(
          "arcade",
          "Ammo management becomes critical in later levels — don't waste rockets on weak enemies."
        )
      ]
    }
  end
end
