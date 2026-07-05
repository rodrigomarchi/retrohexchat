# Visão geral: espaço virtual

Status: proposta para conversa. Nenhuma implementação feita ainda.

## Problema

Os jogos atuais do projeto são sessões P2P de duas pessoas, apoiadas em WebRTC e
DataChannel. Um escritório virtual com até 20 pessoas tem outro perfil:

- mais participantes;
- entrada por link compartilhável no canal de origem;
- presença coletiva;
- estado visível para todos;
- regras de colisão e movimentação que não podem depender de confiança no
  cliente;
- expiração ligada ao ciclo de vida do link de canal.

Por isso, o espaço deve ser uma sessão multiplayer servida pelo backend, não um
canal P2P entre pares.

## Decisão principal

Separar claramente:

- servidor autoritativo em Elixir/Phoenix para sessão, canal de origem,
  participantes, movimento oficial, expiração, capacidade e broadcast;
- Phoenix Channel para o tráfego realtime do mundo;
- LiveView apenas para shell, validação inicial, terminal/erro e emissão do token
  curto de entrada no Channel;
- cliente 100% JavaScript autoral para input, previsão local, renderização,
  animação, câmera, sprites e UI do mundo;
- mapa declarativo em JSON interno, versionado no repositório, sem depender de
  editor externo na primeira etapa.

Essa escolha respeita o projeto atual: o backend já usa contexto de domínio,
`Registry`, `DynamicSupervisor`, PubSub e LiveView; Phoenix já está no bundle JS;
os jogos já usam JS modular com `engine`, `physics`, `renderer` e `protocol`.

## Escopo da primeira versão

V1 deve entregar uma feature completa de escritório virtual textual/visual. O
desenvolvimento pode ser fatiado em PRs, mas o corte de produto só deve sair
quando o fluxo principal estiver completo.

Incluído:

- criar link via slash command em canal de chat;
- abrir link `/space/:token`;
- limite padrão de 20 pessoas no mesmo espaço, configurável pelo admin;
- entrada, saída, reconexão e expiração;
- quatro mapas planejados, começando por uma taverna-cafe completa;
- avatares andando em grid/top-down;
- colisão com paredes, mesas, árvores, balcões e objetos;
- nomes sobre avatares;
- chat textual global do espaço;
- balão curto de fala acima do avatar;
- sentar em cadeira;
- entrar em sala/zona;
- interagir com quadro e abrir modal de imagem;
- persistência de posição enquanto a sessão estiver ativa;
- poderes do criador: expulsar, fechar, trocar mapa e mutar chat.

Fora da V1:

- áudio/vídeo por proximidade;
- edição de mapa in-app;
- persistência permanente de escritórios;
- inventário, combate, NPCs ou quests;
- pathfinding avançado no servidor;
- usar sprites ou assets da Nintendo.

## Nome de produto e rota

Proposta:

- contexto: `RetroHexChat.VirtualSpace`;
- rota pública da sessão: `/space/:token`;
- comando: `/space [#canal-alvo] [nome-do-space] ttl=2h`;
- tipo de card/mensagem: `:space_invite`;
- tópico PubSub: `"space:#{token}"`;
- canal Phoenix: `"space:#{token}"`;
- hook JS: `SpaceCanvasHook`.

Evitaria reaproveitar `/lobby/:token`, porque hoje `Lobby` significa sessão P2P
de dois participantes. Reusar esse nome criaria ambiguidade no código, nos cards
e nos testes.

## Ciclo de vida

Estado fechado para V1:

```text
pending -> active -> closed | expired | failed
```

Significado:

- `pending`: sessão criada, link emitido, ninguém entrou ainda;
- `active`: ao menos uma pessoa entrou; movimento/interação não cria outro
  estado, só atualiza `last_activity_at`;
- `closed`: encerrada explicitamente pelo criador ou por regra administrativa;
- `expired`: TTL do link acabou;
- `failed`: erro de processo ou estado irrecuperável.

Na primeira versão, o espaço expira junto com o link: o link nasce com
`expires_at`, o card mostra essa validade e o `SessionServer` encerra quando a
validade chega. Atividade dentro do espaço não renova o prazo. TTL default do
comando: 2 horas, configurável e limitado por settings/admin. O criador também
pode encerrar manualmente. Se futuramente o espaço for criado a partir de um
lobby P2P existente, guardar `source_lobby_token` em `metadata` e usar o menor
valor entre o `expires_at` do lobby pai e `now + requested_or_default_ttl`.

## Identidade

Decisão V1: criar e entrar exigem usuário registrado e identificado. Guests não
entram no espaço virtual.

Dentro do `SessionServer`, a identidade efetiva deve ser:

```text
registered:<id>
```

O display continua sendo o nickname da sessão, mas a chave operacional é o id
registrado para evitar colisão por renome/nick.

`SpaceLive` assina um token curto de entrada contendo `space_token`,
`channel_name`, nickname, `user_id` e validade curta. `SpaceChannel` verifica
esse token e a permissão no canal antes de permitir join.

## Por que servidor autoritativo

O cliente pode e deve fazer previsão local para não parecer travado, mas o
servidor decide a posição oficial. Isso impede:

- atravessar parede;
- teleportar para qualquer tile;
- andar mais rápido que o permitido;
- ocupar tile proibido;
- burlar capacidade configurada da sala;
- enviar spam de movimento para derrubar outros clientes.

Com limite padrão de 20 pessoas, JSON em Phoenix Channel é aceitável na V1. Se
um dia crescer para centenas de pessoas por mapa, aí faz sentido pensar em
regiões, binário e sharding.

## Inspiração sem cópia

O objetivo visual é "RPG 8-bit top-down com escritório de fantasia", não Zelda
literal. O primeiro mapa é uma taverna-cafe de fantasia, com balcão, mesas,
cadeiras, salas e quadros interativos. Devemos criar tiles e avatares autorais:
chão de pedra/madeira, mesas de escriba, quadros de runas, vasos, árvores,
estantes, salas de reunião como círculos mágicos, etc.

Isso evita risco de propriedade intelectual e encaixa melhor no tom próprio do
Retro Hex Chat.
