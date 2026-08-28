# Onda 1 — `/join/:slug`, o link que dá pra postar

**Depende de:** onda 0 (uma aba satélite precisa poder existir).

**Entrega:** um link curto, público, com preview de rede social, que resolve para
qualquer superfície e aplica a política normal de quem clicou.

---

## 1. Por que um resolver único, e não uma URL por feature

`/call/:room_token` já seria uma URL. Ela tem três problemas que só aparecem
depois:

1. **Vaza estrutura.** O token da sala é uma coluna do banco
   (`group_call_rooms.token`); publicá-lo amarra a URL ao schema.
2. **Não é revogável.** Fechar o link exigiria fechar a sala.
3. **Não serve pro space.** Um space é identificado por nome de canal
   (`space:#retro`) ou por chave de DM (`space:dm:<key>`)
   (`channels/space_channel.ex:22,41`). Nenhum dos dois é seguro nem bonito numa
   URL.

Um `share_link` resolve os três de uma vez, e dá de graça o que a onda 6 vai
querer: contagem de cliques por link, para saber se compartilhar link realmente
traz gente.

## 2. O que muda

### 2.1 Contexto novo: `RetroHexChat.ShareLinks`

Camadas iguais às dos outros contextos (Schema, Queries, Service, Policy —
`AGENT-GUIDE` §1.2).

Tabela `share_links`:

| coluna | papel |
|---|---|
| `slug` | opaco, url-safe, único. Curto o bastante pra caber num tweet |
| `kind` | `"call" \| "space" \| "p2p" \| "play"` |
| `target` | `:map` — o que aquele kind precisa (`channel_name`, `room_token`, `space_id`, `session_token`, `game_id`) |
| `creator_id` / `creator_nick` | quem criou, para revogação e auditoria |
| `expires_at` | nulo = não expira |
| `revoked_at` / `revoked_by` | fechar o link sem fechar a sala |
| `resolve_count` / `last_resolved_at` | o número que responde "compartilhar link funciona?" |

`ShareLinks.resolve/1` devolve `{:ok, %{kind:, target:, live?: boolean}}` ou
`{:error, :not_found | :revoked | :expired}`. `live?` é derivado do runtime, não
persistido: sala ativa (`GroupCall.Queries.active_room_exists?/1`), sessão P2P
não-terminal, jogo existente no catálogo. Persistir `live?` é como o Registry
mentiria sobre uma sessão P2P — a mesma razão pela qual a checagem de duplicata
do P2P é uma query e não um lookup no Registry
([`guide/webrtc-p2p.md` §8.1](../../guide/webrtc-p2p.md)).

Rate limit na criação, no mesmo estilo do P2P (janela deslizante em ETS, escala
de minutos), não no `RateLimit.Limiter` de mensagem.

### 2.2 `/join/:slug` — página pública

Pipeline `:landing_live`, não `:app`. Motivo: quem clica vindo de fora pode nem
ter sessão, e o entry público tem orçamento de 80 KB / 18 KB gzip contra os
470 KB do `app.js`. A página de convite é a primeira coisa que um estranho vê do
produto; ela não pode custar o app inteiro.

Quatro estados, e todos os quatro são teste:

| estado | o que a pessoa vê |
|---|---|
| link vivo + sessão + autorizado | card + botão que faz `push_navigate` para `/call/:token` etc. |
| link vivo + sessão + **não** autorizado | card + o motivo, na linguagem da `Policy` (`"You are not in this channel"`) |
| link vivo + **sem** sessão | card + Connect → `/connect?return_to=/join/:slug` |
| link morto (revogado / expirado / sala fechada) | card de "acabou", com link pro chat |

### 2.3 `return_to` no connect — e o open redirect que ele seria se ninguém olhasse

`SessionController.create/2` já sabe redirecionar para um destino derivado de
parâmetro: `join_channel_redirect/1` (`session_controller.ex:117`). `return_to` é
a generalização disso, com uma diferença que precisa estar no código e no teste:

