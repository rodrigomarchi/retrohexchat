defmodule RetroHexChatWeb.Components.HistorySearch do
  @moduledoc """
  Inline history search bar component (Ctrl+R reverse search).

  Rendered inside the chat-input-area, hidden by default.
  Toggled by JS when Ctrl+R is pressed.
  """

  use Phoenix.Component

  @doc "Renders the history search bar, hidden by default."
  @spec history_search(map()) :: Phoenix.LiveView.Rendered.t()
  def history_search(assigns) do
    ~H"""
    <div id="hist-search-panel" class="hist-search-panel" style="display: none;">
      <label class="history-search-label">Pesquisar histórico:</label>
      <input type="text" class="history-search-input" autocomplete="off" />
      <span class="history-no-match" style="display: none;">Sem resultados</span>
    </div>
    """
  end
end
