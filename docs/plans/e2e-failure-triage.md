# Triagem das falhas do Playwright

Uma falha de e2e só vale alguma coisa depois de responder **onde** está o defeito.
Este documento classifica cada falha em uma de três categorias, com a evidência que
sustenta a classificação, para que cada uma seja atacada no lugar certo.

| | Categoria | O que significa | Onde se corrige |
|---|---|---|---|
| **P** | Produto | O teste está certo; o produto não faz o que ele afirma | `apps/` |
| **T** | Teste | O produto mudou de propósito; o teste ficou para trás | `e2e/` |
| **A** | Ambiente | O spec não consegue rodar nesse alvo por construção | `e2e/`, com guarda |

Uma falha marcada **T** nunca é "afrouxar a asserção". É reescrevê-la contra o
comportamento que o produto realmente tem hoje — se não houver comportamento
equivalente, a asserção volta como **P**.

## Como a lista foi produzida

Três execuções, nesta ordem:

1. **Suíte completa contra produção** (banco zerado) — 373 ✓ · 8 flaky · 60 ✘ de 447.
2. **Re-run só das 52 specs que falharam**, ainda em produção — 54 ✘ de 152.
   Isso descartou interferência da suíte longa: as falhas se repetem isoladas.
3. **As mesmas 52 specs, local**, para separar o que é específico de produção.

### Uma hipótese descartada, com prova

A primeira execução local rodou `npx playwright` direto, **sem `mix assets.build`
no `MIX_ENV=e2e`** — a armadilha do servidor :4003 servindo bundle velho. Como a
lista era dominada por comportamento de JS (mute, foco de diálogo, timestamp,
autocomplete, idle), "é tudo bundle velho" parecia a explicação óbvia.

Repeti a execução com o :4003 morto e os assets reconstruídos. O conjunto de
falhas voltou **idêntico** — os mesmos 34 testes, nome por nome:

```
$ diff rerun-local.failed.txt rerun-local2.failed.txt
IDÊNTICOS
```

Idêntico, e não apenas parecido, é o que fecha a questão: assets velhos nunca
foram fator. As falhas são reais.

## Placar

|  | falha em produção | falha local | leitura |
|---|---|---|---|
| **34** | ✘ | ✘ | reproduz na máquina — ciclo de correção curto |
| **20** | ✘ | ✓ | específico de produção — exige evidência de servidor antes de tocar em código |
| **0** | ✓ | ✘ | — |

Zero falhas só-locais. O conjunto local é subconjunto estrito do de produção, o
que dá confiança na matriz: não há ruído de máquina inflando a lista.

Falhar **só em produção** é o caso que exige Grafana na janela exata do teste
antes de qualquer diagnóstico. Falhar nos dois é onde começar.

---

# Famílias

Seis famílias cobrem 23 falhas com seis causas raiz. Nenhuma delas apareceu por
leitura da mensagem de erro: todas exigiram abrir o produto e comparar com o que o
spec afirma. É por isso que a triagem tem que ser individual — a mensagem de erro
diz onde o teste parou, nunca por quê.

Somando as famílias e os oito casos isolados adiante, **31 das 54** estão
classificadas com evidência. As 24 restantes estão listadas no fim, com o sintoma
capturado e sem categoria — porque eu ainda não as medi.

## F1 · `localStorage` que o produto não usa mais — **T**

**Sintoma:** `Expected: "true" · Received: null`, e variantes.

**Evidência:** o cliente não usa `localStorage` em lugar nenhum. A única ocorrência
da palavra em todo o bundle é um comentário dizendo exatamente isso:

```
apps/retro_hex_chat_web/assets/js/lib/notifications/toast.js:6
 * No localStorage access — used by ContextualTipsHook for rendering.
```

As cinco chaves que a suíte ainda interroga têm **zero** ocorrências em `apps/`:

| Chave | Specs que dependem dela |
|---|---|
| `retro_hex_chat_mute` | `chat-local-storage-isolation` (AA8), `chat-sound-settings` (U4), `chat-statusbar` (O19) |
| `retro_hex_chat_history` | `chat-command-history-sensitive` (Q9) |
| `retro_hex_chat_recent_commands` | `chat-command-history-sensitive` (Q10) |
| `rhc_reconnect_state` | `chat-reconnect` (P8), `chat-unicode` (R5) |
| `retro_hex_chat_tips_suppressed` | — |

