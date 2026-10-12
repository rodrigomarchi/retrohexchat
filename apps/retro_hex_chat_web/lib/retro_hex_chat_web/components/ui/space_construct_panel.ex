defmodule RetroHexChatWeb.Components.UI.SpaceConstructPanel do
  @moduledoc """
  The frame a Construct piece's panel is drawn into: a sign's line (and the
  field to rewrite it), a board's topic and pinned lines, a screen's newest
  picture, an arcade cabinet's games.

  A `<template>` inside the `phx-update="ignore"` space shell, like the gate's
  confirm: the server answers a press of E with the panel's data, and
  `assets/js/lib/space/construct/panels.js` clones this frame and fills it.
  Every sentence the frame can need is carried here as a `data-` attribute,
  translated, because the panel's data never carries a sentence.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Space.PixelIcon

  alias RetroHexChat.VirtualSpace.Construct.Layout

  @spec space_construct_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def space_construct_panel(assigns) do
    assigns = assign(assigns, :sign_max, Layout.sign_max())

    ~H"""
    <template data-space-panel-template {sentences()}>
      <div class="w-[min(22rem,80vw)] text-left" data-testid="space-panel">
        <p data-space-panel-title class="space-ui-modal__title"></p>
        <div data-space-panel-body class="space-panel-body max-h-[50vh] overflow-y-auto"></div>
        <form data-space-panel-sign hidden class="mt-2 flex gap-1">
          <input
            type="text"
            maxlength={@sign_max}
            autocomplete="off"
            data-space-panel-input
            data-testid="space-panel-input"
            aria-label={dgettext("chat", "What the sign says")}
            class="space-ui-field h-8 min-w-0 flex-1"
          />
          <.button
            type="submit"
            size="sm"
            variant="pixel"
            data-testid="space-panel-save"
            class="h-8 px-2"
          >
            <:icon><.pixel_icon name={:ok} /></:icon>
            {dgettext("chat", "Save")}
          </.button>
        </form>
        <p data-space-panel-status aria-live="polite" class="space-panel-status mt-1"></p>
        <div class="mt-2 flex justify-end">
          <.button
            type="button"
            size="sm"
            variant="pixel-secondary"
            data-space-panel-close
            data-testid="space-panel-close"
          >
            <:icon><.pixel_icon name={:cancel} /></:icon>
            {dgettext("chat", "Close")}
          </.button>
        </div>
      </div>
    </template>
    """
  end

  defp sentences do
    %{
      "data-title-sign" => dpgettext("chat", "signpost", "Sign"),
      "data-title-board" => dpgettext("chat", "notice board", "Board"),
      "data-title-screen" => dpgettext("chat", "television", "Screen"),
      "data-title-arcade" => dgettext("chat", "Arcade cabinet"),
      "data-empty-sign" => dgettext("chat", "Nothing is written on this signboard yet."),
      "data-empty-board" => dgettext("chat", "This channel has no topic and nothing pinned yet."),
      "data-empty-screen" => dgettext("chat", "Nobody has posted a picture here yet."),
      "data-topic" => dgettext("chat", "Topic"),
      "data-pinned" => dgettext("chat", "Pinned"),
      "data-posted-by" => dgettext("chat", "Sent by %{name}", name: "%{name}"),
      "data-opens-in-tab" => dgettext("chat", "Opens in another browser tab.")
    }
  end
end
