defmodule RetroHexChat.Arcade.Content.Hacx do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "HacX: Twitch 'n Kill (1997) is a cyberpunk total conversion for DOOM II that went standalone. Set in a dystopian future, you hack through corporate security systems and cyborg enemies in neon-lit corridors.",
        "Originally released as a commercial PWAD, HacX v1.2 was later released as a free standalone IWAD. It features completely new weapons (from tasers to molecular disintegrators), enemies (robots, drones, cyborgs), textures, and music.",
        "The cyberpunk aesthetic gives the DOOM engine a completely different feel — think Blade Runner meets DOOM, with circuit boards, holographic displays, and corporate dystopia replacing hell and demons."
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
        "The weapons are all new with different behavior — experiment with each one's strengths.",
        "Cyborg enemies can be tougher than classic DOOM monsters — keep your distance.",
        "The cyberpunk environments can be visually dense — use the automap to stay oriented.",
        "This is the standalone v1.2 IWAD — no DOOM II required."
      ]
    }
  end
end
