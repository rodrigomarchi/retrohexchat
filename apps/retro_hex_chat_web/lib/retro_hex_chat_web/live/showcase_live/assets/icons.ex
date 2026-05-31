defmodule RetroHexChatWeb.ShowcaseLive.Assets.Icons do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ShowcaseHelpers

  @submodules [
    {RetroHexChatWeb.Icons.People, dgettext("showcase", "People"),
     dgettext("showcase", "Users, contacts, social")},
    {RetroHexChatWeb.Icons.Communication, dgettext("showcase", "Communication"),
     dgettext("showcase", "Chat, channels, networking")},
    {RetroHexChatWeb.Icons.Media, dgettext("showcase", "Media"),
     dgettext("showcase", "Audio, video, devices")},
    {RetroHexChatWeb.Icons.Files, dgettext("showcase", "Files"),
     dgettext("showcase", "Documents, folders, clipboard")},
    {RetroHexChatWeb.Icons.Hardware, dgettext("showcase", "Hardware"),
     dgettext("showcase", "Servers, databases, platforms")},
    {RetroHexChatWeb.Icons.Code, dgettext("showcase", "Code"),
     dgettext("showcase", "Terminal, scripting, automation")},
    {RetroHexChatWeb.Icons.Security, dgettext("showcase", "Security"),
     dgettext("showcase", "Locks, shields, bans")},
    {RetroHexChatWeb.Icons.Arrows, dgettext("showcase", "Arrows"),
     dgettext("showcase", "Directional, navigation")},
    {RetroHexChatWeb.Icons.Marks, dgettext("showcase", "Marks"),
     dgettext("showcase", "Checkmarks, X marks, status")},
    {RetroHexChatWeb.Icons.Tools, dgettext("showcase", "Tools"),
     dgettext("showcase", "Settings, editing, search")},
    {RetroHexChatWeb.Icons.Alerts, dgettext("showcase", "Alerts"),
     dgettext("showcase", "Notifications, info, warnings")},
    {RetroHexChatWeb.Icons.Symbols, dgettext("showcase", "Symbols"),
     dgettext("showcase", "Currency, stars, misc")},
    {RetroHexChatWeb.Icons.Formatting, dgettext("showcase", "Formatting"),
     dgettext("showcase", "Text formatting (14x14)")},
    {RetroHexChatWeb.Icons.Games, dgettext("showcase", "Games"),
     dgettext("showcase", "P2P game icons (32x32)")}
  ]

  # Build a compile-time map of {module, function_name} => viewBox size
  # by parsing the source files of each icon submodule.
  @icon_sizes (for {mod, _, _} <- @submodules, reduce: %{} do
                 acc ->
                   source_path = mod.module_info(:compile)[:source] |> to_string()
                   source = File.read!(source_path)

                   sizes =
                     Regex.scan(
                       ~r/def (icon_\w+)\(.*?viewBox=dgettext("showcase", "0 0 (\d+) \d+")/s,
                       source
                     )
                     |> Enum.reduce(%{}, fn [_, name, size_str], inner ->
                       atom = String.to_existing_atom(name)

                       size =
                         cond do
                           String.starts_with?(name, "icon_dialog_") -> :small_dark
                           size_str == "32" -> :large
                           size_str == "14" -> :tiny
                           true -> :small
                         end

                       Map.put(inner, {mod, atom}, size)
                     end)

                   Map.merge(acc, sizes)
               end)

  @impl true
  def mount(_params, _session, socket) do
    groups = build_groups()

    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Icons"),
       active_page: "icons",
       groups: groups
     )}
  end

  defp build_groups do
    Enum.map(@submodules, fn {mod, title, description} ->
      icons =
        mod.__info__(:functions)
        |> Enum.filter(fn {name, arity} ->
          arity == 1 and String.starts_with?(to_string(name), "icon_")
        end)
        |> Enum.map(fn {name, _} -> {name, Map.get(@icon_sizes, {mod, name}, :small)} end)
        |> Enum.sort_by(fn {name, _} -> to_string(name) end)

      {mod, title, description, icons}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Icons")}</h2>
      <p class="text-xs text-muted-foreground mb-4">
        {dgettext("showcase", "Auto-discovered from submodules. New icons appear here automatically.")}
      </p>

      <.icon_group
        :for={{mod, title, description, icons} <- @groups}
        mod={mod}
        title={title}
        description={description}
        icons={icons}
      />
    </.showcase_layout>
    """
  end

  attr :mod, :atom, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icons, :list, required: true

  defp icon_group(assigns) do
    ~H"""
    <.showcase_card
      title={@title <> " (" <> to_string(length(@icons)) <> ")"}
      description={@description}
    >
      <div class="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-2">
        <.icon_cell :for={{name, size} <- @icons} mod={@mod} name={name} size={size} />
      </div>
    </.showcase_card>
    """
  end

  attr :mod, :atom, required: true
  attr :name, :atom, required: true
  attr :size, :atom, required: true

  defp icon_cell(assigns) do
    # Render icons at their exact native pixel size — never resize.
    # Use Tailwind arbitrary-value classes matching the SVG viewBox.
    assigns =
      assign(
        assigns,
        :rendered,
        apply(assigns.mod, assigns.name, [%{class: icon_native_class(assigns.size)}])
      )

    ~H"""
    <div class="flex flex-col items-center gap-1 overflow-hidden" title={to_string(@name)}>
      <div class={[
        "flex items-center justify-center shadow-retro-sunken",
        container_dim(@size),
        bg_class(@size)
      ]}>
        {@rendered}
      </div>
      <span class="text-[9px] text-muted-foreground text-center w-full truncate leading-tight">
        {format_name(@name)}
      </span>
      <span class="text-[8px] text-muted-foreground/60">{size_label(@size)}</span>
    </div>
    """
  end

  defp bg_class(:small_dark),
    do: dgettext("showcase", "bg-gradient-to-r from-primary to-[#1084d0]")

  defp bg_class(_), do: "bg-surface"

  # Native pixel size classes — icons must not be resized
  defp icon_native_class(:large), do: "block w-[32px] h-[32px]"
  defp icon_native_class(:small), do: "block w-[16px] h-[16px]"
  defp icon_native_class(:small_dark), do: "block w-[16px] h-[16px]"
  defp icon_native_class(:tiny), do: "block w-[14px] h-[14px]"

  # Container just big enough to hold the icon with some padding
  defp container_dim(:large), do: "w-10 h-10"
  defp container_dim(:small), do: "w-7 h-7"
  defp container_dim(:small_dark), do: "w-7 h-7"
  defp container_dim(:tiny), do: "w-6 h-6"

  defp format_name(name) do
    name
    |> to_string()
    |> String.replace_prefix("icon_", "")
    |> String.replace("_", " ")
  end

  defp size_label(:large), do: "32×32"
  defp size_label(:small), do: "16×16"
  defp size_label(:small_dark), do: "16×16"
  defp size_label(:tiny), do: "14×14"
end
