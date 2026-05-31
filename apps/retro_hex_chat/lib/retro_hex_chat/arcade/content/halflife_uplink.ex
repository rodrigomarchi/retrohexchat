defmodule RetroHexChat.Arcade.Content.HalflifeUplink do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Half-Life: Uplink (1999) is the official demo for Half-Life, featuring three unique levels not found in the full game. As Gordon Freeman, navigate the aftermath of the Black Mesa incident through previously unseen areas of the research facility."
        ),
        dgettext(
          "arcade",
          "These exclusive demo levels showcase Half-Life's revolutionary approach to FPS storytelling — no cutscenes, no interruptions, everything happens in real-time around you. Fight alien creatures and military forces while solving environmental puzzles."
        ),
        dgettext(
          "arcade",
          "Uplink was freely distributed by Valve as a standalone demo and remains freely redistributable. It runs on the Xash3D engine (GoldSrc-compatible) compiled to WebAssembly, delivering the full Half-Life experience in your browser."
        )
      ],
      controls: [
        {dgettext("arcade", "W / ↑"), dgettext("arcade", "Move forward")},
        {dgettext("arcade", "S / ↓"), dgettext("arcade", "Move backward")},
        {"A", dgettext("arcade", "Strafe left")},
        {"D", dgettext("arcade", "Strafe right")},
        {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / look")},
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Primary fire")},
        {dgettext("arcade", "Right Click"), dgettext("arcade", "Secondary fire / alt-fire")},
        {"E", dgettext("arcade", "Use / interact")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Jump")},
        {dgettext("arcade", "Shift"), dgettext("arcade", "Crouch (hold)")},
        {"R", dgettext("arcade", "Reload")},
        {"1–5", dgettext("arcade", "Weapon category")},
        {"Q", dgettext("arcade", "Last weapon used")},
        {"F", dgettext("arcade", "Flashlight toggle")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ],
      tips: [
        dgettext(
          "arcade",
          "Most weapons have a secondary fire mode (Right Click) — the shotgun's double-barrel blast is devastating."
        ),
        dgettext(
          "arcade",
          "Use the flashlight (F) in dark areas — but note it shares power with your HEV suit's sprint."
        ),
        dgettext(
          "arcade",
          "Headcrabs are weak to the crowbar — save ammo for bigger threats like vortigaunts and soldiers."
        ),
        dgettext(
          "arcade",
          "Environmental storytelling is key — listen to scientist dialogues and read signs for clues."
        ),
        dgettext(
          "arcade",
          "Crouch-jumping (Shift + Space) lets you reach higher ledges — essential for some puzzle areas."
        )
      ]
    }
  end
end
