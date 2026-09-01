# Handover — superfícies compartilháveis, do estado atual até o fim

Escrito em 2026-09-01 por quem auditou o plano e implementou as fases A–F da
onda 7. Para uma sessão com o contexto zerado.

**Apagar quando a onda 8 fechar** — junto com os outros três (decisão **Q12**).

---

## 0. Em uma tela

Um plano de seis ondas deu endereço próprio a conferência, space, P2P e jogos.
Foi declarado fechado. Uma auditoria independente achou **quinze** coisas além
das oito que o próprio autor tinha listado. A onda 7 consertou a maioria. Falta
**uma entrega** e **uma lista de acabamento**, e as doze ambiguidades que
sobravam já foram decididas.

| Onde | O quê |
|---|---|
| `shareable-surfaces-audit.md` | os achados, com evidência reproduzível e **três correções minhas** onde eu estava errado |
| `shareable-surfaces-wave-7.md` | o plano dos consertos; **§8 tem as 12 decisões travadas e a ordem de trabalho** |
| `shareable-surfaces-wave-7-progress.md` | o diário, com os erros e as armadilhas |
| `shareable-surfaces-wave-8.md` | o card ao vivo — a última entrega |

O desenho original foi apagado de propósito e vive no git:

```sh
mkdir -p /tmp/plan && for f in README ux wave-1-join-resolver wave-5-games-surfaces \
  wave-6-cross-tab-and-bundle; do
  git show 9620e81b^:docs/plans/shareable-surfaces/$f.md > /tmp/plan/$f.md
done
```

`ux.md` é a fonte da verdade sobre as telas. `README §3` tem `P1`–`P7` (produto)
e `§4` tem `D1`–`D6` (arquitetura). **Nenhuma delas foi reaberta** e nenhuma deve
ser sem escrever o porquê.

---

## 1. Leia nesta ordem

1. **`shareable-surfaces-wave-7.md` §8** — as doze decisões e a ordem de
   trabalho. É o que manda.
2. **`shareable-surfaces-wave-7-progress.md`** — o que já aconteceu e onde estão
   as armadilhas. Comece pela seção "Armadilhas para a próxima sessão".
3. **`shareable-surfaces-audit.md`** — só quando precisar do detalhe de um `R.n`
   específico. É longo e a maior parte já está fechada.
4. **`shareable-surfaces-wave-8.md`** — quando chegar no item 7 da ordem.

---

## 2. O que falta, na ordem decidida

| | O quê | Decisão |
|---|---|---|
| 1 | Os três specs vermelhos: o answerer que recarrega, e os dois de pré-join | **Q2, Q3** |
| 2 | O spec "a mesma chamada duas vezes" + reescrever os laços de `Process.sleep` | **Q9, Q10** |
| 3 | A zona de status do chat dizendo **onde** a superfície está aberta | **Q6** |
| 4 | Traduzir os 9 `msgid` restantes **e** pôr `i18n.catalog.check` no `make ci` | **Q7** |
| 5 | Checagem no `lint.hooks`: hook registrado tem que estar montado | **Q11** |
| 6 | Duas frases de decisão nos moduledocs (`SpaceRef`, `Slug`) | **Q4, Q8** |
| 7 | A onda 8, e então apagar os quatro documentos | **Q1, Q12** |

### O item 1 tem método obrigatório

**"Você precisa de testes Playwright e rodar tudo no navegador."** Isso foi dito
em resposta à minha proposta de investigar por leitura, e foi merecido: nesta
onda eu estimei um defeito pelos sintomas **três vezes** e errei as três. A única
vez que abri o navegador, achei três bugs empilhados numa tarde.

Os três vermelhos, com o que já se sabe:

* **`chat-call-fault-injection.spec.ts:355`** — a mídia não se restabelece quando
  o answerer recarrega no meio do offer inicial. A onda 4B registrou como
  limitação conhecida. Nenhuma investigação de fundo foi feita.
* **`chat-group-call.spec.ts:1273`** — depois de cancelar e reabrir o pré-join, a
  caixa do microfone volta marcada: a preferência de dispositivo não persiste. A
  sondagem morta do `localStorage` já foi removida; o vermelho abaixo dela é
  produto.
* **`chat-group-call.spec.ts:1340`** — a caixa de aviso de permissão aparece com
  o botão `Retry` e **texto vazio**. Rastreado até `_showWarning(message)`
  receber string vazia (`assets/js/lib/group_call/prejoin.js`), sem causa raiz.
  `mediaErrorMessage` devolve string para `NotAllowedError`, então a mensagem se
  perde entre uma coisa e outra.

