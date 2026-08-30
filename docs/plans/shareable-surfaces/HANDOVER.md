# Handover — superfícies compartilháveis

Escrito em 2026-08-28, atualizado em 2026-08-30 para retomar o trabalho com
contexto zerado. Apagar quando a onda 6 fechar.

---

## 1. Leia nesta ordem

1. [`README.md`](README.md) — a análise, as decisões travadas (P1–P7 produto,
   D1–D6 arquitetura) e o mapa das ondas.
2. [`ux.md`](ux.md) — **o desenho de todas as telas**. Quando uma onda e este
   arquivo discordarem, o arquivo está errado e é ele que muda primeiro.
3. [`PROGRESS.md`](PROGRESS.md) — quinze iterações registradas, com os erros.
   Leia pelo menos as iterações 7, 8, 10, 13, 14 e 15: são armadilhas que vão
   voltar.
4. O arquivo da onda em que você vai mexer.

E antes de tocar código: `AGENTS.md`, `CLAUDE.md` e as regras em
`.claude/rules/` que o caminho do arquivo disparar.

---

## 2. Estado em 2026-08-30

Working tree limpo. `main` está **à frente de `origin/main`** — nada foi
empurrado, e empurrar é decisão do usuário.

| Commit | O quê |
|---|---|
| `3076e54e` | Onda 0 — identidade multi-aba, `Live.Surface`, `/play/:game` |
| `f0898719` | Onda 1 — `ShareLinks`, `/join/:slug`, `App.ReturnTo` |
| `ba197d38` | Onda 1 — o card na conversa |
| `b33e0963` | Onda 1 — traduções do domínio `share` nos 13 locales |
| `7dc8245a` | Onda 2 — passo 0: `App.GroupCallShape` extraído |
| `0b665bb2` | Onda 2 — passo 1: read-model de canal separado do estar-dentro |
| `5bb4091e` | Onda 2 — `CallLive` em dois hosts + `/call/:token` |
| `8bf8b202` | Onda 2 — filiação com contagem de superfícies; onda 2 fechada |
| (este) | Onda 3 — `SpaceLive` em dois hosts, `/space/:slug`, roster na antessala |

| Onda | Estado |
|---|---|
| 0 — identidade + `/play` | ✅ fechada |
| 1 — `/join/:slug` + card | ✅ fechada |
| 2 — conferência | ✅ fechada |
| 3 — space | ✅ fechada |
| 4 — P2P channel + superfície | ⬜ **próxima** |
| 5–6 | ⬜ |

