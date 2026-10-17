defmodule RetroHexChatWeb.Components.UI.Site.DesktopFiles do
  @moduledoc """
  The two files on a visitor's desk — README.txt and the Trash — and the
  popups they open. Each is a plain `data-modal` popup, shown by the icon's
  `data-show-target` and closed by its own title bar, a click outside or
  Escape (`desktop.js`), so they work before the chat has started.

  `files/0` is the list the desktop's icons read, so an icon and its popup
  cannot name two different files.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Landing.LandingMockups, only: [readme_text: 1]
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @type file :: %{popup: String.t(), label: String.t(), icon_fn: atom()}

  @doc "The files on the desk, each with the id of the popup it opens."
  @spec files() :: [file()]
  def files do
    [
      %{popup: "readme-popup", label: dgettext("landing", "README.txt"), icon_fn: :icon_notepad},
      %{popup: "trash-popup", label: dgettext("landing", "Trash"), icon_fn: :icon_trash}
    ]
  end

  @doc "README.txt and the Trash, closed."
  @spec desktop_file_popups(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_file_popups(assigns) do
    assigns = assign(assigns, files: Map.new(files(), &{&1.popup, &1}))

    ~H"""
    <.file_popup
      file={@files["readme-popup"]}
      title={dgettext("landing", "README.txt — Notepad")}
      class="max-w-lg"
      status={dgettext("landing", "Ln 1, Col 1")}
    >
      <.readme_text />
    </.file_popup>

    <.file_popup
      file={@files["trash-popup"]}
      title={dgettext("landing", "Trash")}
      class="max-w-sm"
      status={dgettext("landing", "0 object(s)")}
    >
      <p class="text-sm">
        {dgettext("landing", "No trash here.")}<br /> {dgettext("landing", "Just clean code. ✨")}
      </p>
    </.file_popup>
    """
  end

  attr :file, :map, required: true, doc: "one of `files/0`"
  attr :title, :string, required: true
  attr :class, :string, required: true, doc: "the popup's width"
  attr :status, :string, required: true
  slot :inner_block, required: true

  defp file_popup(assigns) do
    ~H"""
    <div
      id={@file.popup}
      hidden
      class="fixed inset-0 z-modal flex items-center justify-center bg-overlay-bg"
      data-modal
      aria-hidden="true"
    >
      <div class={["w-full mx-4", @class]} data-modal-panel>
        <.window>
          <.window_title_bar title={@title} controls={[:close]} close_target={"#" <> @file.popup}>
            <:icon>{apply(Icons, @file.icon_fn, [%{class: "w-4 h-4"}])}</:icon>
          </.window_title_bar>
          <.window_body>{render_slot(@inner_block)}</.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>{@status}</.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </div>
    </div>
    """
  end
end