**um `return_to` só é aceito se for um caminho interno conhecido.** Começar com
`/`, não começar com `//`, não conter `\`, não conter `..`, e casar com o
conjunto de prefixos de superfície (`/join/`, `/call/`, `/space/`, `/p2p/`,
`/play/`, `/chat`). Qualquer outra coisa cai no default `/chat`, em silêncio para
o atacante e com log para nós.

Isto é a única superfície de open redirect que o plano inteiro cria. Ela ganha
teste negativo próprio.

### 2.4 Compartilhar de dentro do chat, e o card ao vivo

Desenho: [`ux.md` §2.1](ux.md) (o card na conversa) e [§2.2](ux.md) (o card
público). Aqui fica só o que precisa existir no código.

**O link nasce de um botão** (P6). Abrir a feature cria a sala; `[Compartilhar]`
cria o `share_link`. Duas ações: **copiar** (`clipboard_copy` já existe em
`SURFACE.txt`) e **mandar pra conversa atual** — que é uma mensagem normal, no
canal ou na PM. Não inventar canal de entrega: o convite P2P já provou que reusar
`send_private_message` funciona e fica no histórico
([`guide/webrtc-p2p.md` §8.1](../../guide/webrtc-p2p.md)).

**O card é uma mensagem, e ele é ao vivo** (P3). Tipo `:share_card` ao lado de
`:p2p_invite` em `components/ui/chat/message_row.ex:121`. Três kinds × dois
estados (vivo / encerrado), e um card encerrado sempre oferece a próxima ação
plausível — nunca um beco.

O que mantém o card vivo, por kind:

| kind | leitura | assinatura |
|---|---|---|
| chamada | `GroupCall.get_summary/1` | **nenhuma nova** — o `ChatLive` já mantém `@group_call_channel_summaries` por PubSub (`group_call_events.ex:72-97`) |
| space | `VirtualSpace.snapshot/1` | **nova** — o `ChannelSpaceServer` já transmite entrada/saída no tópico `space:#canal` (`channel_space_server.ex:434,599`), mas o chat ainda não assina |
| jogo / P2P | `Lobby` | tópico `lobby:<token>`, que o chat já conhece |

O único custo novo é o do space. Ele tem um limite que precisa estar no código:
**o chat assina o tópico de space de um canal só enquanto houver card visível
daquele canal** — assinar todos os canais em que a pessoa está transformaria cada
passo de cada avatar em tráfego para quem só quer conversar.

**O convite P2P de hoje vira uma variante deste card**, não um segundo
componente. Ele já é o card do kind `p2p` com estado "aguardando" — a diferença
é que hoje ele carrega `/lobby/<token>` no texto
(`live/chat_live/helpers/lobby_invite.ex:88`) e passa a carregar `/join/:slug`.

### 2.5 Open Graph — e o que ele não pode contar

`SEO` já tem `canonical_url/2`, `social_image_url/0`, `alternate_links/1`.
O card de `/join/:slug` usa isso.

**Decisão que precisa estar no código:** o preview não revela nome de canal
privado. Um link de conferência num canal secreto que renderiza
"Chamada em #diretoria" no Twitter vaza a existência do canal para quem nunca
poderia listá-lo. Regra: OG genérico por padrão; nome do canal no preview
**apenas** quando o canal for público pelas regras de modo que já existem em
`RetroHexChat.Channels`. Isto é um teste, não um comentário.

`/join/*` é `noindex` (`SEO.noindex_content/0`) e não entra no sitemap: um link
de convite indexado no Google é um convite que ninguém mandou.

---

## 3. TDD

### 3.1 `:unit`

| Arquivo | Asserção |
|---|---|
| `.../share_links/slug_test.exs` | charset url-safe, comprimento fixo, sem ambiguidade visual (`0/O`, `1/l`), unicidade sob geração em massa |
| `.../share_links/policy_test.exs` | quem pode criar por kind; quem pode revogar (criador + op do canal) |
| `apps/retro_hex_chat_web/test/.../return_to_test.exs` | tabela de casos: `/chat` ok; `/join/abc` ok; `//evil.com` recusado; `https://evil.com` recusado; `/chat/../../etc` recusado; `""`/`nil` → default |

O teste de `return_to` é uma tabela porque a falha aqui é silenciosa e cara.

### 3.2 `:integration`

