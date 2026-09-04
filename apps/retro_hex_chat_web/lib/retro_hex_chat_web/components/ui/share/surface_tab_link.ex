defmodule RetroHexChatWeb.Components.UI.SurfaceTabLink do
  @moduledoc """
  The way back from a surface to the chat.

  There used to be a matching way *forward* here — an anchor from the chat into
  a surface's own tab — and it was a second door into a room whose first door is
  the card in the conversation. A room entered through it was a room the
  conversation was never told about, so it is gone: the card is the only way in
  now, and this is only the way out.

  It stays an anchor with the real address, which is what keeps middle-click,
  "open in new tab" and the browser's own status bar working, and what makes
  the fallback free: when no tab answers the focus request, the next click
  simply follows the link.

  `rel="noopener"` is not a style choice. Without it the new tab shares this
  one's event loop and the whole point of a separate address is worth nothing —
  measured at 1203 ms against 12 ms.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.App.Paths

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
end
