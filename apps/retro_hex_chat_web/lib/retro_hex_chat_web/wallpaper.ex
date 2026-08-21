defmodule RetroHexChatWeb.Wallpaper do
  @moduledoc """
  The art painted on the desktop behind every window.

  One image per shape of screen — a wide one for a desk, a tall one for a phone
  — served to `Components.UI.Desktop.desktop/1`, which is the single workspace
  every surface of the app is built on. The choice between the two is made in
  `window-manager.css` at the same width the window manager itself switches to
  its stacked layout, so the desk and its backdrop never disagree about which
  kind of screen this is.

  Both URLs carry a content hash, which is why they reach CSS as custom
  properties set on the workspace element rather than from the stylesheet: a
  cached stylesheet cannot spell a hash that changes with the next build.

  WebP, and only WebP. The art is a halftone-dithered gradient: PNG cannot
  compress that texture below 700 KB, and AVIF does worse than WebP on it.
  A browser too old for WebP is left with the teal underneath, which is the
  colour the desktop wore before there was a picture on it.

  Filenames separate their words with `_`, not `-`. `priv/static`'s ignore rule
  for digest artefacts (`*-[0-9a-f]*.*`) reads the `d` of `-desktop` as a hex
  digit, so a hyphenated name is silently untracked by git — present locally,
  missing in the release.
  """

  alias RetroHexChatWeb.Endpoint

  @desktop_path "/images/desktop/wallpaper_desktop.webp"
  @mobile_path "/images/desktop/wallpaper_mobile.webp"

  @doc """
  The digested URL of the wide wallpaper, for a desk-sized screen.
  """
  @spec desktop_url() :: String.t()
  def desktop_url, do: Endpoint.static_path(@desktop_path)

  @doc """
  The digested URL of the tall wallpaper, for a phone-sized screen.
  """
  @spec mobile_url() :: String.t()
  def mobile_url, do: Endpoint.static_path(@mobile_path)
end
