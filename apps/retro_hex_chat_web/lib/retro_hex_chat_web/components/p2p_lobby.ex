defmodule RetroHexChatWeb.Components.P2pLobby do
  @moduledoc """
  Function components for the P2P session lobby UI.
  """

  use Phoenix.Component

  attr :session, :map, required: true
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true
  attr :messages, :list, required: true
  attr :action_request, :map, default: nil
  attr :capabilities, :map, required: true
  attr :session_status, :string, required: true
  attr :inactivity_warning, :boolean, default: false
  attr :role, :atom, required: true
  attr :webrtc_state, :string, default: nil
  attr :retry_attempt, :integer, default: nil

  @spec p2p_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_lobby(assigns) do
    ~H"""
    <div class="p2p-lobby window">
      <div class="title-bar">
        <div class="title-bar-text">
          Sessao P2P — {@nickname} e {@peer_nick}
        </div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="close_session"></button>
        </div>
      </div>
      <div class="window-body p2p-lobby__body">
        <.p2p_inactivity_warning :if={@inactivity_warning} />
        <.p2p_connection_state
          :if={@webrtc_state}
          webrtc_state={@webrtc_state}
          retry_attempt={@retry_attempt}
        />

        <div :if={@session_status == "connecting" && !@webrtc_state} class="p2p-lobby__connecting">
          <p>Aguardando conexao...</p>
        </div>

        <div :if={@session_status != "connecting"} class="p2p-lobby__content">
          <.p2p_presence nickname={@nickname} peer_nick={@peer_nick} peer_online={@peer_online} />

          <.p2p_chat messages={@messages} nickname={@nickname} />

          <.p2p_actions
            capabilities={@capabilities}
            action_request={@action_request}
            nickname={@nickname}
            peer_nick={@peer_nick}
            session_status={@session_status}
          />
        </div>

        <div class="p2p-lobby__footer">
          <button class="p2p-lobby__close-btn" phx-click="close_session">
            Encerrar Sessao
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true

  defp p2p_presence(assigns) do
    ~H"""
    <div class="p2p-lobby-presence">
      <div class="p2p-lobby-presence__user p2p-lobby-presence__user--online">
        <span class="p2p-lobby-presence__indicator p2p-lobby-presence__indicator--online"></span>
        <span class="p2p-lobby-presence__nick">{@nickname}</span>
        <span class="p2p-lobby-presence__label">(voce)</span>
      </div>
      <div class={"p2p-lobby-presence__user #{if @peer_online, do: "p2p-lobby-presence__user--online", else: "p2p-lobby-presence__user--offline"}"}>
        <span class={"p2p-lobby-presence__indicator #{if @peer_online, do: "p2p-lobby-presence__indicator--online", else: "p2p-lobby-presence__indicator--offline"}"}>
        </span>
        <span class="p2p-lobby-presence__nick">{@peer_nick}</span>
        <span :if={!@peer_online} class="p2p-lobby-presence__label">(aguardando)</span>
      </div>
    </div>
    """
  end

  attr :messages, :list, required: true
  attr :nickname, :string, required: true

  defp p2p_chat(assigns) do
    ~H"""
    <div class="p2p-lobby-chat">
      <div class="p2p-lobby-chat__messages" id="p2p-chat-messages">
        <div
          :for={msg <- @messages}
          class={"p2p-lobby-chat__message #{if msg.type == "system", do: "p2p-lobby-chat__message--system"}"}
        >
          <span :if={msg.type != "system"} class="p2p-lobby-chat__nick">{msg.sender_nick}:</span>
          <span class="p2p-lobby-chat__content">{msg.content}</span>
        </div>
        <div :if={@messages == []} class="p2p-lobby-chat__empty">
          Nenhuma mensagem ainda. Diga oi!
        </div>
      </div>
      <form class="p2p-lobby-chat__form" phx-submit="send_lobby_message">
        <input
          type="text"
          name="content"
          placeholder="Digite uma mensagem..."
          autocomplete="off"
          class="p2p-lobby-chat__input"
        />
        <button type="submit" class="p2p-lobby-chat__send">Enviar</button>
      </form>
    </div>
    """
  end

  attr :capabilities, :map, required: true
  attr :action_request, :map, default: nil
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :session_status, :string, required: true

  defp p2p_actions(assigns) do
    ~H"""
    <div class="p2p-lobby-actions">
      <.p2p_consent_banner
        :if={
          @action_request && @action_request[:status] == "pending" &&
            @action_request[:requester_nick] != @nickname
        }
        action_request={@action_request}
        peer_nick={@peer_nick}
      />
      <.p2p_waiting_indicator
        :if={
          @action_request && @action_request[:status] == "pending" &&
            @action_request[:requester_nick] == @nickname
        }
        action_request={@action_request}
      />

      <div
        :if={!@action_request || @action_request[:status] != "pending"}
        class="p2p-lobby-actions__buttons"
      >
        <button
          phx-click="request_action"
          phx-value-action_type="file_transfer"
          disabled={!@capabilities[:dataChannel]}
          title={
            if !@capabilities[:dataChannel],
              do: "Navegador nao suporta transferencia de arquivos",
              else: "Enviar arquivo"
          }
          class="p2p-lobby-actions__btn"
        >
          Enviar Arquivo
        </button>
        <button
          phx-click="request_action"
          phx-value-action_type="audio_call"
          disabled={!@capabilities[:getUserMedia]}
          title={
            if !@capabilities[:getUserMedia],
              do: "Navegador nao suporta chamadas de audio",
              else: "Chamada de audio"
          }
          class="p2p-lobby-actions__btn"
        >
          Chamada de Audio
        </button>
        <button
          phx-click="request_action"
          phx-value-action_type="video_call"
          disabled={!@capabilities[:getUserMedia]}
          title={
            if !@capabilities[:getUserMedia],
              do: "Navegador nao suporta chamadas de video",
              else: "Chamada de video"
          }
          class="p2p-lobby-actions__btn"
        >
          Chamada de Video
        </button>
      </div>
    </div>
    """
  end

  defp p2p_consent_banner(assigns) do
    ~H"""
    <div class="p2p-lobby-consent">
      <p class="p2p-lobby-consent__text">
        {@action_request.requester_nick} quer iniciar: {action_label(@action_request.action_type)}
      </p>
      <div class="p2p-lobby-consent__buttons">
        <button
          phx-click="respond_action"
          phx-value-accepted="true"
          class="p2p-lobby-consent__btn p2p-lobby-consent__btn--accept"
        >
          Aceitar
        </button>
        <button
          phx-click="respond_action"
          phx-value-accepted="false"
          class="p2p-lobby-consent__btn p2p-lobby-consent__btn--reject"
        >
          Recusar
        </button>
      </div>
    </div>
    """
  end

  defp p2p_waiting_indicator(assigns) do
    ~H"""
    <div class="p2p-lobby-actions__waiting">
      <p>Aguardando resposta para: {action_label(@action_request.action_type)}...</p>
    </div>
    """
  end

  defp p2p_inactivity_warning(assigns) do
    ~H"""
    <div class="p2p-lobby__warning">
      <p>Sessao sera encerrada por inatividade em breve. Envie uma mensagem para manter ativa.</p>
    </div>
    """
  end

  attr :webrtc_state, :string, required: true
  attr :retry_attempt, :integer, default: nil

  defp p2p_connection_state(assigns) do
    ~H"""
    <div class={"p2p-lobby-connection #{connection_state_class(@webrtc_state)}"}>
      <span class="p2p-lobby-connection__indicator"></span>
      <span class="p2p-lobby-connection__label">
        {@webrtc_state}
        <span :if={@retry_attempt && String.contains?(@webrtc_state, "Reconectando")}>
          (tentativa {@retry_attempt}/3)
        </span>
      </span>
    </div>
    """
  end

  defp connection_state_class("Conectado"), do: "p2p-lobby-connection--connected"
  defp connection_state_class("Conectando..."), do: "p2p-lobby-connection--connecting"
  defp connection_state_class("Reconectando..."), do: "p2p-lobby-connection--retrying"
  defp connection_state_class("Falha na conexao"), do: "p2p-lobby-connection--failed"
  defp connection_state_class(_), do: ""

  defp action_label("audio_call"), do: "Chamada de Audio"
  defp action_label("video_call"), do: "Chamada de Video"
  defp action_label("file_transfer"), do: "Transferencia de Arquivo"
  defp action_label(_), do: "Acao"
end
