defmodule RetroHexChat.Arcade.Content.Hacx do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "HacX: Twitch 'n Kill (1997) is a cyberpunk total conversion for DOOM II that went standalone. Set in a dystopian future, you hack through corporate security systems and cyborg enemies in neon-lit corridors."
        ),
        dgettext(
          "arcade",
          "Originally released as a commercial PWAD, HacX v1.2 was later released as a free standalone IWAD. It features completely new weapons (from tasers to molecular disintegrators), enemies (robots, drones, cyborgs), textures, and music."
        ),
        dgettext(
          "arcade",
          "The cyberpunk aesthetic gives the DOOM engine a completely different feel — think Blade Runner meets DOOM, with circuit boards, holographic displays, and corporate dystopia replacing hell and demons."
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
          "The weapons are all new with different behavior — experiment with each one's strengths."
        ),
        dgettext(
          "arcade",
          "Cyborg enemies can be tougher than classic DOOM monsters — keep your distance."
        ),
        dgettext(
          "arcade",
          "The cyberpunk environments can be visually dense — use the automap to stay oriented."
        ),
        dgettext("arcade", "This is the standalone v1.2 IWAD — no DOOM II required.")
      ]
    }
  end
end
