# Onda 6 — coordenação entre abas, bundle medido, e fechar o plano

**Depende de:** ondas 0–5.

**Entrega:** o chat sabe o que você tem aberto, o bundle é dividido com número na
mão (ou não é dividido, com número na mão), e as regras duráveis saem daqui para
os guias.

---

## 1. Coordenação entre abas

### 1.1 A verdade é do servidor, não do navegador

A tentação é `BroadcastChannel` e pronto. Mas o servidor **já vai saber** disso
desde a onda 2 §2.6: o registro de superfícies abertas por nickname existe para
manter a filiação a canal viva. Ele é a fonte da verdade porque:

* sobrevive a `noopener` (o navegador não tem referência entre as abas);
* sobrevive a abas em máquinas diferentes — a mesma pessoa no laptop e no
  celular;
* é o mesmo dado que a taskbar e o menu precisam para decidir entre "abrir" e
  "focar".

`BroadcastChannel` entra só para uma coisa: **tentar** trazer a aba existente pra
frente. E isso precisa estar escrito com honestidade — `window.focus()` a partir
de uma aba em segundo plano é bloqueado em muitos casos. O contrato então é:

1. o chat pede foco pelo `BroadcastChannel`;
2. a aba satélite tenta `window.focus()`;
3. se em ~300 ms nada mudou, o chat cai para "você já tem esta chamada aberta em
   outra aba" com o link — que é o comportamento correto de qualquer jeito,
   porque a aba pode estar em outra janela ou outro monitor.

Degradar bem é o requisito; focar é o bônus.

### 1.2 O que muda na UI do chat

* A taskbar e o menu Games/Call passam a mostrar o estado real: **abrir** quando
  não há nada, **focar** quando há.
* O `chat_shell_status` (`chat_live.html.heex:88`) ganha o que hoje ele já quase
  faz: dizer que existe uma chamada/space/jogo rodando — só que agora ele diz
  *onde*.
* Fechar a última aba de uma superfície é o que devolve a filiação a canal ao
  estado de "só chat" (§2.6 da onda 2).

### 1.3 TDD

| Camada | Asserção |
|---|---|
| `:unit` | o registro de superfícies conta corretamente abrir/fechar/crash; o `:DOWN` de um LiveView decrementa |
| `:unit` | a última superfície a fechar libera a filiação; a penúltima não |
| Vitest | `lib/surfaces/tab_registry.js`: anuncia, escuta, e o pedido de foco expira em vez de pendurar |
| `:liveview` | a taskbar renderiza "focar" quando o registro tem a superfície, "abrir" quando não |
| Playwright | abrir a mesma chamada duas vezes não gera dois participantes; a segunda aba avisa |

---

## 2. Bundle — agora com número

Só aqui, e por decisão D4 do [README](README.md).

### 2.1 O que medir

`assets/scripts/bundle_budget.cjs` já constrói cada entry com metafile
(`--metafile`). Rodar por superfície e responder:

* quanto de `app.js` cada superfície satélite realmente executa;
* quanto do entry é LiveSocket + `phoenix_live_view` (compartilhado com o chat,
  logo cacheável entre abas);
* quanto é cola exclusiva do chat, que a satélite baixa e nunca chama.

O contexto que já existe: `app.js` tem orçamento de **470 KB / 130 KB gzip**; a
entry pública tem **80 KB / 18 KB**; o chunk do SFU **85 KB**; o do space
**120 KB** — os dois já lazy.

### 2.2 A decisão que o número toma

* Se a cola exclusiva do chat for pequena → **não dividir**. Uma entry a mais
  é um download a mais no primeiro clique e uma linha de orçamento a mais para
  sempre. "Não dividir" é um resultado legítimo e precisa ser aceitável antes de
  medir, senão a medição é teatro.
* Se for grande → uma entry **`surface.js`** compartilhada pelas quatro
  satélites, não uma por superfície. As partes pesadas já são chunks lazy; o que
  se ganha é o entry, e um entry compartilhado é cache quente ao pular de
  `/call` para `/space`.

Em qualquer um dos dois casos: entry nova = linha em `ENTRIES` **e** orçamento em
`BUDGETS` com razão escrita. Número sem razão vira carimbo
(`bundle_budget.cjs:57-60`).

### 2.3 A conta de nós de DOM que ninguém lembra

Cada tela do window manager herda o Start menu inteiro — **+177 nós, +17 KB raw,
+1 KB gzip** por tela (`test/support/perf_budgets.ex`, moduledoc). Quatro
satélites = quatro vezes isso.

Decisão a tomar aqui, com os `PerfBudgets` de todas as ondas na mesa: o
superconjunto é uma regra do **desktop do chat** ou de **toda tela com window
manager**? Uma superfície de propósito único carregando 177 linhas cinzas é
peso sem uso. *Recomendação: satélites carregam só o que alcançam, mais um
"Voltar ao chat".* Se isso for aceito, é uma exceção escrita — não um
esquecimento.

---

## 3. Convergência e fechamento

### 3.1 Código que deve ter sumido

- `ChatLive.Components.RetroGamesIsland`, `ChatLive.RetroGamesEvents` (onda 0)
- o corpo de `group_call_events.ex` que não é read-model de canal (onda 2)
- os assigns e handlers de space no `ChatLive` (onda 3)
- a sinalização P2P no `ChatLive` (onda 4)
- o polling de janela do `arcade_session_hook.js` (onda 5)

Grep por **módulo e função**, nunca por nome de arquivo — "0 referências" já foi
falso neste repositório exatamente por isso.

### 3.2 Documentação durável (mover, depois apagar o plano)

| Para onde | O quê |
|---|---|
| `AGENT-GUIDE.md` §7 / `guide/windowed-desktop.md` | a regra "um módulo, dois hosts" (D2) e como testar as duas montagens |
| `guide/webrtc-p2p.md` | a política de nomes muda: existe superfície standalone de novo, e o transporte 1:1 virou channel. §8.1 ganha o estado `open` |
| `guide/webrtc-p2p.md` §8.5 | fechar aba ≠ sair, agora como caso comum |
| `AGENT-GUIDE.md` §16 | os cinco segmentos reservados de rota e por que `/join` é `noindex` |
| novo `guide/surfaces.md` (só se sobrar coisa que não cabe acima) | o `Live.Surface`, o registro de superfícies, o resolver |
| `docs/reference/call-handshake-resilience-map.md` | reescrito para o transporte novo |

Nada de contagem em prosa (quantas superfícies, quantas rotas) — apontar para o
router.

### 3.3 Só então

Apagar `docs/plans/shareable-surfaces/`.

---

## 4. Pronto quando

- `make ci` verde.
- A taskbar do chat mostra corretamente abrir/focar, e o caso de foco bloqueado
  degrada com mensagem em vez de silêncio.
- A decisão de bundle está escrita com o número que a produziu, seja ela dividir
  ou não dividir.
- A decisão do Start menu nas satélites está escrita.
- Todo código da §3.1 sumiu, verificado por grep de símbolo.
- Os guias foram atualizados **antes** de o diretório do plano ser apagado.
