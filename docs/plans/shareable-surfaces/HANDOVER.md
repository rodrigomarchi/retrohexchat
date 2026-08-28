# Handover — superfícies compartilháveis

Escrito em 2026-08-28 para retomar o trabalho com contexto zerado. Apagar
quando a onda 6 fechar.

---

## 1. Leia nesta ordem

1. [`README.md`](README.md) — a análise, as decisões travadas (P1–P7 produto,
   D1–D6 arquitetura) e o mapa das ondas.
2. [`ux.md`](ux.md) — **o desenho de todas as telas**. Quando uma onda e este
   arquivo discordarem, o arquivo está errado e é ele que muda primeiro.
3. [`PROGRESS.md`](PROGRESS.md) — onze iterações registradas, com os erros. Leia
   pelo menos as iterações 7, 8 e 10: são armadilhas que vão voltar.
4. O arquivo da onda em que você vai mexer.

E antes de tocar código: `AGENTS.md`, `CLAUDE.md` e as regras em
`.claude/rules/` que o caminho do arquivo disparar.

---

## 2. Estado em 2026-08-28

Working tree limpo. `main` está **5 commits à frente de `origin/main`** — nada
foi empurrado, e empurrar é decisão do usuário.

| Commit | O quê |
|---|---|
| `3076e54e` | Onda 0 — identidade multi-aba, `Live.Surface`, `/play/:game` |
| `f0898719` | Onda 1 — `ShareLinks`, `/join/:slug`, `App.ReturnTo` |
| `ba197d38` | Onda 1 — o card na conversa |
| `b33e0963` | Onda 1 — traduções do domínio `share` nos 13 locales |
| `7dc8245a` | Onda 2 — passo 0: `App.GroupCallShape` extraído |

| Onda | Estado |
|---|---|
| 0 — identidade + `/play` | ✅ fechada |
| 1 — `/join/:slug` + card | ✅ fechada |
| 2 — conferência | 🔨 **um terço**: normalizadores extraídos |
| 3–6 | ⬜ |

**O que já dá para testar à mão:** entrar no chat com nick registrado, abrir
Retro Games, escolher um jogo, **Share**, colar a URL numa conversa (vira card),
abrir o link noutro navegador sem sessão, **Conectar e entrar**, cair no jogo. E
`/chat` numa aba convive com `/play/hex_pong` noutra.

---

## 3. O próximo passo, concreto

**Onda 2, passo 1: separar o read-model de canal do estar-dentro.**

`live/chat_live/group_call_events.ex` tem 2.346 linhas e 87 `handle_event`. Duas
metades convivem ali:

* **fica no `ChatLive`** — saber que existe uma chamada: `rehydrate/1` (a parte
  dos summaries), `refresh_channel_call_state/2`, `mark_channel_call_active/3`,
  `mark_channel_call_inactive/2`, e os assigns `@group_call_channels` e
  `@group_call_channel_summaries`.
* **vai para o `CallLive`** — estar dentro: `@group_call`, mídia, layout, foco,
  reações, screen share, stats, pré-join, os diálogos de confirmação.

**A régua:** se o dado só existe enquanto você está na chamada, ele vai; se
existe para quem só está olhando o canal, ele fica.

Chamadores externos que precisam continuar funcionando (mapeados):

```
live/app/chat_live.ex:194            GroupCallEvents.rehydrate/1
live/app/chat_live.ex:783,854        dispatch de handle_event (2 registros)
live/chat_live/keyboard_events.ex:101 delega um atalho
live/chat_live/pubsub_handlers/channel_state.ex:89,343,353,370
                                     leave_channel_call, mark_channel_call_*
live/chat_live/helpers/channel.ex:86 refresh_channel_call_state
```

**Passo 2 (depois):** criar `RetroHexChatWeb.App.CallLive` e montá-lo **aninhado**
na janela `group-call` do chat via `live_render/3`, exatamente como o `PlayLive`
faz hoje (`live/app/chat_live.html.heex`, procurar `retro-games-live`). Nada
muda para o usuário; é o passo reversível.

**Passo 3:** a rota `/call/:token`. **Só aqui** aparece a necessidade da
filiação a canal com contagem de superfícies (onda 2 §2.6) — no modo aninhado a
chamada morre com o chat, então o problema não existe ainda.

---

## 4. Três coisas que vão te morder na onda 2

1. **Identificação é um assign do `ChatLive`, não fato do domínio.** O portão da
   conferência é `session.identified` (`group_call_events.ex`, `require_identified`).
   Uma aba de chamada não tem como lê-lo. Três caminhos possíveis estão nos
   riscos da [onda 2](wave-2-conference-surface.md); **nenhum foi decidido**.
   Decidir com o código na frente.

