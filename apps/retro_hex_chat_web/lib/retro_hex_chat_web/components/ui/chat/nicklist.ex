defmodule RetroHexChatWeb.Components.UI.Nicklist do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders a Win98-style user list container."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist(assigns) do
    ~H"""
    <div
      class={classes(["shadow-retro-field bg-white overflow-y-auto p-1", @class])}
      data-testid="nicklist"
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a user item in the nicklist."
  attr :nick, :string, required: true
  attr :status, :string, values: ~w(online offline away), default: "online"

  attr :role, :atom,
    values: [:operator, :voiced, :owner, :half_operator, :regular, :normal],
    default: :regular

  attr :nick_color, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nicklist_item(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_item(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex items-center gap-1.5 px-1 py-[1px] text-sm cursor-pointer select-none",
          "hover:bg-primary hover:text-white",
          @class
        ])
      }
      data-testid={"nicklist-item-#{@nick}"}
      data-role={role_name(@role)}
      {@rest}
    >
      <span class={["w-2 h-2 rounded-full flex-shrink-0 inline-block", status_color(@status)]} />
      <span class="w-4 h-4 flex-shrink-0 inline-flex items-center justify-center">
        {role_icon(assigns)}
      </span>
      <span class={["font-bold font-mono truncate", @nick_color || "text-text"]}>
        {@nick}
      </span>
    </div>
    """
  end

  defp status_color("online"), do: "bg-online"
  defp status_color("away"), do: "bg-away"
  defp status_color("offline"), do: "bg-offline"

  defp role_name(:normal), do: "regular"
  defp role_name(role) when is_atom(role), do: Atom.to_string(role)
  defp role_name("op"), do: "operator"
  defp role_name("voice"), do: "voiced"
  defp role_name("normal"), do: "regular"
  defp role_name(role) when is_binary(role), do: role

  defp role_icon(%{role: role} = assigns) when role in [:operator, :owner, :half_operator] do
    ~H'<Icons.icon_role_operator class="w-[16px] h-[16px]" />'
  end

  defp role_icon(%{role: :voiced} = assigns) do
    ~H'<Icons.icon_role_voiced class="w-[16px] h-[16px]" />'
  end

  defp role_icon(assigns) do
    ~H'<Icons.icon_role_regular class="w-[16px] h-[16px]" />'
  end
end