A persistência foi para o backend (`78ef0529 Move client persistence to backend`).
O comportamento continua existindo; o **mecanismo** que os testes espiavam, não.

No caso do `rhc_reconnect_state` dá para apontar o dedo na linha exata: o hook
recebe o estado do servidor e o guarda **em memória**, nunca em disco —

```js
this.handleEvent("save_reconnect_state", (data) => {
  this._reconnectState = data && typeof data === "object" ? data : null;
});
```

— enquanto P8 e R5 giram num `waitForFunction` esperando a chave aparecer no
`localStorage`. Eles não falham por asserção: estouram o timeout esperando algo
que nunca vai acontecer.

### O agravante: um teste de segurança verde por vacuidade

`Q9` afirma que segredos não vazam para o histórico:

```ts
expect(snapshot.history).not.toContain(secret);
```

`snapshot.history` é sempre `""`. A asserção passa porque não há nada onde
procurar. **Esse teste está verde e não prova nada** — a proteção de comandos
sensíveis não está coberta por ninguém hoje.

**Correção:** reescrever cada asserção contra o comportamento observável — mute
sobrevive ao reload e não vaza entre contextos; o histórico recupera o comando
seguro e recusa o sensível — em vez da chave de storage. Q9 volta a ter conteúdo.

## F2 · Specs que semeiam o banco local — **A**

**Sintoma:** `msg-1000` nunca aparece; timeout de 30 s.

**Evidência:** `helpers/seedHistory.ts` escreve as linhas por `mix run` com
`MIX_ENV=e2e`, ou seja, **no banco local**, enquanto o browser fala com produção.

```ts
spawnSync("mix", ["run", "--no-start", "-e", expression], {
  cwd: repoRoot, env: { ...process.env, MIX_ENV: "e2e" },
});
```

Atinge `chat-scrollback-audit` (3 testes).

**Correção:** guarda com `isLocalTarget()` — o spec **pula** com motivo declarado
em vez de falhar. Um spec que não pode rodar num alvo e falha silenciosamente ali
é pior que um spec ausente: consome uma vaga na lista de defeitos.

## F3 · Specs que dependem da API só-de-e2e — **A**

**Sintoma:** `Expected: 200 · Received: 404`, `response.ok()` falso.

**Evidência:** as rotas são compiladas condicionalmente e não existem em produção:

```elixir
if Application.compile_env(:retro_hex_chat, :e2e_fault_injection?, false) do
  post "/e2e/channel-messages", E2EController, :create_channel_message
```

Atinge `chat-rss-link-preview-visual` (2) e `chat-call-fault-injection:545`.

**Correção:** mesma guarda de F2.

## F4 · Endpoint de storage cravado em `localhost:3900` — **A**, com upgrade possível

**Sintoma:** `page.waitForResponse: Timeout` no upload.

**Evidência:** `chat-attachments` espera o PUT presignado num host literal:

```ts
response.url().includes("localhost:3900/retrohexchat-uploads/")
```

**Correção:** casar por `retrohexchat-uploads/` + método `PUT`, sem o host. Isso é
melhor que uma guarda: o spec passa a cobrir upload **também** em produção, que é
justamente onde o storage tem configuração própria.

## F5 · `/whois` e `/whowas` saíram da lista de mensagens — **T**

**Sintoma:** `element(s) not found` procurando texto de whois dentro de
`chat-message-list`. Cinco specs, uma causa.

**Evidência:** o resultado não é mais uma linha de texto no chat. Ele abre uma
janela e vira um cartão:

```elixir
defp deliver_card(socket, result) do
  socket
  |> assign(lookup_result: result)
  |> Windows.open("user-lookup")
end
```

Só o **erro** ainda vai para a lista de mensagens (`{:error, message} ->
Messages.system_event(...)`). O sucesso vai para `data-testid="lookup-result-card"`
em `user_lookup_dialog.ex`, onde cada linha renderiza como `{row.label}:`.

