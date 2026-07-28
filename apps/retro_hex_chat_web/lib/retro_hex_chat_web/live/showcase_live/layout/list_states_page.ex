defmodule RetroHexChatWeb.ShowcaseLive.Layout.ListStatesPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: dgettext("showcase", "List States"), active_page: "list-states")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Paginated List States")}</h2>

      <p class="text-xs text-muted-foreground mb-4">
        {dgettext(
          "showcase",
          "A list is not only its rows. Every paginated list in the app draws its empty, exhausted, truncated, failed and first-load states from these components."
        )}
      </p>

      <.showcase_card
        title={dgettext("showcase", "Empty State")}
        description="Shown in place of the rows. Pass text only when the reader can act on it."
      >
        <div class="shadow-retro-field bg-white">
          <.list_empty_state
            title={dgettext("showcase", "No channels found")}
            text={dgettext("showcase", "Try a different filter.")}
            icon={:channels}
          />
        </div>
        <.code_example>
          &lt;.list_empty_state title="No channels found" text="Try a different filter."
          icon=&#123;:channels&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "End Marker")}
        description="Closes a paginated list. Without it, the end is indistinguishable from a load that never finished."
      >
        <div class="shadow-retro-field bg-white">
          <.list_end_marker />
        </div>
        <.code_example>&lt;.list_end_marker /&gt;</.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Load More")}
        description="The keyboard path to pagination. Kept alongside scroll loading, never instead of it."
      >
        <div class="shadow-retro-field bg-white">
          <.list_load_more_button target={nil} />
          <.list_load_more_button target={nil} loading={true} />
        </div>
        <.code_example>
          &lt;.list_load_more_button target=&#123;@myself&#125; loading=&#123;@loading&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Count Strip")}
        description="Discloses truncation. Renders nothing when the whole list is on screen, so it reads as a warning rather than furniture."
      >
        <div class="shadow-retro-field bg-white">
          <.list_count_strip shown={100} total={5000} />
        </div>
        <.code_example>
          &lt;.list_count_strip shown=&#123;100&#125; total=&#123;@page.total&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Error & Retry")}
        description="The one list state announced assertively — a failed page must not be scrolled past unnoticed."
      >
        <div class="shadow-retro-field bg-white">
          <.list_error_retry on_retry="noop" target={nil} />
        </div>
        <.code_example>
          &lt;.list_error_retry on_retry="reload_bans" target=&#123;@myself&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "First-load Skeleton")}
        description="Reserves the space the rows will occupy, so the panel does not jump when they land."
      >
        <div class="shadow-retro-field bg-white">
          <.list_skeleton rows={5} />
        </div>
        <.code_example>&lt;.list_skeleton rows=&#123;5&#125; /&gt;</.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Announcer")}
        description="A visually hidden live region that reports what arrived — not merely that loading happened. Nothing to see here by design."
      >
        <div class="shadow-retro-field bg-white p-2 text-xs text-muted-foreground">
          {dgettext("showcase", "(screen-reader only)")}
          <.list_announcer message={dgettext("showcase", "20 items loaded")} />
        </div>
        <.code_example>&lt;.list_announcer message=&#123;@announcement&#125; /&gt;</.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
