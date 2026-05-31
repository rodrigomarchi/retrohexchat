defmodule RetroHexChat.Arcade.Content.Freedoom2 do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Freedoom: Phase 2 is a complete free replacement for DOOM II: Hell on Earth — 32 levels of intense FPS action with the legendary Super Shotgun. All assets are original community creations under the BSD license."
        ),
        gettext(
          "Like DOOM II, Phase 2 features larger, more complex levels with tougher enemy encounters. The Super Shotgun (weapon slot 3, alternate) makes its appearance here, and the level design takes full advantage of DOOM II's expanded monster roster."
        ),
        gettext(
          "Phase 2 is fully compatible with the massive library of DOOM II PWADs — thousands of community-made map packs and total conversions work seamlessly with this free IWAD."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / turn")},
        {gettext("Left Click"), gettext("Fire weapon")},
        {"E", gettext("Use / open doors")},
        {gettext("Space"), gettext("Jump (PrBoom+)")},
        {"1–7", gettext("Select weapon")},
        {"Tab", gettext("Toggle automap")},
        {gettext("Shift"), gettext("Run (hold)")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "The Super Shotgun is your best friend — devastating at close range with its double-barrel blast."
        ),
        gettext(
          "Phase 2 levels are more open and complex than Phase 1 — explore thoroughly for secrets."
        ),
        gettext("This IWAD works with most DOOM II community mods and megaWADs."),
        gettext(
          "Ammo management becomes critical in later levels — don't waste rockets on weak enemies."
        )
      ]
    }
  end
end