| Spec | O que procura na lista de mensagens |
|---|---|
| `chat-idle` P11 | `Idle for: 1 minute` |
| `chat-idle-passive` W11 | `Idle for: 1 minute` |
| `chat-whowas-edges` W6 | `----- Whowas: <nick> -----` |
| `chat-away-advanced` J13 | `Away: <mensagem>` |
| `chat-security-escaping` R2 | texto de away/bio escapado |

Isto responde a dúvida que eu havia deixado em aberto sobre o par idle/whowas: a
linha `Idle for` **é** incondicional em `format_whois_result/3`, e continua sendo —
ela só não está mais onde o spec olha. Nenhum defeito de produto aqui.

**Correção:** apontar os cinco specs para a janela User Lookup. R2 em particular
precisa continuar provando escape de HTML — no cartão, que é a superfície real
hoje.

⚠️ Note o contraste com `chat-ui-features-shell` Feature 10, que já usa a
superfície nova (`lookup-result-card`) e mesmo assim falha **só em produção**.
Essa continua na lista de investigação, e agora é mais interessante: é a única
evidência de que a janela de lookup pode estar com problema real em produção.

## F6 · O estado de desconexão não chega à interface — **P (candidata), a medir**

Quatro testes independentes morrem no mesmo tema, e nenhum deles chega a testar o
que se propõe porque a UI nunca entra em estado desconectado:

| Spec | O que não acontece |
|---|---|
| `chat-admin-reconnect-edges` AA5 ×2 | `connection-banner--visible` |
| `chat-reconnect` P9 | `reconnect-overlay--visible` |
| `chat-reconnect-shell` T12 | menus destrutivos ficam `aria-disabled="false"` |

Todos derrubam a rede por `context.setOffline(true)`. O hook tem o caminho certo —
`window.addEventListener("offline", …)` → `_handleConnectionLost()` → o state
machine aplica as classes. Então ou o evento `offline` não chega, ou o hook não
está montado quando chega.

**Não classifico sem medir.** Se o hook não estiver carregando, é **P** e vale por
quatro; se `setOffline` não disparar o evento no Chromium headless, é **T** e os
quatro specs precisam de outro gatilho. Uma medição decide os quatro.

---

# Defeitos de produto confirmados

## P1 · `/p2p` é o único comando sem "Examples" na ajuda — **P**

`chat-command-registry` (Q2) percorre todo comando registrado e exige `Syntax`,
`Examples` e `Open in Help Topics` no cartão de ajuda inline. Morre no 35º.

**Evidência — varredura de todos os tópicos de comando:**

```
$ for f in cmd_*.heex; do grep -q "Examples" $f || echo "NO EXAMPLES: $f"; done
  NO EXAMPLES: cmd_p2p.html.heex
```

Um, exatamente um. O `AGENTS.md` trata ajuda desatualizada como defeito; este é o
caso mais limpo possível: o teste está certo e a lacuna é de uma seção num arquivo.

**Onde corrigir:** `controllers/help_content/cmd_p2p.html.heex`.

## P2 · O remount frio repete a sequência de login — **P**

`chat-deploy-reconnect` (BA2) recarrega a página e exige que a saudação não volte:

```ts
await expect(page.getByText(/You are now identified as/i)).toHaveCount(0);
// Received: 2
```

Não só volta como aparece **duas** vezes. O spec documenta o defeito no próprio
corpo ("The bug: a reconnect is NOT seamless"), então isto é regressão ou correção
que nunca chegou. O caminho é `maybe_start_nickserv_timer/4` e seu parâmetro
`quiet`, que existe exatamente para suprimir a saudação num reconnect.

**Onde corrigir:** `live/chat_live/helpers/session.ex`.

## P3 · `/ns` ganhou subcomandos; a mensagem de uso não foi atualizada no spec — **T**

```
produto: Usage: /ns <register|identify|ghost|info|drop|devices|sessions|revoke-device|kill-session|help> [args]
spec:    Usage: /ns <register|identify|ghost|info|drop|help> [args]
```

O produto está certo — os subcomandos existem. `chat-command-surface` (G2) é que
não acompanhou.

## P4 · `/bot` virou administrativo; o spec testa a regra antiga — **T**

`chat-bots` (M14) chama-se *"non-admin /bot lists bots"*. O produto recusa:

```elixir
def execute(args, context) do
  with :ok <- Policy.authorize(context), do: run(args, context)
end
```

