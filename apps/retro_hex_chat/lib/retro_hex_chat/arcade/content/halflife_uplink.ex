defmodule RetroHexChat.Arcade.Content.HalflifeUplink do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Half-Life: Uplink (1999) is the official demo for Half-Life, featuring three unique levels not found in the full game. As Gordon Freeman, navigate the aftermath of the Black Mesa incident through previously unseen areas of the research facility.",
        "These exclusive demo levels showcase Half-Life's revolutionary approach to FPS storytelling — no cutscenes, no interruptions, everything happens in real-time around you. Fight alien creatures and military forces while solving environmental puzzles.",
        "Uplink was freely distributed by Valve as a standalone demo and remains freely redistributable. It runs on the Xash3D engine (GoldSrc-compatible) compiled to WebAssembly, delivering the full Half-Life experience in your browser."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / look"},
        {"Left Click", "Primary fire"},
        {"Right Click", "Secondary fire / alt-fire"},
        {"E", "Use / interact"},
        {"Space", "Jump"},
        {"Shift", "Crouch (hold)"},
        {"R", "Reload"},
        {"1–5", "Weapon category"},
        {"Q", "Last weapon used"},
        {"F", "Flashlight toggle"},
        {"Esc", "Menu"}
      ],
      tips: [
        "Most weapons have a secondary fire mode (Right Click) — the shotgun's double-barrel blast is devastating.",
        "Use the flashlight (F) in dark areas — but note it shares power with your HEV suit's sprint.",
        "Headcrabs are weak to the crowbar — save ammo for bigger threats like vortigaunts and soldiers.",
        "Environmental storytelling is key — listen to scientist dialogues and read signs for clues.",
        "Crouch-jumping (Shift + Space) lets you reach higher ledges — essential for some puzzle areas."
      ]
    }
  end
end