2. **A filiação a canal some quando o chat fecha.** `ChatLive.terminate/2` chama
   `cleanup_channels/2` (`chat_live.ex:303`), e a conferência exige ser membro
   para entrar (`group_call/policy.ex:35`) e para moderar. Desenho proposto:
   contagem de superfícies abertas por nickname, provavelmente um
   `Registry` com `keys: :duplicate` (ele já remove a entrada quando o processo
   morre, que é exatamente a semântica necessária).

3. **A suíte Playwright é só Chromium.** Trocar o host de uma chamada é a classe
   de mudança que quebra só o Firefox e passa no `make ci` — o
   `guide/webrtc-p2p.md` §8.6 documenta um caso que custou 13,2 s contra 2,1 s.
   Rodar um spec descartável em Firefox antes de fechar a onda.

---

## 5. Armadilhas desta sessão que já custaram tempo

**Sequência fixa antes do gate.** Caí três vezes na mesma:

```
mix format  →  make i18n.gettext.extract  →  make ci
```

`extract` vai **sempre**, inclusive quando "só movi código" — mover código muda
as referências `#:` do `.pot` e reprova `i18n Catalog Coverage`.

**Merge de gettext só em domínio com msgid novo ou removido.** Mesclar um
domínio que só tem drift de referência reescreve um arquivo por locale e o
fuzzy matching **inventa traduções erradas** — foi assim que `%{count} charts`
recebeu a tradução de `%{count} cores` em 9 locales. Recuperação:
`git stash push -- <paths>`, nunca `git checkout`.

**Um domínio gettext novo precisa ser semeado.** O script de merge casa `.po`
existente com `.pot` e pula um domínio inédito. Receita: copiar o bloco de
cabeçalho do `ui.po` de cada locale para o `<novo>.po`, mesclar, e **corrigir a
primeira linha de comentário**, que vem apontando para `ui.pot`.

**Toda rota pública vai dentro do laço de locales do router.** `/join/:slug`
nasceu só sem prefixo e deu `NoRouteError` em `/pt-BR/join/...`. Dezesseis testes
não pegaram porque todos construíam o caminho do mesmo jeito que o código.
`App.ReturnTo` e `ShareLinkRef` leem `SEO.localized_locale_segments/0` pelo mesmo
motivo.

**O exit code do `make ci` não é o do job em background.** Um `; grep` no fim da
cadeia devolve o status do `grep`. Ler `CI_EXIT` do log, sempre.

**`clipboard_copy` só existe no chat.** É tratado pelo `chat_viewport_hook`; um
`push_event` desses numa aba satélite não tem quem receba. Copiar de verdade
precisa de um hook agnóstico de superfície — a lib de coordenação da onda 6 é o
lugar.

---

## 6. Como o usuário quer que se trabalhe

Instruções dadas explicitamente nesta sessão, além do `AGENTS.md`:

* **Não parar para perguntar.** Implementar até haver algo que ele possa testar
  de ponta a ponta. Ele teve que repetir "prosseguir" quatro vezes; não repita
  isso.
* **Registrar progresso e aprendizados a cada iteração** no `PROGRESS.md`,
  incluindo os erros e como foram recuperados.
* **Tela nova ganha screenshot antes de dizer que fechou.** Regra criada depois
  de ele reclamar que o card estava "horrivelmente feio, sem ícones". Um spec
  Playwright descartável, ler as imagens, apagar o spec. Isso pegou dois defeitos
  que teste nenhum pegaria — a janela de altura zero e o card duplicado.
* **Commit direto na `main`**, com `git fetch` + `pull --ff-only` antes e
  staging de caminhos exatos. Push só quando ele pedir.

---

## 7. Comandos que você vai usar

```sh
make ci                      # gate final; ler CI_EXIT do log, não o do shell
mix test <arquivo>           # iteração
make e2e.catalog             # depois de criar spec Playwright com @flow

# E2E direcionado (nunca a suíte inteira):
MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 mix assets.build
lsof -ti:4003 | xargs kill -9
cd e2e && MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 \
  E2E_BASE_URL=http://localhost:4003 BASE_URL=http://localhost:4003 \
  PUBLIC_ORIGIN=http://localhost:4003 npx playwright test tests/<spec> --retries=0
```

---

## 8. O que continua em aberto para o usuário decidir

1. **Guest pass** — hoje o link carrega identidade da sala, nunca autorização
   (D1). Um link de conferência só funciona para quem já é membro do canal, o
   que limita muito o alcance social. Merece plano próprio, com moderação junto.
2. **Start menu nas satélites** — hoje toda tela do WM carrega a lista inteira,
   +177 nós por tela. `/play` nasceu sem taskbar nenhuma; decidir na onda 6.
3. **Rate limit de criação de share link** — deixado de fora de propósito: já
   existem três cópias da janela deslizante em ETS no repositório, e a quarta
   seria o fork que o Princípio XII proíbe. Entra junto com a extração da comum.
