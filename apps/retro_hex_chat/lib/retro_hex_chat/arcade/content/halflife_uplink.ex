defmodule RetroHexChat.Arcade.Content.HalflifeUplink do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Half-Life: Uplink (1999) is the official demo for Half-Life, featuring three unique levels not found in the full game. As Gordon Freeman, navigate the aftermath of the Black Mesa incident through previously unseen areas of the research facility."
        ),
        gettext(
          "These exclusive demo levels showcase Half-Life's revolutionary approach to FPS storytelling — no cutscenes, no interruptions, everything happens in real-time around you. Fight alien creatures and military forces while solving environmental puzzles."
        ),
        gettext(
          "Uplink was freely distributed by Valve as a standalone demo and remains freely redistributable. It runs on the Xash3D engine (GoldSrc-compatible) compiled to WebAssembly, delivering the full Half-Life experience in your browser."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / look")},
        {gettext("Left Click"), gettext("Primary fire")},
        {gettext("Right Click"), gettext("Secondary fire / alt-fire")},
        {"E", gettext("Use / interact")},
        {gettext("Space"), gettext("Jump")},
        {gettext("Shift"), gettext("Crouch (hold)")},
        {"R", gettext("Reload")},
        {"1–5", gettext("Weapon category")},
        {"Q", gettext("Last weapon used")},
        {"F", gettext("Flashlight toggle")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "Most weapons have a secondary fire mode (Right Click) — the shotgun's double-barrel blast is devastating."
        ),
        gettext(
          "Use the flashlight (F) in dark areas — but note it shares power with your HEV suit's sprint."
        ),
        gettext(
          "Headcrabs are weak to the crowbar — save ammo for bigger threats like vortigaunts and soldiers."
        ),
        gettext(
          "Environmental storytelling is key — listen to scientist dialogues and read signs for clues."
        ),
        gettext(
          "Crouch-jumping (Shift + Space) lets you reach higher ledges — essential for some puzzle areas."
        )
      ]
    }
  end
end
