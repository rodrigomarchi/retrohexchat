defmodule RetroHexChatWeb.HelpLive.Index do
  @moduledoc """
  Help system LiveView at `/chat/help` and `/chat/help/:topic`.

  Topic navigation uses LiveView navigate for instant client-side
  switching without full page reloads.
  """
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.HelpLive.HelpHelpers

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Icons

  @default_topic "welcome"

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, topics_by_category: HelpTopics.topics_by_category())}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    selected_topic = resolve_topic(params)

    canonical_url =
      if selected_topic, do: "/chat/help/#{selected_topic.id}", else: "/chat/help"

    {:noreply,
     socket
     |> assign(:selected_topic, selected_topic)
     |> assign(:page_title, page_title(selected_topic))
     |> assign(:page_description, page_description(selected_topic))
     |> assign(:canonical_url, canonical_url)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.help_layout topics_by_category={@topics_by_category} selected_topic={@selected_topic}>
      <div :if={@selected_topic}>
        <div class="flex items-center gap-2 mb-3 pb-2 border-b border-gray-300">
          <.help_icon name={@selected_topic.icon} class="w-6 h-6 flex-shrink-0" />
          <div>
            <h1 class="text-base font-bold text-text">{@selected_topic.title}</h1>
            <nav aria-label="Breadcrumb" class="text-xs text-muted-foreground">
              <.link navigate={~p"/chat/help"} class="hover:underline text-link">Help</.link>
              {" > "}{@selected_topic.category}{" > "}{@selected_topic.title}
            </nav>
          </div>
        </div>

        <article class={[
          "text-sm leading-relaxed space-y-2",
          "[&_p]:my-1.5",
          "[&_pre]:bg-gray-100 [&_pre]:border [&_pre]:border-gray-300 [&_pre]:p-2 [&_pre]:text-xs [&_pre]:overflow-x-auto [&_pre]:my-2",
          "[&_code]:bg-gray-100 [&_code]:px-0.5 [&_code]:text-xs",
          "[&_ul]:list-disc [&_ul]:pl-5 [&_ul]:my-1",
          "[&_ol]:list-decimal [&_ol]:pl-5 [&_ol]:my-1",
          "[&_li]:my-0.5",
          "[&_table]:w-full [&_table]:border-collapse [&_table]:text-xs [&_table]:my-2",
          "[&_th]:border [&_th]:border-gray-300 [&_th]:bg-gray-50 [&_th]:px-2 [&_th]:py-1 [&_th]:text-left [&_th]:font-bold",
          "[&_td]:border [&_td]:border-gray-300 [&_td]:px-2 [&_td]:py-1"
        ]}>
          <.render_topic_content id={@selected_topic.id} />
        </article>
      </div>

      <div :if={!@selected_topic} class="text-center py-12 text-muted-foreground">
        <Icons.icon_notepad class="w-8 h-8 mx-auto mb-3 opacity-50" />
        <h1 class="text-base font-bold mb-2 text-text">RetroHexChat Help</h1>
        <p class="text-sm">Select a topic from the navigation pane to get started.</p>
        <p class="text-xs mt-1">Browse by category or use F1 inside the chat.</p>
      </div>
    </.help_layout>
    """
  end

  # ── Private ────────────────────────────────────────────────

  @spec resolve_topic(map()) :: map() | nil
  defp resolve_topic(%{"topic" => topic_id}) do
    HelpTopics.get_topic(topic_id) || HelpTopics.get_topic(@default_topic)
  end

  defp resolve_topic(_params), do: HelpTopics.get_topic(@default_topic)

  @spec page_title(map() | nil) :: String.t()
  defp page_title(nil), do: "Help — RetroHexChat"
  defp page_title(topic), do: "#{topic.title} — RetroHexChat Help"

  @spec page_description(map() | nil) :: String.t()
  defp page_description(nil) do
    "RetroHexChat help documentation. Learn about IRC commands, " <>
      "channel modes, features, and keyboard shortcuts."
  end

  defp page_description(topic), do: topic.description
end