E a documentação do próprio produto diz que isso é intencional, sem margem:

> "Every subcommand is administrative, including the ones that only read: running
> /bot with no arguments opens Bot Management, and anyone else is refused."
> — `help_content/bot_command.html.heex`

O teste precisa mudar de nome e de premissa: um não-admin deve ver a **recusa**.

## P5 · A boas-vindas não sobrevive a um `/part` seguido de `/join` — **T**

Eu classifiquei este como defeito de produto provável. Medindo, não era.

`chat-channel-welcome` (H9) recebia zero onde esperava uma linha. O primeiro
suspeito era um catch-all silencioso no caminho:

```elixir
rescue
  _ -> socket
end
```

Ele saiu — o `AGENTS.md` o proíbe, e `GenServer.call` a um processo ausente sai
por `exit`, que `rescue` nem pega, então ele nunca fez o que aparentava fazer.
Mas a falha continuou, e sem erro nenhum no servidor.

O log de dentro do `/join` contou a história:

```
51.854  join   → a boas-vindas aparece; as duas primeiras asserções passam
52.106  part   ← do próprio teste
52.346  join   → o viewport é reconstruído do histórico
```

A asserção que falhava era a **última**, depois de sair e voltar. A saudação é
dita a uma pessoa, não escrita no canal: ela não está no histórico que o rejoin
carrega. Zero não era "nunca apareceu" — era "não foi repetida", que é
exatamente a regra sob teste.

O spec agora afirma isso: aparece uma vez ao entrar, e **não** reaparece ao
voltar. Para que essa ausência signifique algo, o canal ganha uma mensagem
guardada antes, e o rejoin tem de mostrá-la — senão a ausência passaria num
canal vazio.

Efeito colateral: **H10 deixou de ser um teste vazio.** Ele nega que a
boas-vindas apareça depois de `/clearwelcome`, e passava porque ela nunca
aparecia; agora H9 prova, no mesmo arquivo, que o mecanismo funciona.

---

# O padrão que essa triagem expôs: testes verdes por vacuidade

Uma asserção negativa estava passando porque o que ela nega nunca existia:

| Teste | Afirma | Por que passa |
|---|---|---|
| `chat-command-history-sensitive` Q9 | segredos não estão no histórico | o histórico lido é sempre `""` (F1) |

O par positivo do mesmo arquivo era justamente o que falhava. Isso é o pior
tipo de cobertura: **verde, e apontando para o lado errado**. Uma asserção
negativa só vale acompanhada da positiva correspondente no mesmo cenário — se a
positiva morre, a negativa deixa de significar qualquer coisa e ninguém percebe.

Vale varrer o resto da suíte atrás de `not.toContain` / `toHaveCount(0)` sem par
positivo. Não fiz essa varredura ainda.

---

# Falhas ainda sob investigação

Estas têm o sintoma capturado e a evidência do servidor **ainda não** colhida. Não
as classifico sem isso; chutar categoria aqui seria exatamente a preguiça que este
documento existe para evitar.

## Só em produção — 10 (exigem Grafana na janela do teste)

| Spec | Sintoma |
|---|---|
| `chat-command-history` G9 | input retém `/ns identify <segredo>` — **prioridade** |
| `chat-channel-central` I18 | checkbox `Moderated (+m)` fica desmarcada após editar |
| `chat-channel-modes` I14 | contexto fechado no meio (`/slow`) |
| `chat-group-call:1717` | botão de pin não reflete estado |
| `chat-nickserv` K5 | nick não aparece na nicklist após troca |
| `chat-notify` J15 | contexto fechado no meio |
| `chat-system-windows:287` | aviso `system-log-unreachable` ausente |
| `chat-ui-features-shell` Feature 10 | `lookup-result-card` não aparece |
| `i18n:113` | item de menu `ja` não clicável no chat (existe no `/connect` — verificado por HTTP) |
| `space-virtual-pad` | 0 frames `space_input` enviados |

`G9` é o primeiro da fila: um comando sensível permanecendo no campo de entrada é
o mesmo assunto que a família F1 deixou de cobrir, e o único desta tabela com
consequência de segurança.

## Nos dois ambientes — 13

