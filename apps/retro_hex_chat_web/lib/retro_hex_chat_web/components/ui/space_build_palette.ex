defmodule RetroHexChatWeb.Components.UI.SpaceBuildPalette do
  @moduledoc """
  The Construct's build palette: one key per placeable kind, plus turn and
  remove, floating at the top-left of the canvas.

  Static markup inside the `phx-update="ignore"` space shell, like the virtual
  pad. `assets/js/lib/space/construct/palette.js` draws each kind's sprite into
  its key, marks the armed kind with `data-selected`, and enables turn and
  remove while a placed piece is picked. Why an edit was refused is said in the
  status line, from the translated sentences carried here as `data-` templates,
  because the server answers with a reason and never with a sentence.
  """
  use RetroHexChatWeb, :html

  alias RetroHexChatWeb.Icons

  @spec space_build_palette(map()) :: Phoenix.LiveView.Rendered.t()
  def space_build_palette(assigns) do
    ~H"""
    <div
      data-construct-palette
      data-testid="construct-palette"
      role="toolbar"
      aria-label={dgettext("chat", "Build")}
      class="absolute left-3 top-3 z-10 flex max-w-[calc(100%-1.5rem)] flex-col gap-1 select-none"
      {refusal_templates()}
    >
      <div class="flex flex-wrap gap-1">
        <.build_kind kind="chair" label={dgettext("chat", "Chair")} />
        <.build_kind kind="table" label={dpgettext("chat", "furniture", "Table")} />
        <.build_kind kind="tree" label={dgettext("chat", "Tree")} />
        <.build_kind kind="lamp" label={dgettext("chat", "Lamp")} />
        <button
          type="button"
          tabindex="-1"
          disabled
          data-construct-rotate
          data-testid="construct-rotate"
          aria-label={dgettext("chat", "Turn")}
          title={dgettext("chat", "Turn") <> " (R)"}
          class="space-build-tool icon-on-dark"
        >
          <Icons.icon_btn_refresh class="h-5 w-5" />
          <span>{dgettext("chat", "Turn")}</span>
        </button>
        <button
          type="button"
          tabindex="-1"
          disabled
          data-construct-remove
          data-testid="construct-remove"
          aria-label={dgettext("chat", "Remove")}
          title={dgettext("chat", "Remove") <> " (Delete)"}
          class="space-build-tool icon-on-dark"
        >
          <Icons.icon_btn_trash class="h-5 w-5" />
          <span>{dgettext("chat", "Remove")}</span>
        </button>
      </div>
      <p
        data-construct-status
        data-testid="construct-status"
        aria-live="polite"
        data-hint={
          dgettext(
            "chat",
            "Pick a piece, then click the floor. Drag a piece to move it, right-click to remove it."
          )
        }
        class="w-fit max-w-full bg-black/60 px-1 text-[10px] text-white"
      >
        {dgettext(
          "chat",
          "Pick a piece, then click the floor. Drag a piece to move it, right-click to remove it."
        )}
      </p>
    </div>
    """
  end

  attr :kind, :string, required: true
  attr :label, :string, required: true

  defp build_kind(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-construct-kind={@kind}
      data-selected="false"
      data-testid={"construct-kind-#{@kind}"}
      aria-label={@label}
      class="space-build-tool"
    >
      <canvas data-construct-thumb width="40" height="40" class="space-build-thumb h-10 w-10">
      </canvas>
      <span>{@label}</span>
    </button>
    """
  end

  # One sentence per reason the server can refuse an edit with, keyed the way
  # the reply names it.
  defp refusal_templates do
    %{
      "data-refused-occupied" => dgettext("chat", "There is already a piece on that spot."),
      "data-refused-someone_there" => dgettext("chat", "Somebody is standing on that spot."),
      "data-refused-reserved" => dgettext("chat", "Keep the way to the gate clear."),
      "data-refused-would_trap" =>
        dgettext("chat", "That would leave somebody with no way back to the gate."),
      "data-refused-seat_taken" => dgettext("chat", "Somebody is sitting in it."),
      "data-refused-full" => dgettext("chat", "The Construct is full."),
      "data-refused-out_of_bounds" => dgettext("chat", "That is off the floor."),
      "data-refused-cooldown" => dgettext("chat", "One piece at a time. Try again."),
      "data-refused-default" => dgettext("chat", "That piece cannot go there.")
    }
  end
end
