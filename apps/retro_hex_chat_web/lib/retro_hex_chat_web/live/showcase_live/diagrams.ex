defmodule RetroHexChatWeb.ShowcaseLive.Diagrams do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ShowcaseHelpers

  @submodules [
    {RetroHexChatWeb.Components.Diagrams.P2P, "P2P", "Flow and architecture diagrams"},
    {RetroHexChatWeb.Components.Diagrams.Security, "Security",
     "Encryption layers and protocol diagrams"},
    {RetroHexChatWeb.Components.Diagrams.Voice, "Voice", "Voice/video call mockups"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    groups = build_groups()
    {:ok, assign(socket, page_title: "Diagrams", active_page: "diagrams", groups: groups)}
  end

  defp build_groups do
    Enum.map(@submodules, fn {mod, title, description} ->
      diagrams =
        mod.__info__(:functions)
        |> Enum.filter(fn {name, arity} ->
          arity == 1 and String.starts_with?(to_string(name), "diagram_")
        end)
        |> Enum.map(fn {name, _} -> name end)
        |> Enum.sort_by(&to_string/1)

      {mod, title, description, diagrams}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Diagrams</h2>
      <p class="text-xs text-muted-foreground mb-4">
        Auto-discovered from submodules. Each diagram gets its own window.
      </p>

      <div :for={{mod, _title, _description, diagrams} <- @groups}>
        <.diagram_window :for={name <- diagrams} mod={mod} name={name} />
      </div>
    </.showcase_layout>
    """
  end

  attr :mod, :atom, required: true
  attr :name, :atom, required: true

  defp diagram_window(assigns) do
    assigns =
      assign(
        assigns,
        :rendered,
        apply(assigns.mod, assigns.name, [%{class: "w-full h-auto"}])
      )

    ~H"""
    <.showcase_card title={format_name(@name)} description={to_string(@mod)}>
      <div class="flex justify-center">
        {@rendered}
      </div>
      <.code_example>
        &lt;{format_component_tag(@name)} /&gt;
      </.code_example>
    </.showcase_card>
    """
  end

  defp format_name(name) do
    name
    |> to_string()
    |> String.replace_prefix("diagram_", "")
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_component_tag(name) do
    "." <> to_string(name)
  end
end
