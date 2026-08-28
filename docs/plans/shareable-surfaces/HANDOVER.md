# Handover — superfícies compartilháveis

Escrito em 2026-08-28 para retomar o trabalho com contexto zerado. Apagar
quando a onda 6 fechar.

---

## 1. Leia nesta ordem

1. [`README.md`](README.md) — a análise, as decisões travadas (P1–P7 produto,
   D1–D6 arquitetura) e o mapa das ondas.
2. [`ux.md`](ux.md) — **o desenho de todas as telas**. Quando uma onda e este
   arquivo discordarem, o arquivo está errado e é ele que muda primeiro.
3. [`PROGRESS.md`](PROGRESS.md) — treze iterações registradas, com os erros. Leia
   pelo menos as iterações 7, 8, 10 e 13: são armadilhas que vão voltar.
4. O arquivo da onda em que você vai mexer.

E antes de tocar código: `AGENTS.md`, `CLAUDE.md` e as regras em
`.claude/rules/` que o caminho do arquivo disparar.

---

## 2. Estado em 2026-08-28

Working tree limpo. `main` está **8 commits à frente de `origin/main`** — nada
foi empurrado, e empurrar é decisão do usuário.

| Commit | O quê |
|---|---|
| `3076e54e` | Onda 0 — identidade multi-aba, `Live.Surface`, `/play/:game` |
| `f0898719` | Onda 1 — `ShareLinks`, `/join/:slug`, `App.ReturnTo` |
| `ba197d38` | Onda 1 — o card na conversa |
| `b33e0963` | Onda 1 — traduções do domínio `share` nos 13 locales |
| `7dc8245a` | Onda 2 — passo 0: `App.GroupCallShape` extraído |
| `0b665bb2` | Onda 2 — passo 1: read-model de canal separado do estar-dentro |
| `5bb4091e` | Onda 2 — `CallLive` em dois hosts + `/call/:token` |

| Onda | Estado |
|---|---|
| 0 — identidade + `/play` | ✅ fechada |
| 1 — `/join/:slug` + card | ✅ fechada |
| 2 — conferência | 🔨 **quase**: falta só a filiação com contagem de superfícies |
| 3–6 | ⬜ |

**O que já dá para testar à mão:** entrar no chat com nick registrado, entrar
num canal, **Chamada** → a antessala abre *na janela* (não mais um diálogo) com
quem já está dentro; entrar; **Share** acima do painel cria o link; colar numa
conversa vira card; abrir o link noutro navegador sem sessão mostra o card
público ("Uma chamada em #canal · N pessoas agora"); com sessão e filiação, ele
leva a `/call/:token`, a conferência numa aba só dela. O resumo ao lado de
Chamada também tem **Abrir em uma aba**.

---

## 3. O próximo passo, concreto

**Onda 2, o que sobrou: a filiação a canal precisa sobreviver à aba do chat**
([onda 2 §2.6](wave-2-conference-surface.md)).

Hoje o problema ainda **não existe**: a chamada embutida é filha do `ChatLive`,
então ela morre junto. Ele nasce no momento em que alguém deixar `/call/:token`
aberto e fechar a aba do chat — `ChatLive.terminate/2` chama `cleanup_channels/2`
e a pessoa vira participante de uma sala de um canal do qual não é mais membro.
O `rejoin` depois de um reload é negado e a moderação fica indefinida.

O desenho está escrito na §2.6 e não mudou: contagem de superfícies abertas por
nickname (um `Registry` com `keys: :duplicate` remove a entrada quando o processo
morre, que é exatamente a semântica necessária), `cleanup_channels/2` só efetiva
a saída quando a última superfície fecha, e `/part` explícito continua imediato.
`Live.Surface` é onde o registro entra, porque é por onde toda superfície passa.

O teste que prova a onda, e que deve ser escrito primeiro e falhar:
**depois de fechar a aba do chat, o `rejoin` na chamada continua autorizado.**

Depois disso a onda 2 fecha e a onda 3 (space) reusa `Live.Surface`,
`CallLive.Host` e `Topics.channel_calls/1` inteiros.

---

## 4. O que ainda morde na onda 2

1. ~~**Identificação é um assign do `ChatLive`.**~~ **Resolvido** (iteração 13):
   `Services.NickServ.identified?/1` mantém o conjunto em runtime e o assign do
   chat é espelho dele, então a superfície pergunta ao domínio. Não é preciso
   token novo.

2. **A filiação a canal some quando o chat fecha.** Continua aberto — é o §3
   acima, e é a única coisa que falta na onda 2.

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
