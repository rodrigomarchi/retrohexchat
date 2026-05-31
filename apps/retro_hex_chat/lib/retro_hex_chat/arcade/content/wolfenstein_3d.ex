defmodule RetroHexChat.Arcade.Content.Wolfenstein3d do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Wolfenstein 3D (1992) — the grandfather of first-person shooters. Episode 1: \"Escape from Castle Wolfenstein\" — 10 levels of castle-storming action as American spy B.J. Blazkowicz fights his way out of a Nazi fortress."
        ),
        gettext(
          "Created by id Software before DOOM, Wolfenstein 3D established the FPS genre. The gameplay is pure and immediate: navigate maze-like castle floors, collect keys, find secrets, and shoot everything that moves. No jumping, no looking up or down — just raw, fast-paced shooting."
        ),
        gettext(
          "This shareware episode features 10 levels (including a secret level) with guards, SS troops, officers, and the boss Hans Grösse. The game uses the classic arrow key + Ctrl scheme, though WASD is also supported."
        )
      ],
      controls: [
        {gettext("↑ / W"), gettext("Move forward")},
        {gettext("↓ / S"), gettext("Move backward")},
        {"← / →", gettext("Turn left / right")},
        {gettext("Alt + ←/→"), gettext("Strafe")},
        {gettext("Ctrl"), gettext("Fire weapon")},
        {gettext("Space"), gettext("Open doors / use")},
        {gettext("Shift"), gettext("Run (hold)")},
        {"1–4", gettext("Select weapon")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "Push every wall — Wolfenstein 3D is famous for its push-wall secrets hiding treasure and ammo."
        ),
        gettext("Listen for guards — you can hear enemies through doors before opening them."),
        gettext(
          "The chaingun (weapon 4) is your best friend — it fires faster than anything else."
        ),
        gettext(
          "Conserve ammo on guards (use the knife or pistol) and save the chaingun for officers and bosses."
        ),
        gettext(
          "Treasure counts toward your score — try for 100% on each level for maximum points."
        )
      ]
    }
  end
end
