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
  attr :file_transfer, :map, default: nil

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

          <.p2p_file_transfer
            :if={@file_transfer}
            file_transfer={@file_transfer}
            nickname={@nickname}
            peer_nick={@peer_nick}
          />

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

  attr :file_transfer, :map, required: true
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true

  defp p2p_file_transfer(assigns) do
    ~H"""
    <div class="file-transfer" id="p2p-file-transfer" phx-hook="FileTransferHook">
      <input type="file" class="file-transfer-input u-hidden" />

      <.ft_offer_received
        :if={@file_transfer[:status] == "offer_received"}
        file_transfer={@file_transfer}
      />

      <.ft_progress_bar
        :if={@file_transfer[:status] in ["transferring", "verifying", "paused", "resuming"]}
        file_transfer={@file_transfer}
      />

      <.ft_completed :if={@file_transfer[:status] == "completed"} file_transfer={@file_transfer} />

      <.ft_cancelled
        :if={@file_transfer[:status] == "cancelled"}
        file_transfer={@file_transfer}
      />

      <.ft_failed
        :if={@file_transfer[:status] == "failed"}
        file_transfer={@file_transfer}
      />

      <.ft_rejected
        :if={@file_transfer[:status] == "rejected"}
        file_transfer={@file_transfer}
        peer_nick={@peer_nick}
      />

      <.ft_queued :if={@file_transfer[:queued_file]} file_transfer={@file_transfer} />

      <.ft_validation_error
        :if={@file_transfer[:validation_error]}
        error={@file_transfer.validation_error}
      />

      <.ft_offer_pending
        :if={@file_transfer[:status] == "offering"}
        file_transfer={@file_transfer}
      />
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_offer_received(assigns) do
    ~H"""
    <div class="file-transfer__offer">
      <p class="file-transfer__offer-text">
        {@file_transfer.sender_nick} quer enviar: {@file_transfer.file_name} ({@file_transfer.formatted_size})
      </p>
      <div class="file-transfer__offer-buttons">
        <button
          phx-click="ft_respond"
          phx-value-accepted="true"
          class="file-transfer__offer-btn file-transfer__offer-btn--accept"
        >
          Aceitar
        </button>
        <button
          phx-click="ft_respond"
          phx-value-accepted="false"
          class="file-transfer__offer-btn file-transfer__offer-btn--reject"
        >
          Rejeitar
        </button>
      </div>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_progress_bar(assigns) do
    percent = assigns.file_transfer[:percent] || 0

    assigns =
      assign(assigns,
        percent: percent,
        speed: assigns.file_transfer[:speed] || "0 B/s",
        eta: assigns.file_transfer[:eta] || "--",
        paused: assigns.file_transfer[:status] == "paused",
        resuming: assigns.file_transfer[:status] == "resuming",
        verifying: assigns.file_transfer[:status] == "verifying"
      )

    ~H"""
    <div class="file-transfer__progress">
      <div class="file-transfer__progress-header">
        <span class="file-transfer__progress-filename">{@file_transfer.file_name}</span>
        <span
          :if={@paused}
          class="file-transfer__progress-status file-transfer__progress-status--paused"
        >
          Reconectando...
        </span>
        <span
          :if={@resuming}
          class="file-transfer__progress-status file-transfer__progress-status--resuming"
        >
          Retomando transferencia...
        </span>
        <span :if={@verifying} class="file-transfer__progress-status">
          Verificando integridade...
        </span>
      </div>
      <div
        role="progressbar"
        class="file-transfer__bar"
        aria-valuenow={@percent}
        aria-valuemin="0"
        aria-valuemax="100"
      >
        <div class="file-transfer__bar-fill" style={"width: #{@percent}%"}></div>
      </div>
      <div class="file-transfer__progress-info">
        <span>{@percent}%</span>
        <span :if={!@paused && !@verifying}>{@speed} — ETA: {@eta}</span>
      </div>
      <div :if={!@verifying} class="file-transfer__progress-actions">
        <button phx-click="ft_cancel" class="file-transfer__cancel-btn">
          Cancelar
        </button>
      </div>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_completed(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--success">
      <p>Transferencia concluida com sucesso: {@file_transfer.file_name}</p>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_cancelled(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--cancelled">
      <p>Transferencia cancelada por {@file_transfer.cancelled_by}</p>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_failed(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--error">
      <p>{@file_transfer.reason}</p>
      <button
        :if={@file_transfer[:can_retry]}
        phx-click="ft_retry"
        class="file-transfer__retry-btn"
      >
        Tentar novamente
      </button>
    </div>
    """
  end

  attr :file_transfer, :map, required: true
  attr :peer_nick, :string, required: true

  defp ft_rejected(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--rejected">
      <p>{@peer_nick} rejeitou a transferencia de arquivo</p>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_queued(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--queued">
      <p>Transferencia em andamento, arquivo na fila: {@file_transfer.queued_file}</p>
    </div>
    """
  end

  attr :error, :string, required: true

  defp ft_validation_error(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--error">
      <p>{@error}</p>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_offer_pending(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--pending">
      <p>Aguardando resposta para: {@file_transfer.file_name} ({@file_transfer.formatted_size})</p>
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