**O que já dá para testar à mão:** tudo o que a onda 2 entregava, mais — entrar
num canal, abrir a aba **Space**, e no seletor de personagem ver **quem está lá
dentro agora**, **Compartilhar** (que cria o link) e **Abrir em uma aba**. A aba
própria é `/space/<slug>`: o mapa ocupa a janela inteira, sem botão de tela cheia
(a página já é), com `← Chat` e a contagem na barra de status. O link colado numa
conversa vira card, e aberto sem sessão mostra o card público ("O espaço de
#canal · N pessoas agora").

---

## 3. O próximo passo, concreto

**Onda 4 — P2P vira channel e ganha superfície**
([`wave-4-p2p-channel-and-surface.md`](wave-4-p2p-channel-and-surface.md)).

Esta é a onda cara, e é por isso que ela ficou por último entre as features: a
sinalização do P2P mora dentro do `ChatLive`, em
`live/chat_live/p2p_session_events.ex` (2.258 linhas), e **tirar o P2P da aba
exige antes mover a sinalização para um channel cru** (D3). Conferência e space
já entravam assim; o P2P não.

A ordem que as ondas 2 e 3 ensinaram, aplicada aqui:

1. **Primeiro o transporte, sozinho e verde.** `P2PChannel` com token assinado,
   com o `ChatLive` ainda como único cliente. Nada de UI nesse passo.
2. **Depois o read-model:** o que fica no chat é *saber que existe uma sessão*
   (o glifo na aba de PM, o badge na sidebar); o que vai é tudo o que só existe
   enquanto você está na chamada.
3. **`P2PLive` nos dois hosts de uma vez.** A antessala aqui é uma **sala de
   partida** (P1/P7): tem host, `[Pronto]` e `[Iniciar]`, e é a primeira do
   plano que é uma entidade persistida — o `RetroHexChat.Lobby` que já existe.
4. **A rota `/p2p/:token`** e o `kind: "p2p"` ligado no `JoinLive` (o domínio já
   aceita o kind; falta `surface_path/1` e o subject).

### O que já está pronto e não se reinventa

* `RetroHexChatWeb.Live.Surface` — nickname, ban, tópico de superfícies, e o
  registro em `RetroHexChat.Surfaces` que mantém a filiação a canal viva.
* `RetroHexChatWeb.CallLive.Host` e o padrão dos três desvios entre hosts. **A
  onda 3 decidiu não promovê-lo** (§7 da onda 3): o space não tinha nenhum dos
  três desvios, então um módulo compartilhado teria um usuário. O P2P **tem** os
  três (aviso, janela, e o que o chat desenha), então é aqui que a decisão se
  paga — com três pontos de dado em vez de dois.
* `RetroHexChatWeb.ChatLive.SpaceEvents` — o padrão menor, para uma superfície
  que só precisa mandar duas mensagens para cima.
* `RetroHexChatWeb.SpaceRef` — como um id vira segmento de caminho **e** id de
  elemento, numa codificação só.
* `Topics.channel_calls/1` e `Topics.space_roster/1` — o precedente, agora com
  dois casos: um tópico pequeno para quem só desenha uma lista, publicado do
  único ponto por onde a mudança já passava.

### As coisas que vão se repetir

* **`live_render/3` embrulha o filho numa div sem altura.** Passe
  `container: {:div, class: …}` com a cadeia de flex/altura que o pai espera.
* **Dois hosts na tela ao mesmo tempo precisam de ids diferentes.**
* **Um clique num filho tem que ser mirado no filho.** `has_element?(pai, …)`
  enxerga o markup do filho, mas `render_click(pai, …)` não chega aos handlers
  dele — pegue o `live_children/1` do módulo.
* **Um merge de gettext inventa tradução por fuzzy mesmo dizendo "0 fuzzy".**
  Na onda 3, `A space on RetroHexChat` veio traduzido como "Um jogo no
  RetroHexChat" em 13 locales, com a flag `fuzzy`. Depois de todo merge:
  `grep -c ', fuzzy'` nos arquivos tocados e conferir cada um.

---

## 4. O que ainda morde

1. ~~**Identificação é um assign do `ChatLive`.**~~ **Resolvido** (iteração 13):
   `Services.NickServ.identified?/1` mantém o conjunto em runtime e o assign do
   chat é espelho dele, então a superfície pergunta ao domínio. Não é preciso
   token novo.

2. ~~**A filiação a canal some quando o chat fecha.**~~ **Resolvido**
   (iteração 14): `RetroHexChat.Surfaces` conta as superfícies abertas por
   nickname e o chat entrega a saída dos canais quando não é a última. Duas
   coisas para não reaprender: um `live_render/3` aninhado **não** passa pelo
   `on_mount` do `live_session`, então a janela do chat não é uma superfície; e
   um chat que quebra nunca entrega nada, o que está escrito no `@moduledoc` em
   vez de corrigido.

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

**Dois testes Playwright já estavam vermelhos antes desta sessão**, e o
`surface_snapshot.sh --check` também. Verificado com `git stash`: falham iguais
no `HEAD` anterior. Playwright não está no `make ci`, então a suíte derivou —
não perca tempo achando que foi você.

**`live_render` embrulha o filho numa div sem altura.** Um `h-full` dentro dela
resolve contra ela, não contra o corpo da janela: passe
`container: {:div, class: "h-full min-h-0"}`. Nenhum teste vê isso; só o
screenshot.

**Dois hosts renderizando o mesmo LiveComponent precisam de ids diferentes.**
Ids são únicos no documento, não por LiveView, e a chamada embutida põe os dois
na tela ao mesmo tempo. Derive os `data-testid` internos do `id` em vez de
escrevê-los literais.

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
  Playwright descartável, ler as imagens, apagar o spec. Já pegou quatro defeitos
  que teste nenhum pegaria — a janela de altura zero, o card duplicado, a
  antessala ocupando metade da janela e a barra Share solta no canto.
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

---

## 9. O prompt para abrir a próxima sessão

Cole isto numa sessão com o contexto limpo. Ele é curto de propósito: o que ele
precisa dizer está neste arquivo, e o resto é a ordem de leitura.

```
Retomando a implementação do plano de superfícies compartilháveis no
retro_hex_chat. A onda 3 fechou; começa a onda 4.

Leia, nesta ordem:
1. docs/plans/shareable-surfaces/HANDOVER.md  — estado, próximo passo, armadilhas
2. docs/plans/shareable-surfaces/README.md    — decisões travadas (P1–P7, D1–D6)
3. docs/plans/shareable-surfaces/ux.md        — o desenho de todas as telas
4. docs/plans/shareable-surfaces/wave-4-p2p-channel-and-surface.md
5. docs/plans/shareable-surfaces/PROGRESS.md  — pelo menos as iterações 7, 8,
   10, 13, 14 e 15: são armadilhas que vão voltar

O próximo passo está na seção 3 do HANDOVER. A onda 4 é a cara: a sinalização
do P2P vive dentro do ChatLive e precisa virar um Phoenix Channel cru ANTES de
qualquer superfície. Faça nesta ordem: transporte sozinho e verde, depois o
read-model de conversa, depois P2PLive nos dois hosts de uma vez (a antessala
é sala de partida: host, Pronto, Iniciar, sobre o Lobby que já existe), depois
a rota /p2p/:token e o kind "p2p" no JoinLive.

Como trabalhar, e isto não é negociável:
- Não pare para pedir permissão entre passos. Implemente até haver algo
  testável de ponta a ponta pelo usuário.
- Registre cada iteração no PROGRESS.md, incluindo os erros e como foram
  recuperados.
- Toda tela nova ganha screenshot (spec Playwright descartável) antes de
  você dizer que fechou.
- Sequência fixa antes do gate: mix format → make i18n.gettext.extract →
  make ci. Leia o "Results:" do log, não o exit code do shell.
- Commit direto na main, com fetch + pull --ff-only antes e staging de
  caminhos exatos. Não faça push.
```