| Spec | Sintoma |
|---|---|
| `chat-persistence` P1 | abas de PM não restauram após novo login |
| `chat-timer-error-edges` Y7 | erro de timer não emitido (a string existe no produto) |
| `chat-chanserv-transfer-persistence` X7 | nicklist não traz o nick transferido |
| `chat-conversations-sidebar:100` | item de canal popular não aparece |
| `chat-bot-persistence` Y4 | rótulo `Status:` ausente na janela de bots |
| `chat-dialog-keyboard` T8 | foco escapa do diálogo com Tab |
| `chat-trusted-terminals-pagination` | botão "carregar mais" existe no DOM, porém `hidden` |
| `chat-ui-features-channel` Feature 06 | `sets mode +i` não aparece |
| `chat-rate-limit` R9 | convite de P2P não confirmado |
| `chat-p2p:664`, `chat-p2p:763` | tela compartilhada e modo mini |
| `chat-group-call:1275`, `chat-call-fault-injection:348` | mídia/WebRTC |

`Y7` tem a string esperada **presente no produto** (`timer_handlers.ex:71`). Não é
texto trocado: é o caminho que não chega a emiti-la — a mesma forma de P5, e o
mesmo motivo para desconfiar de um `rescue` no caminho.

Os cinco de mídia (P2P, group call, fault injection) provavelmente compartilham
causa e devem ser investigados como bloco, não um a um.

## `chat-persistence` P1 merece nota à parte

As abas de PM não voltam depois de sair e entrar de novo. Rastreei o caminho:
`restore_pm_conversations/2` popula `session.pm_conversations`, que alimenta a
**barra lateral**; a barra de abas lê `open_pm_tabs`, que monta vazia e só é
preenchida por mensagem que chega ou por restauração de reconnect.

Este é o teste que mais se aproxima do que eu mexi no passo 3 (entrega de PM), e
por isso é o que eu menos quero classificar por dedução. Precisa do teste dirigido.

## Os quatro flaky de produção

Passaram na segunda tentativa, o que os mantém fora da contagem de falhas — e é
justamente o que os torna fáceis de ignorar até virarem falha permanente:

| Spec | O sintoma da primeira tentativa |
|---|---|
| `chat-sound-settings` U3 | escolheu "Beep", o campo ficou "Alert" |
| `chat-channel-modes` I9 | `Channel is full (+l)` não apareceu |
| `chat-rate-limit` R9 | placeholder do input não seguiu a troca de canal |
| `chat-ui-features-shell` Feature 07 | botão de enviar continuou desabilitado |

O primeiro é o mais preocupante: **selecionar um valor e receber outro** é a mesma
classe do bug do seletor de cores que já corrigimos hoje — um controle cujo valor
depende de uma ida ao servidor. Vale olhar antes de virar vermelho.

---

# Ordem de ataque

1. **F2, F3, F4** — guardas de alvo e um casamento de URL. Barato, e tira 8 falhas
   estruturais da frente, que hoje escondem defeito real atrás de ruído.
2. **Os `T` de uma linha** — P3 (`/ns`), P4 (`/bot`), P6 (locator), P7 (colchetes),
   P8 (menu Find). Cinco specs que só precisam contar a verdade atual.
3. **P1 (`/p2p` sem Examples)** — defeito de produto, um arquivo, e a regra de
   ajuda obrigatória do `AGENTS.md` cobra isso.
4. **F5** — reapontar cinco specs de `/whois`/`/whowas` para a janela User Lookup,
   mantendo o que R2 prova sobre escape de HTML.
5. **F1** — reescrever as asserções de storage contra comportamento observável, e
   devolver conteúdo ao Q9, que hoje passa vazio.
6. **P5 (boas-vindas)** — remover o `rescue` primeiro, medir depois. E rever H10,
   que passa por vacuidade enquanto isso.
7. **P2 (saudação duplicada)** e **G9 (comando sensível no input)** — os dois com
   consequência direta para quem usa.
8. **F6** — uma medição decide quatro testes de uma vez.
9. As 23 restantes, uma a uma, medindo antes de classificar. Os cinco de
   mídia como bloco.

Nada aqui deve ser "ajustado até passar". Um spec que muda de categoria durante a
correção — de `T` para `P` — é o caso mais valioso da lista, não um contratempo.