| Arquivo | Asserção |
|---|---|
| `.../share_links/service_test.exs` | `resolve/1` para os quatro `kind`; `:not_found`, `:revoked`, `:expired` |
| idem | `live?` acompanha o runtime: criar sala → `live? == true`; fechar sala → `live? == false` **com o mesmo slug** |
| idem | `resolve_count` incrementa uma vez por resolução e não em erro |
| idem | rate limit de criação dispara e libera |

### 3.3 Componente — o card

| Asserção |
|---|
| os três kinds renderizam com ícone, título e ação próprios |
| estado encerrado: cinza, sem `[Entrar]`, **com** a próxima ação (`Abrir #canal` / `Jogar X`) |
| contagem de participantes reflete o summary passado, e muda quando ele muda |
| um card de canal privado visto por quem não é membro não revela o nome do canal |
| o card de kind `p2p` cobre o que o `:p2p_invite` cobria — teste portado, não reescrito |

| Asserção (host) |
|---|
| o chat assina o tópico `space:#canal` ao renderizar um card de space daquele canal, e **cancela** quando o último card sai de vista |

A segunda tabela é o teste que impede o card ao vivo de virar um custo silencioso
por canal.

### 3.4 `:liveview`

| Arquivo | Asserção |
|---|---|
| `.../live/join_live_test.exs` | os quatro estados de §2.2, cada um por `data-testid` próprio |
| idem | sem sessão, o botão aponta para `/connect?return_to=…` com o slug correto |
| idem | autorizado → `push_navigate` para a rota da superfície certa por kind |
| idem | OG: canal público aparece no `og:title`; canal privado **não** aparece em lugar nenhum do documento (asserção por `refute` no HTML inteiro, não só na meta) |
| `.../controllers/app/session_controller_test.exs` | `return_to` válido é honrado; inválido cai em `/chat` |

### 3.5 Playwright

`e2e/tests/share-link-join.spec.ts`:

1. usuário A, no chat, cria e copia o link de uma superfície;
2. **contexto novo, sem cookie** abre o link → card público, sem conteúdo do
   canal;
3. Connect nesse contexto → volta para `/join/:slug` (o `return_to` funcionou) →
   entra;
4. A revoga o link → um terceiro contexto vê o card de "acabou".

---

## 4. Obrigações do repositório

- [ ] Migração + índices: único em `slug`; índice para revogação por criador.
- [ ] `docs/README.md` se um `docs/reference/` novo nascer — provavelmente não
      nasce: o catálogo de kinds é respondido pelo código.
- [ ] Help topic: "como compartilhar um link", "como revogar". Ambos são
      acionáveis.
- [ ] i18n dos textos do card, incluindo os quatro estados.
- [ ] `PerfBudgets` para `:join` (é uma página pública — o orçamento importa).
- [ ] `SURFACE.txt` para os eventos de share/copy.
- [ ] Sitemap **não** muda; garantir por teste que `/join` não entrou.

## 5. Riscos

* **Enumeração de slug.** Slug curto convida a varredura. Comprimento e charset
  saem de um cálculo escrito no `@moduledoc` do gerador, e a resolução tem rate
  limit por IP como qualquer rota pública.
* **O card ao vivo é tráfego por card visível.** O de chamada é grátis (o assign
  já existe); o de space não é. Sem o cancelamento de assinatura da §3.3, um
  canal com space movimentado manda delta de avatar para todo mundo que só queria
  ler o chat.
* **O card vira canal lateral de informação.** Toda diferença de mensagem entre
  "não existe" e "existe mas você não pode" é um oráculo. Manter as duas
  respostas indistinguíveis para quem não tem sessão.
* **Link em rede social com `live?` falso a maior parte do tempo.** Uma chamada
  dura minutos; o link dura para sempre. O card precisa ser útil morto — "essa
  chamada acabou, o canal é #retro, entra aí" — senão o compartilhamento gera
  uma experiência ruim na maioria dos cliques.

## 6. Pronto quando

- `make ci` verde.
- Os quatro estados do card cobertos em `:liveview` e o fluxo de fora coberto em
  Playwright.
- A tabela de `return_to` recusa todos os casos negativos.
- `/lobby/:token` legado resolve para `/join/:slug` quando possível.
