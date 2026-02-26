defmodule RetroHexChat.Arcade.Content.Freedoom2 do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Freedoom: Phase 2 is a complete free replacement for DOOM II: Hell on Earth — 32 levels of intense FPS action with the legendary Super Shotgun. All assets are original community creations under the BSD license.",
        "Like DOOM II, Phase 2 features larger, more complex levels with tougher enemy encounters. The Super Shotgun (weapon slot 3, alternate) makes its appearance here, and the level design takes full advantage of DOOM II's expanded monster roster.",
        "Phase 2 is fully compatible with the massive library of DOOM II PWADs — thousands of community-made map packs and total conversions work seamlessly with this free IWAD."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / turn"},
        {"Left Click", "Fire weapon"},
        {"E", "Use / open doors"},
        {"Space", "Jump (PrBoom+)"},
        {"1–7", "Select weapon"},
        {"Tab", "Toggle automap"},
        {"Shift", "Run (hold)"},
        {"Esc", "Menu"}
      ],
      tips: [
        "The Super Shotgun is your best friend — devastating at close range with its double-barrel blast.",
        "Phase 2 levels are more open and complex than Phase 1 — explore thoroughly for secrets.",
        "This IWAD works with most DOOM II community mods and megaWADs.",
        "Ammo management becomes critical in later levels — don't waste rockets on weak enemies."
      ]
    }
  end
end
