defmodule RetroHexChatWeb.Components.UI.SurfaceTabLink do
  @moduledoc """
  The way from the chat to a surface's own tab, in the two shapes it has.

  Three screens drew this by hand — the call badge, the space picker and the
  P2P starting room — and all three drew the same anchor with the same
  `noopener` and the same three-word label. That was fine while there was only
  one shape. There are two now: a surface you do **not** have open is *opened*,
  and one you **do** is *gone back to*, and the difference is not decoration.
  Opening a second tab of a session you already have would move the session into
  it, which is the takeover contract firing for somebody who only wanted to look
  at what they already had.

  It stays an anchor in both shapes, always with the real address. That is what
  keeps middle-click, "open in new tab" and the browser's own status bar
  working, and it is what makes the fallback free: when no tab answers the focus
  request, the next click simply follows the link.

  `rel="noopener"` is not a style choice. Without it the new tab shares this
  one's event loop and the whole point of a separate address is worth nothing —
  measured at 1203 ms against 12 ms.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  attr :path, :string, required: true, doc: "the surface's own address"

  attr :open?, :boolean,
    default: false,
    doc: "whether this person already has that address open somewhere"

  attr :label, :string, default: nil, doc: "overrides the open label"
  attr :testid, :string, default: nil
  attr :class, :any, default: nil

  @spec surface_tab_link(map()) :: Phoenix.LiveView.Rendered.t()
  def surface_tab_link(assigns) do
    ~H"""
    <div class="contents">
      <.link
        href={@path}
        target="_blank"
        rel="noopener"
        id={@open? && "surface-tab-link-#{Base.url_encode64(@path, padding: false)}"}
        phx-hook={@open? && "SurfaceTabLinkHook"}
        data-surface-path={@path}
        class={
          classes([
            "shadow-retro-raised bg-surface flex h-[26px] shrink-0 items-center justify-center gap-1 px-3 text-sm focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
            @class
          ])
        }
        data-testid={@testid}
        data-surface-open={to_string(@open?)}
      >
        <Icons.icon_btn_link class="h-3.5 w-3.5" />
        <span>{label(@open?, @label)}</span>
      </.link>
      <%!-- Only ever shown by the hook, and only after a tab failed to come
            forward: the honest sentence for a window that exists somewhere the
            browser will not let us reach.

            `phx-update="ignore"` because the hook writes `data-visible` and the
            server does not know it did. Without it the next patch of this
            subtree — and the open set changes often enough to cause one —
            restores the server's `false` and the sentence disappears again,
            which is the silence this element exists to end. --%>
      <p
        :if={@open?}
        id={"surface-tab-note-#{Base.url_encode64(@path, padding: false)}"}
        phx-update="ignore"
        class="surface-tab-note text-muted-foreground text-xs"
        data-surface-tab-note
        data-visible="false"
        data-testid={@testid && "#{@testid}-note"}
      >
        {dgettext("share", "It is already open in another window of yours.")}
      </p>
    </div>
    """
  end

  attr :open?, :boolean,
    default: false,
    doc: "whether the chat is one of this person's open tabs"

  attr :testid, :string, required: true

  @doc """
  The way back, which is a way *back* only when the chat is still open.

  Every surface has had this link since wave 0, and until now it always
  navigated: somebody who came from the chat got a second chat, and the first
  one — the one holding their channels, their conversations and their scroll
  position — was taken over by it. The address is the same in both cases; what
  changes is whether the click tries the tab that exists first.

  A plain `navigate` when nothing is open, because then there is nothing to go
  back to and opening the chat is exactly right.
  """
  @spec back_to_chat(map()) :: Phoenix.LiveView.Rendered.t()
  def back_to_chat(assigns) do
    ~H"""
    <%!-- `contents` so the status bar lays this out as if the wrapper were not
          here. The wrapper exists for the note: the hook finds it through the
          link's own parent, so a link with no parent of its own is a link whose
          refusal has nowhere to be said. --%>
    <div :if={@open?} class="contents">
      <.link
        href={Paths.chat_path()}
        id="surface-back-to-chat"
        phx-hook="SurfaceTabLinkHook"
        data-surface-path={Paths.chat_path()}
        data-testid={@testid}
      >
        ← {dgettext("share", "Chat")}
      </.link>
      <%!-- Shown only by the hook, and only once a tab has failed to come
            forward. Without it the first click is silent and the second one
            opens a second chat — which is the takeover this link exists to
            avoid, arriving one click later than it used to.

            `phx-update="ignore"` for the same reason as its sibling above: the
            hook writes `data-visible`, the server never learns it, and a patch
            would put the sentence away again. --%>
      <p
        id="surface-back-to-chat-note"
        phx-update="ignore"
        class="surface-tab-note text-muted-foreground text-xs"
        data-surface-tab-note
        data-visible="false"
        data-testid={@testid && "#{@testid}-note"}
      >
        {dgettext("share", "It is already open in another window of yours.")}
      </p>
    </div>
    <.link :if={!@open?} navigate={Paths.chat_path()} data-testid={@testid}>
      ← {dgettext("share", "Chat")}
    </.link>
    """
  end

  defp label(false, nil), do: dgettext("share", "Open in a tab")
  defp label(false, label), do: label
  defp label(true, _label), do: dgettext("share", "Go to the tab")
end
