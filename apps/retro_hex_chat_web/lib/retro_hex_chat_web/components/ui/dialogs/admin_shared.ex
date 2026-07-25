defmodule RetroHexChatWeb.Components.UI.AdminShared do
  @moduledoc """
  Presentation shared by every admin window.

  The admin surfaces are separate windows over one visual language: each runs a
  privileged command and reports the outcome in the same black inline strip.
  `inline_result/1` is that strip; `present?/1` is the blank-string guard the
  read-only panes use before falling back to an empty state.
  """
  use RetroHexChatWeb.Component

  @doc """
  Outcome strip for a privileged command — green on success, red on error.

  Renders nothing while `result` is nil, so a window that has not run a command
  yet shows no strip at all.
  """
  attr :result, :any, default: nil

  @spec inline_result(map()) :: Phoenix.LiveView.Rendered.t()
  def inline_result(assigns) do
    ~H"""
    <div
      :if={@result}
      class={[
        "shadow-retro-sunken bg-black font-mono text-xs p-retro-6",
        if(Map.get(@result, :status) == :error, do: "text-red-400", else: "text-green-400")
      ]}
      data-testid="admin-inline-result"
    >
      {Map.get(@result, :message, "")}
    </div>
    """
  end

  @doc "Whether a value is a string with something other than whitespace in it."
  @spec present?(term()) :: boolean()
  def present?(value), do: is_binary(value) and String.trim(value) != ""
end
