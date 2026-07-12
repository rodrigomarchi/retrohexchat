defmodule RetroHexChatWeb.Components.UI.GroupCall.DeviceSelect do
  @moduledoc """
  Native device selector used by the channel conference pre-join flow.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :name, :string, required: true
  attr :value, :string, default: nil
  attr :kind, :string, required: true
  attr :devices, :list, default: []
  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :testid, :string, required: true

  @spec device_select(map()) :: Phoenix.LiveView.Rendered.t()
  def device_select(assigns) do
    ~H"""
    <label class="grid gap-1">
      <span class="inline-flex min-w-0 items-center gap-1 font-bold">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </span>
      <select
        name={@name}
        class="h-7 w-full bg-white px-1 text-xs shadow-retro-sunken focus:outline focus:outline-1 focus:outline-foreground"
        data-group-call-prejoin-device-select={@kind}
        data-testid={@testid}
      >
        <option value="" selected={blank?(@value)}>{dgettext("group_call", "System default")}</option>
        <option
          :for={device <- @devices}
          value={device["id"]}
          selected={device["id"] == @value}
        >
          {device["label"]}
        </option>
      </select>
    </label>
    """
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false
end
