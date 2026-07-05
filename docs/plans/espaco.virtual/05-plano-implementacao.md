# Plano de implementação

Status: proposta para conversa. Nenhuma implementação feita ainda.

## Fase 0: decisão e documentação

Entregáveis:

- estes documentos em `docs/plans/espaco.virtual/`;
- decisões abertas revisadas;
- nome final do comando e da rota.

Critério de saída:

- concordância sobre `VirtualSpace`, `/space/:token`,
  `/space [#canal-alvo] [nome-do-space] ttl=2h` e limite default configurável;
- decisões fechadas em `06-ambiguidades-fechadas.md` aceitas;
- decisões do usuário em `07-decisoes-produto-usuario.md` aceitas.

## Fase 1: sessão, comando e card sem canvas

Backend:

- migration `virtual_space_sessions`;
- schema, queries, policy, service, registry, supervisor, session_server mínimo;
- facade `RetroHexChat.VirtualSpace`;
- comando `/space [#canal-alvo] [nome-do-space] ttl=2h`;
- UI action `:space_invite`;
- card `:space_invite`;
- rota `/space/:token`;
- `SpaceLive` terminal/skeleton;
- `UserSocket` e `SpaceChannel` com join/leave mínimo.

Comportamento:

- cria link;
- vincula sessão ao canal de origem;
- exige usuário registrado/identificado;
- valida permissão de canal;
- abre link;
- valida capacidade;
- entra/sai;
- Channel join retorna snapshot textual/simples;
- expira;
- card mostra status.

Testes:

- unit de policy;
- unit de changeset;
- unit de service create/join/expire;
- command handler;
- render de card vivo/terminal;
- LiveView mount para token válido, inválido, expirado e cheio.
- Channel join autorizado, inválido, expirado e cheio.
- Policy para canal público/privado e usuário não identificado.

## Fase 2: canvas local e snapshot

Frontend:

- `SpaceCanvasHook` lazy;
- `engine.js`;
- `renderer.js`;
- `sprite_atlas.js` autoral;
- mapa `tavern_cafe_v1`;
- render local com câmera e avatar próprio;
- receber `space_init` pelo Channel e snapshot;
- renderizar outros participantes parados.

Backend:

- `join_session` publica snapshot;
- presença básica com `participant_joined` e `participant_left`;
- substituição de aba/reconnect pelo mesmo participant key.

Testes:

- hook registry contract;
- Vitest para parser/normalização de mapa;
- E2E abre `/space/:token` e verifica canvas não branco.

## Fase 3: movimento autoritativo

Backend:

- `space_input`;
- validação de passo adjacente;
- colisão;
- bounds;
- cooldown de velocidade;
- delta broadcast.

Frontend:

- input teclado;
- previsão local;
- reconciliação por `seq_ack`;
- interpolação para remotos;
- label de nickname.

Testes:

- unit de colisão/validação no servidor;
- unit JS de collision/map;
- E2E com 2-3 usuários vendo movimento um do outro;
- teste de input inválido não move o jogador.

## Fase 4: escritório vivo

Adicionar:

- zonas `spawn`, `meeting`, `quiet`;
- chat textual global;
- balão de fala curto;
- cadeiras sentáveis;
- salas/zonas navegáveis;
- quadro/interactable com modal de imagem;
- indicador de participante/lotação;
- tela de cheio/expirado refinada;
- pequenos detalhes visuais autorais.

Testes:

- zona muda ao entrar/sair;
- balão escapa HTML;
- limite de mensagem;
- cadeira não aceita dois ocupantes;
- quadro abre modal;
- capacidade configurável.

## Fase 5: poderes do criador e mapas

Adicionar:

- expulsar participante;
- mutar/desmutar participante;
- fechar espaço manualmente;
- trocar mapa;
- registry de quatro mapas;
- snapshot completo em troca de mapa;
- persistência de posição em reload/reconnect.

Testes:

- criador consegue usar ações administrativas;
- participante comum não consegue;
- usuário expulso sai e recebe erro claro ao tentar reentrar, se banido da sessão;
- mutado não envia chat;
- troca de mapa respawna em tile válido;
- reload mantém posição enquanto sessão ativa.

## Fase 6: robustez

Adicionar:

- cleanup task para sessões vencidas;
- refresh ao vivo de cards de sessão;
- métricas simples;
- logs de erro úteis;
- rate limiter específico se o P2P rate limiter não encaixar;
- cenários de reconnect/offline.

Testes:

- reconnect mantém ou substitui participante corretamente;
- fechar aba remove/coloca offline;
- reinício do processo retoma sessão não expirada;
- `make ci`.

## Fases futuras

Não colocar na V1, mas deixar o desenho preparado:

- proximidade de áudio/vídeo;
- salas privadas;
- múltiplos andares;
- portais para outros espaços;
- editor de mapa;
- importador Tiled/TMJ;
- persistência de escritórios além do lobby;
- uploads/edição de imagens de quadros.

## Decisões fechadas

1. Criar e entrar exigem usuário registrado/identificado, permissão de canal e
   token de join assinado.
2. TTL é fixo desde criação, default 2h, sem renovação por atividade, com close
   manual pelo criador.
3. Comando e rota V1 são `/space [#canal-alvo] [nome-do-space] ttl=2h` e
   `/space/:token`; `/office` fica fora da V1.
4. `/space` posta card somente em canal de chat; PM/Status não são origem de
   espaço na V1.
5. Runtime realtime usa Phoenix Channel; LiveView é shell.
6. Mapas V1 são JS/JSON autorais internos; primeiro completo é `tavern_cafe_v1`;
   importador Tiled fica para depois.
7. Movimento V1 é tile-a-tile cardinal, servidor autoritativo, sem colisão entre
   participantes.
8. V1 inclui chat global do espaço, balões, cadeiras, salas/zonas, quadro com
   modal, poderes do criador e persistência de posição em sessão ativa.

## Riscos

- Eventos realtime em alta frequência podem ficar pesados se enviarmos movimento
  por frame. Mitigação: Phoenix Channel, input discreto tile-a-tile, deltas
  pequenos e limite de 20.
- Se o servidor aceitar posição livre, o mundo vira trivial de burlar. Mitigação:
  input como intenção, servidor valida.
- Se o canvas captura teclado sempre, quebra chat. Mitigação: respeitar foco e
  ter modo explícito de chat/balão.
- Assets "inspirados em Zelda" podem virar cópia sem querer. Mitigação: tiles e
  personagens autorais, nomes próprios e paleta própria.
- Reaproveitar `Lobby` para 20 pessoas cria ambiguidade com P2P. Mitigação:
  contexto novo `VirtualSpace`.

## Primeiro PR recomendado

O menor PR que cria valor sem assumir engine:

1. migration/schema/contexto `VirtualSpace`;
2. `/space` cria sessão e card;
3. `/space/:token` abre uma LiveView skeleton;
4. `SpaceChannel` aceita join e retorna snapshot simples;
5. join/leave/expire funcionam;
6. testes de domínio, comando, LiveView e Channel.

Depois disso, o canvas entra em PR separado.
