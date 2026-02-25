defmodule RetroHexChatWeb.IconsLive do
  use RetroHexChatWeb, :live_view
  import RetroHexChatWeb.Components.Window

  def mount(_params, _session, socket) do
    all_exports = RetroHexChatWeb.Icons.__info__(:functions)
    
    icons_by_name = 
      all_exports
      |> Enum.filter(fn {name, arity} -> arity == 1 and String.starts_with?(to_string(name), "icon_") end)
      |> Enum.map(fn {name, _} -> name end)
      |> Enum.sort()
      
    groups = Enum.group_by(icons_by_name, fn name -> 
      str_name = to_string(name)
      cond do
        String.starts_with?(str_name, "icon_btn_") -> "Buttons & Utilities (16x16)"
        String.starts_with?(str_name, "icon_dialog_") -> "Dialog Titlebars (16x16 Dark)"
        String.starts_with?(str_name, "icon_tab_") -> "Tabs (16x16)"
        String.starts_with?(str_name, "icon_group_") -> "Settings Groups (32x32)"
        String.starts_with?(str_name, "icon_role_") -> "User Roles (16x16)"
        String.starts_with?(str_name, "icon_quality_") -> "A/V Quality (16x16)"
        String.starts_with?(str_name, "icon_status_") -> "User Status (16x16)"
        str_name in ["icon_lightbulb"] -> "Misc (16x16)"
        true -> "General & Desktop (32x32)"
      end
    end)

    # Convert to a list of {title, [{str_name, func, size}]}
    formatted_groups = 
      Enum.map(groups, fn {group_title, icon_atoms} ->
        icon_data = Enum.map(icon_atoms, fn atom_name ->
          str_name = to_string(atom_name)
          
          # Heuristic for size/bg class
          size = 
            cond do
              String.contains?(group_title, "Dark") -> "16x16 darkbg"
              String.contains?(group_title, "16x16") -> "16x16"
              true -> "32x32"
            end
            
          # The function reference we can call in the template
          func = Function.capture(RetroHexChatWeb.Icons, atom_name, 1)
          
          {str_name, func, size}
        end)
        
        {group_title, icon_data}
      end)
      
    # Sort groups so General is first
    sorted_groups = Enum.sort_by(formatted_groups, fn {title, _} -> 
      if String.starts_with?(title, "General"), do: "0", else: title 
    end)

    {:ok, assign(socket, groups: sorted_groups)}
  end

  def render(assigns) do
    ~H"""
    <div style="height: 100vh; width: 100vw; overflow-y: auto; background-color: #008080; padding: 20px; font-family: Tahoma, sans-serif; display: flex; flex-wrap: wrap; gap: 20px; align-items: flex-start; align-content: flex-start; box-sizing: border-box;">
      
      <.icon_window :for={{group_title, icons} <- @groups} title={group_title} icons={icons} />

    </div>
    """
  end

  def icon_window(assigns) do
    ~H"""
    <.window title={@title} style="flex: 0 0 auto; min-width: 250px; max-width: 500px; margin: 0; margin-bottom: 20px;">
      <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px; background-color: #C0C0C0; padding: 8px; box-sizing: border-box;">
        <div :for={{name, component, size} <- @icons} style="display: flex; flex-direction: column; align-items: center; gap: 4px; overflow: hidden; width: 100%;">
          <div style={
            "display: flex; align-items: center; justify-content: center; padding: 2px; width: 36px; height: 36px; box-shadow: inset -1px -1px #fff, inset 1px 1px #808080; box-sizing: border-box; " <>
            if(String.contains?(size, "darkbg"), do: "background: linear-gradient(to right, #000080, #1084d0);", else: "background-color: #C0C0C0;")
          }>
            <div style={if String.contains?(size, "32x32"), do: "width: 32px; height: 32px;", else: "width: 16px; height: 16px;"}>
              {component.(%{class: "w-full h-full block"})}
            </div>
          </div>
          <div style="font-size: 10px; color: black; text-align: center; width: 100%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.2;" title={name}>{name}</div>
        </div>
      </div>
    </.window>
    """
  end
end
