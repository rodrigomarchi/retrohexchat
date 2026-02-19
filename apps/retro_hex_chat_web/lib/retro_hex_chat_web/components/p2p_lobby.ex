defmodule RetroHexChatWeb.Components.P2pLobby do
  @moduledoc """
  Function components for the P2P session lobby UI.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

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
  attr :call, :map, default: nil
  attr :turn_only, :boolean, default: false
  attr :turn_configured, :boolean, default: false

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

        <div
          :if={@session_status == "connecting" && !@webrtc_state && !@call}
          class="p2p-lobby__connecting"
        >
          <p>Aguardando conexao...</p>
        </div>

        <.p2p_media_call
          :if={@call}
          call={@call}
          peer_nick={@peer_nick}
        />

        <div :if={@session_status != "connecting" && !@call} class="p2p-lobby__content">
          <.p2p_presence nickname={@nickname} peer_nick={@peer_nick} peer_online={@peer_online} />

          <.p2p_chat messages={@messages} nickname={@nickname} />

          <.p2p_file_transfer
            :if={@file_transfer}
            file_transfer={@file_transfer}
            nickname={@nickname}
            peer_nick={@peer_nick}
          />

          <.p2p_actions
            :if={!@file_transfer}
            capabilities={@capabilities}
            action_request={@action_request}
            nickname={@nickname}
            peer_nick={@peer_nick}
            session_status={@session_status}
          />
        </div>

        <div :if={!@call && !@file_transfer} class="p2p-lobby__footer">
          <div
            :if={@turn_configured || @turn_only}
            class="p2p-lobby__privacy"
          >
            <label class="p2p-lobby__privacy-label">
              <input
                type="checkbox"
                checked={@turn_only}
                phx-click="toggle_privacy_mode"
              /> Modo privado (TURN-only)
            </label>
            <span :if={!@turn_configured} class="p2p-lobby__privacy-warning">
              Servidor TURN nao configurado
            </span>
          </div>
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
      <form
        id="lobby-chat-form"
        class="p2p-lobby-chat__form"
        phx-submit={JS.push("send_lobby_message") |> JS.dispatch("reset", to: "#lobby-chat-form")}
      >
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

  attr :call, :map, required: true
  attr :peer_nick, :string, required: true

  defp p2p_media_call(assigns) do
    bars_active = quality_bars_active(assigns.call[:quality_level])
    assigns = assign(assigns, bars_active: bars_active)

    ~H"""
    <div
      id="media-call"
      phx-hook="MediaHook"
      class="media-call"
    >
      <div :if={@call.type == "video"} class="media-call__video-area">
        <video
          id="remote-video"
          class={"media-call__remote #{if @call.peer_camera_off, do: "u-hidden"}"}
          autoplay
          playsinline
        >
        </video>
        <div :if={@call.peer_camera_off} class="media-call__placeholder">
          {@peer_nick} — camera desligada
        </div>
        <video
          id="local-video"
          class="media-call__local"
          autoplay
          playsinline
          muted
        >
        </video>
      </div>

      <audio id="remote-audio" autoplay></audio>

      <div class="media-call__info">
        <span>{@peer_nick}</span>
        <span class="media-call__timer">{@call.duration}</span>
        <div :if={@call.quality_level} class="media-call__quality">
          <div class="media-call__quality-bars">
            <div
              :for={i <- 1..4}
              class={"media-call__quality-bar #{if i <= @bars_active, do: "media-call__quality-bar--active media-call__quality-bar--#{@call.quality_level}"}"}
            >
            </div>
          </div>
          <span class="media-call__quality-label">{@call.quality_label}</span>
        </div>
      </div>

      <div :if={@call.peer_muted} class="media-call__mute-indicator">
        {@peer_nick} silenciou o microfone
      </div>

      <div :if={@call.upgrade_pending && !@call[:upgrade_from]} class="media-call__upgrade-consent">
        <span>{@peer_nick} quer adicionar video</span>
        <button phx-click="media_respond_upgrade" phx-value-accepted="true">Aceitar</button>
        <button phx-click="media_respond_upgrade" phx-value-accepted="false">Recusar</button>
      </div>

      <div :if={@call.upgrade_pending && @call[:upgrade_from]} class="media-call__mute-indicator">
        Aguardando resposta para adicionar video...
      </div>

      <hr class="media-call__separator" />

      <div class="media-call__controls">
        <div class="media-call__controls-row">
          <button
            data-media-action="mute"
            class={"#{if @call[:local_muted], do: "media-call__btn--active"}"}
          >
            {if @call[:local_muted], do: "Ativar Mic", else: "Silenciar"}
          </button>
          <button
            :if={@call.type == "video"}
            data-media-action="camera"
            class={"#{if @call[:local_camera_off], do: "media-call__btn--active"}"}
          >
            {if @call[:local_camera_off], do: "Ligar Camera", else: "Desligar Camera"}
          </button>
          <button :if={@call.type == "audio"} data-media-action="upgrade">
            Adicionar Video
          </button>
          <button :if={@call.type == "video"} data-media-action="pip">
            PiP
          </button>
          <button class="media-call__push-right" data-media-action="device-settings">
            Dispositivos
          </button>
        </div>
        <div class="media-call__controls-row">
          <button phx-click="media_select_preset" phx-value-preset="high">Alta</button>
          <button phx-click="media_select_preset" phx-value-preset="medium">Media</button>
          <button phx-click="media_select_preset" phx-value-preset="low">Baixa</button>
          <button class="media-call__end-btn" data-media-action="end-call">
            Encerrar Chamada
          </button>
        </div>
      </div>
    </div>
    """
  end

  @spec quality_bars_active(String.t() | nil) :: non_neg_integer()
  defp quality_bars_active("excellent"), do: 4
  defp quality_bars_active("good"), do: 3
  defp quality_bars_active("fair"), do: 2
  defp quality_bars_active("poor"), do: 1
  defp quality_bars_active(_), do: 0

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

      <.ft_ready :if={@file_transfer[:status] == "ready"} />

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

  defp ft_ready(assigns) do
    ~H"""
    <div class="file-transfer__ready">
      <p class="file-transfer__ready-text">
        Arraste um arquivo aqui ou clique para selecionar
      </p>
      <button
        class="file-transfer__ready-btn"
        onclick="this.closest('.file-transfer').querySelector('.file-transfer-input').click()"
      >
        Escolher Arquivo
      </button>
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
      <button phx-click="ft_reset" class="file-transfer__reset-btn">
        Enviar outro arquivo
      </button>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_cancelled(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--cancelled">
      <p>Transferencia cancelada por {@file_transfer.cancelled_by}</p>
      <button phx-click="ft_reset" class="file-transfer__reset-btn">
        Enviar outro arquivo
      </button>
    </div>
    """
  end

  attr :file_transfer, :map, required: true

  defp ft_failed(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--error">
      <p>{@file_transfer.reason}</p>
      <div class="file-transfer__status-actions">
        <button
          :if={@file_transfer[:can_retry]}
          phx-click="ft_retry"
          class="file-transfer__retry-btn"
        >
          Tentar novamente
        </button>
        <button phx-click="ft_reset" class="file-transfer__reset-btn">
          Enviar outro arquivo
        </button>
      </div>
    </div>
    """
  end

  attr :file_transfer, :map, required: true
  attr :peer_nick, :string, required: true

  defp ft_rejected(assigns) do
    ~H"""
    <div class="file-transfer__status file-transfer__status--rejected">
      <p>{@peer_nick} rejeitou a transferencia de arquivo</p>
      <button phx-click="ft_reset" class="file-transfer__reset-btn">
        Enviar outro arquivo
      </button>
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
      <button phx-click="ft_reset" class="file-transfer__reset-btn">
        Tentar outro arquivo
      </button>
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
