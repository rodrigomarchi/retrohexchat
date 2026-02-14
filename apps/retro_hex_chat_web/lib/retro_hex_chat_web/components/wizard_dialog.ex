defmodule RetroHexChatWeb.Components.WizardDialog do
  @moduledoc """
  3-step Windows 98-style onboarding wizard dialog.
  Steps: welcome (nickname) → server (connection) → channels (selection).
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :step, :atom, values: [:welcome, :server, :channels]
  attr :nickname, :string, default: ""
  attr :nickname_error, :string, default: nil
  attr :server, :string, default: "irc.retro.chat"
  attr :port, :integer, default: 6697
  attr :ssl, :boolean, default: true
  attr :connecting, :boolean, default: false
  attr :connect_error, :string, default: nil
  attr :channels, :list, default: []
  attr :selected_channels, :list, default: []
  attr :custom_channel, :string, default: ""

  @spec wizard_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def wizard_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="wizard-overlay"
      data-testid="wizard-overlay"
      phx-window-keydown="wizard_dismiss"
      phx-key="Escape"
    >
      <div class="window wizard-dialog" data-testid="wizard-dialog">
        <div class="title-bar">
          <div class="title-bar-text">Assistente de Configuração — RetroHexChat</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="wizard_dismiss"></button>
          </div>
        </div>
        <div class="window-body">
          <div class="wizard-content">
            <div class="wizard-step-indicator" data-testid="wizard-step-indicator">
              {step_label(@step)}
            </div>

            {render_step(assigns)}
          </div>
          <div class="wizard-button-bar">
            {render_buttons(assigns)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @spec render_step(map()) :: Phoenix.LiveView.Rendered.t()
  defp render_step(%{step: :welcome} = assigns) do
    ~H"""
    <div class="wizard-logo" data-testid="wizard-logo">
      ╔══════════════════════════╗
      ║   RetroHexChat  v1.0    ║
      ║  ┌──────────────────┐   ║
      ║  │  &gt; Bem-vindo! _  │   ║
      ║  └──────────────────┘   ║
      ╚══════════════════════════╝
    </div>
    <fieldset>
      <legend>Escolha seu nickname</legend>
      <label for="wizard-nickname">Nickname:</label>
      <input
        type="text"
        id="wizard-nickname"
        name="nickname"
        value={@nickname}
        maxlength="16"
        autofocus
        autocomplete="off"
        phx-change="wizard_validate_nickname"
        phx-debounce="300"
        data-testid="wizard-nickname-input"
      />
      <p :if={@nickname_error} class="wizard-error" data-testid="wizard-nickname-error">
        {@nickname_error}
      </p>
    </fieldset>
    <p class="wizard-tip">
      Seu nick é como seu nome no chat. Pode mudar depois com /nick
    </p>
    """
  end

  defp render_step(%{step: :server} = assigns) do
    ~H"""
    <fieldset>
      <legend>Configuração do Servidor</legend>
      <label for="wizard-server">Servidor:</label>
      <input
        type="text"
        id="wizard-server"
        name="server"
        value={@server}
        autocomplete="off"
        data-testid="wizard-server-input"
      />
      <label for="wizard-port">Porta:</label>
      <input
        type="number"
        id="wizard-port"
        name="port"
        value={@port}
        data-testid="wizard-port-input"
      />
      <label>
        <input
          type="checkbox"
          name="ssl"
          checked={@ssl}
          data-testid="wizard-ssl-checkbox"
        /> Usar SSL/TLS
      </label>
    </fieldset>
    <p :if={@connect_error} class="wizard-error" data-testid="wizard-connect-error">
      {@connect_error}
    </p>
    <p class="wizard-tip">
      Não sabe o que escolher? Deixe o padrão!
    </p>
    """
  end

  defp render_step(%{step: :channels} = assigns) do
    ~H"""
    <fieldset>
      <legend>Escolha canais para entrar</legend>
      <div :if={@channels != []} class="wizard-channel-list" data-testid="wizard-channel-list">
        <label :for={{name, count} <- @channels}>
          <input
            type="checkbox"
            phx-click="wizard_toggle_channel"
            phx-value-channel={name}
            checked={name in @selected_channels}
          />
          {name}
          <span class="wizard-channel-count">({count})</span>
        </label>
      </div>
      <p :if={@channels == []} class="wizard-tip">
        Nenhum canal disponível no momento.
      </p>
      <label for="wizard-custom-channel">Ou digite um canal:</label>
      <input
        type="text"
        id="wizard-custom-channel"
        name="channel"
        value={@custom_channel}
        placeholder="#canal"
        autocomplete="off"
        phx-change="wizard_update_custom_channel"
        phx-debounce="300"
        data-testid="wizard-custom-channel-input"
      />
    </fieldset>
    """
  end

  @spec render_buttons(map()) :: Phoenix.LiveView.Rendered.t()
  defp render_buttons(%{step: :welcome} = assigns) do
    ~H"""
    <button phx-click="wizard_dismiss" data-testid="wizard-cancel-btn">Cancelar</button>
    <button
      phx-click="wizard_next"
      phx-value-step="welcome"
      disabled={@nickname == "" or @nickname_error != nil}
      data-testid="wizard-next-btn"
    >
      Próximo &gt;
    </button>
    """
  end

  defp render_buttons(%{step: :server} = assigns) do
    ~H"""
    <button phx-click="wizard_back" phx-value-step="server" data-testid="wizard-back-btn">
      &lt; Voltar
    </button>
    <button phx-click="wizard_dismiss" data-testid="wizard-cancel-btn">Cancelar</button>
    <button
      phx-click="wizard_next"
      phx-value-step="server"
      disabled={@connecting}
      data-testid="wizard-connect-btn"
    >
      {if @connecting, do: "Conectando...", else: "Conectar"}
    </button>
    """
  end

  defp render_buttons(%{step: :channels} = assigns) do
    ~H"""
    <button phx-click="wizard_back" phx-value-step="channels" data-testid="wizard-back-btn">
      &lt; Voltar
    </button>
    <button phx-click="wizard_skip" data-testid="wizard-skip-btn">Pular</button>
    <button phx-click="wizard_complete" data-testid="wizard-enter-btn">
      Entrar!
    </button>
    """
  end

  @spec step_label(atom()) :: String.t()
  defp step_label(:welcome), do: "Passo 1 de 3"
  defp step_label(:server), do: "Passo 2 de 3"
  defp step_label(:channels), do: "Passo 3 de 3"
end
