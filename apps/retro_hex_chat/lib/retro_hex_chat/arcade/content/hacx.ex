defmodule RetroHexChat.Arcade.Content.Hacx do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "HacX: Twitch 'n Kill (1997) is a cyberpunk total conversion for DOOM II that went standalone. Set in a dystopian future, you hack through corporate security systems and cyborg enemies in neon-lit corridors."
        ),
        gettext(
          "Originally released as a commercial PWAD, HacX v1.2 was later released as a free standalone IWAD. It features completely new weapons (from tasers to molecular disintegrators), enemies (robots, drones, cyborgs), textures, and music."
        ),
        gettext(
          "The cyberpunk aesthetic gives the DOOM engine a completely different feel — think Blade Runner meets DOOM, with circuit boards, holographic displays, and corporate dystopia replacing hell and demons."
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
          "The weapons are all new with different behavior — experiment with each one's strengths."
        ),
        gettext("Cyborg enemies can be tougher than classic DOOM monsters — keep your distance."),
        gettext(
          "The cyberpunk environments can be visually dense — use the automap to stay oriented."
        ),
        gettext("This is the standalone v1.2 IWAD — no DOOM II required.")
      ]
    }
  end
end
