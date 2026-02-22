# P2P no RetroHexChat — Discovery

## DCC Moderno: Descentralização de Mídia via WebRTC

---

## I. Motivação

O DCC (Direct Client-to-Client) foi uma das funcionalidades mais icônicas do IRC.
Transferir arquivos, abrir um chat privado direto, até fazer chamadas de voz — tudo
passando de máquina para máquina, sem sobrecarregar o servidor. O servidor era apenas
o intermediário que apresentava os dois lados. Depois, saía do caminho.

O Discord e o Slack centralizaram tudo. Cada arquivo que você envia passa pelos
servidores deles. Cada chamada de voz é roteada pela infraestrutura deles. Você
paga com seus dados e com a dependência. Se eles caem, você fica mudo.

O RetroHexChat traz o DCC de volta — mas com tecnologia de 2026. WebRTC substitui
as conexões TCP diretas do DCC original. O navegador negocia a conexão P2P. O
servidor faz apenas o signaling (sinalização): apresenta os dois lados, troca as
credenciais de conexão, e sai do caminho. Exatamente como o IRC fazia, mas agora
com criptografia ponta-a-ponta obrigatória, travessia de NAT automática, e suporte
nativo a áudio, vídeo e transferência de dados binários.

100% self-hosted. Zero dependência de serviços externos para mídia. O servidor
coordena; os peers se conectam.

## II. Índice

| # | Documento | Tema |
|---|-----------|------|
| 01 | [Fluxo da Sessão P2P](01-fluxo-sessao.md) | Ciclo de vida, lobby, aceite mútuo, wireframes |
| 02 | [Fundamentos WebRTC](02-webrtc-fundamentos.md) | Offer/answer, SDP, ICE, STUN, TURN |
| 03 | [Ecossistema Elixir WebRTC](03-stack-elixir.md) | ex_webrtc, Membrane, Rel, comparativo |
| 04 | [Transferência de Arquivos](04-transferencia-arquivos.md) | DataChannel, chunking, protocolo, UI |
| 05 | [Chamadas de Áudio e Vídeo](05-audio-video.md) | getUserMedia, codecs, controles, layout |
| 06 | [Sinalização via Phoenix](06-sinalizacao-phoenix.md) | PubSub signaling, hooks, sequência |
| 07 | [Segurança e Privacidade](07-seguranca.md) | Tokens, autorização, IP leak, rate limiting |
| 08 | [Arquitetura Proposta](08-arquitetura-proposta.md) | Bounded context, GenServer, schemas, router |

## III. Glossário Rápido

| Termo | Definição |
|-------|-----------|
| **WebRTC** | Web Real-Time Communication — API do navegador para comunicação P2P em tempo real (áudio, vídeo, dados). Criptografia DTLS obrigatória. |
| **SDP** | Session Description Protocol — formato de texto que descreve as capacidades de mídia de cada peer (codecs, formatos, endereços). Trocado via offer/answer. |
| **ICE** | Interactive Connectivity Establishment — framework para descobrir o melhor caminho de rede entre dois peers. Testa candidatos (host, srflx, relay) em ordem de preferência. |
| **STUN** | Session Traversal Utilities for NAT — servidor leve que responde "qual é seu IP público?" Permite que peers atrás de NAT descubram como são vistos externamente. |
| **TURN** | Traversal Using Relays around NAT — servidor relay que encaminha pacotes quando a conexão direta falha (~30% dos casos com NATs simétricos). Último recurso, mais caro. |
| **DataChannel** | Canal de dados binários/texto sobre WebRTC. Usa SCTP sobre DTLS. Ideal para transferência de arquivos — sem precisar de servidor intermediário. |
| **Signaling** | Processo de troca de metadados (SDP + ICE candidates) necessário para estabelecer a conexão P2P. O servidor coordena, mas não participa da mídia. |
| **DTLS** | Datagram Transport Layer Security — criptografia obrigatória em todas as conexões WebRTC. Garante confidencialidade e integridade ponta-a-ponta. |
| **Peer** | Um dos dois participantes da conexão P2P. No contexto do RetroHexChat, sempre um usuário registrado. |
| **Lobby** | Sala de espera onde os dois peers se encontram antes de iniciar a sessão P2P propriamente dita. Inclui chat temporário. |

## IV. Premissas

1. **Ambos os participantes devem ser usuários registrados** — guests não podem
   iniciar ou aceitar sessões P2P.
2. **O servidor nunca carrega mídia** — apenas sinalização. Arquivos, áudio e vídeo
   fluem diretamente entre os peers.
3. **HTTPS obrigatório** — navegadores modernos exigem contexto seguro para
   `getUserMedia()` e WebRTC.
4. **Self-hosted** — zero dependência de serviços SaaS para STUN/TURN. O operador
   do servidor pode rodar seu próprio STUN/TURN ou usar públicos.

## V. Relação com a Constituição

| Princípio | Relevância |
|-----------|------------|
| I. Stack Exclusiva | WebRTC é API do navegador — sem frameworks JS extras. Signaling 100% Elixir/Phoenix. |
| II. Umbrella + Bounded Contexts | Novo contexto `P2P` no app de domínio, `P2PSessionLive` no app web. |
| III. OTP Process Architecture | GenServer por sessão P2P, sob DynamicSupervisor. |
| IV. TDD | Testes para signaling, GenServer de sessão, políticas de acesso. |
| VII. Lean LiveViews | LiveView `P2PSessionLive` delega para contexto `P2P`. Hooks JS isolados. |
| VIII. retro Fidelity | UI do lobby e controles seguem estética retro design system. |
| IX. Hot/Cold Data | Sessão ativa em GenServer (hot), histórico em PostgreSQL (cold). |
| XI. Help Documentation | Help topics para `/p2p`, `/call`, `/sendfile`. |