Comando:

```sh
lsof -ti :4003 | xargs -r kill -9
MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 E2E_BASE_URL=http://localhost:4003 \
  BASE_URL=http://localhost:4003 PUBLIC_ORIGIN=http://localhost:4003 mix assets.build
cd e2e && MIX_ENV=e2e PGPORT=5433 E2E_PORT=4003 E2E_BASE_URL=http://localhost:4003 \
  BASE_URL=http://localhost:4003 PUBLIC_ORIGIN=http://localhost:4003 \
  npx playwright test tests/chat-call-fault-injection.spec.ts tests/chat-group-call.spec.ts \
    --retries=0 --project=chromium --reporter=line
```

Estado atual das suítes tocadas: **39 passam, 3 falham** (era 32/5).

---

## 3. O que a onda 7 consertou, para você não reabrir

* **Um `mount/3` de superfície não escreve no domínio.** Ele roda duas vezes e a
  primeira é um GET comum: um prefetch tomava o assento de uma partida **e**
  disparava o takeover de uma sessão viva.
* **O read-model do chat** parou de esconder a sessão P2P viva atrás de um link
  de partida recém-criado.
* **Ir para a aba que já existe** nunca tinha funcionado: a nota não existia no
  `← Chat`, o `SurfacePresenceHook` não estava montado em template nenhum, e
  `log.info` não existe no logger congelado — um `TypeError` dentro de um `.then`
  comia o resto do callback em silêncio.
* **A regra de privacidade de canal** virou `Channels.Visibility.nameable?/1`,
  com o `JoinLive` e o `SpaceLive` nela, e as meta tags do `/join` passaram a
  falar do link em vez do blurb genérico da landing.
* **Um endereço por sala**, `ShareLinks.Policy`, e o botão `Revoke` — a
  revogação existia no domínio e nunca tinha sido alcançável.
* **O convite P2P** parou de escrever `/lobby/<token>`, que descartava o token.

---

## 4. Onde eu errei, para você desconfiar dos lugares certos

Três correções estão escritas ao lado do texto errado, de propósito.

1. **"A vaga queimada nunca volta"** (R.1) — falso. O `SessionServer` agenda
   `:pending_expiry` em cinco minutos. Eu li a query da varredura e não o
   servidor, e a varredura era a única coisa que eu tinha olhado.
2. **"A janela maximizada cobre a barra de status, isso é produto"** (R.7) —
   falso. A barra é o rodapé da própria janela do chat; uma janela maximizada por
   cima dela é o gerenciador de janelas funcionando. O que mudou foi o fluxo.
3. **"Os dois specs de pré-join são bug de teste"** (R.13) — repeti o erro do
   autor original. A sondagem morta do `localStorage` era real, mas o vermelho
   por baixo dela é produto.

**O padrão nos três: eu afirmei a partir da única coisa que tinha olhado.** O
antídoto que funcionou foi procurar quem *mais* tem uma opinião sobre aquele
estado — e, no navegador, sondar em vez de teorizar.

---

## 5. Regras da casa que custaram caro aqui

* `make ci` é o único portão final. **Leia a linha `Results:`, não o exit code de
  um pipe.** Sequência antes de qualquer commit: `mix format` →
  `make i18n.gettext.extract` → `make ci`.
* Commit direto na `main`, com `git fetch` + `pull --ff-only` antes e staging de
  caminhos exatos. Mais de uma pessoa empurra em paralelo.
* **`live/2` sempre conecta** — um efeito no `mount/3` só aparece com `get/2`.
* **Um teste que afirma ausência é o mais fácil de escrever verde por acidente.**
  Reverta o conserto uma vez e veja ficar vermelho.
* **Um hook registrado não é um hook montado**, e nada reclama. Vira checagem no
  item 5 da ordem.
* `RetroHexChat.GroupCall.RuntimeTest` "join_call/5 reconnects a briefly
  disconnected participant" falha de forma intermitente e passa sozinho. Não é
  desta onda — não culpe a sua mudança antes de rodar de novo.

---

## 6. Estado

* `main` empurrada, 37 commits à frente do que havia antes desta sessão.
* `make ci` 17/17 com Dialyzer, árvore limpa.
* `make i18n.catalog.check` **reprova** — 9 `msgid` de outras features, item 4 da
  ordem.
* E2E das suítes tocadas: 39 verdes, 3 vermelhas (item 1 da ordem).
