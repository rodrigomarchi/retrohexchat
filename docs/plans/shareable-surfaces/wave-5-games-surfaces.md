# Onda 5 — jogos: o lobby aberto

**Depende de:** ondas 0 (solo já shippou lá), 1 e 4.

**Entrega:** `/play/:game/:token` para multiplayer, e — a mudança de produto mais
importante deste plano — **um lobby que não precisa saber o nome de quem vai
entrar**.

---

## 1. O buraco que só aparece quando você tenta compartilhar um jogo

Multiplayer hoje só existe dentro de uma sessão P2P, e uma sessão P2P só nasce
apontando para uma pessoa específica:

```
/p2p <nickname>                      commands/handlers/lobby.ex
  → alvo precisa estar registrado    resolve_registered_nick/1
  → alvo precisa estar online        validate_target_online/1
  → alvo precisa aceitar             convite por PM
Lobby.create_session(creator_id, peer_id)   ← peer_id é obrigatório
lobby_sessions.peer_id                       validate_required
```

Ou seja: **não existe hoje nenhuma forma de criar uma partida e convidar "quem
aparecer"**. Um link de jogo postado num canal ou numa rede social não tem para
onde apontar. Isso não é um problema de roteamento — é o modelo de domínio.

É exatamente o fluxo que você descreveu ("abrir a feature cria um link de lobby
para os usuários conectarem"), e ele não existe.

## 2. O que muda

### 2.1 Lobby aberto — sessão sem par até alguém reivindicar

1. `lobby_sessions.peer_id` passa a ser **nulo** enquanto a sessão está aberta.
   O `validate_required` sai do changeset de criação e entra na transição de
   reivindicação.
2. Status novo no início da máquina: `open`. A máquina fica
   `open → pending → lobby → connected → (closed | expired | failed)`, e `open`
   pode ir direto para `expired`. Os terminais e a exigência de `closed_at` +
   `closed_reason` não mudam (`lobby/schema/session.ex:76`).
3. `Lobby.Service.create_open_session/2` — cria com `peer_id` nulo, `expires_at`
   curto (um lobby aberto é um convite, não um endereço permanente) e o mesmo
   rate limit de criação que já existe.
4. `Lobby.Service.claim_open_session/2` — a reivindicação. Ela é a parte
   perigosa e precisa ser **uma escrita condicional no banco**, não um
   `read → check → write`:

   ```
   UPDATE lobby_sessions
      SET peer_id = $claimer, status = 'pending', accepted_at = now()
    WHERE token = $token AND peer_id IS NULL AND status = 'open'
   ```

   Zero linhas afetadas = alguém chegou primeiro. Este é o mesmo raciocínio que
   já fez a checagem de sessão duplicada ser uma query e não um lookup de
   Registry ([`guide/webrtc-p2p.md` §8.1](../../guide/webrtc-p2p.md)): o banco é
   quem sabe.
5. `Lobby.Policy.can_claim?/2` — não pode reivindicar o próprio link; bloqueio /
   ignore vale igual ao convite direto (o P2P já consulta
   `ignore_list_entries` direto, tipo `:all`); as mesmas exigências de registro
   e identificação que `/p2p` já impõe.

### 2.2 A sala de partida — o que o lobby aberto precisa guardar

Desenho: [`ux.md` §2.5](ux.md). É a única antessala do plano com estado
persistido (P1), e ela vive no `RetroHexChat.Lobby` que já existe — o que também
mantém honesta a frase do guia de que lobby é o domínio.

Em cima do lobby aberto da §2.1, três coisas a mais:

| Estado | Onde | Regra |
|---|---|---|
| host | `creator_id`, já existe | P7: host sai antes de iniciar → sala fecha, link morre |
| pronto por pessoa | `metadata`, mapa por `user_id` | `[Iniciar]` só habilita com as vagas mínimas prontas |
| iniciada | transição `pending → lobby` | depois disso, entra quem tiver vaga (P4) |

`[Pronto]` não é só um clique: ele significa *dispositivos/controles escolhidos e
canvas montado*, do mesmo jeito que na onda 4. Um `[Pronto]` que mente é uma
partida que começa com um dos lados sem hook.

Quem chega depois do início (P4): **entra se houver vaga**; se não houver, o card
do link diz "vaga preenchida". Um jogo 1v1 fica cheio no segundo jogador, e é
esse o caso comum — o card precisa dizer isso bem, porque é a resposta que a
maioria dos cliques atrasados vai receber.

### 2.3 A superfície

* `/play/:game/:token` — `P2PLive` da onda 4 já hospeda o jogo (o
  `P2PGameIsland` é uma das seções do console). Para o jogo, a rota entra
  direto na seção de jogo com o `game_id` da URL, em vez de abrir no console.
* Link compartilhável: `kind: "play"` na onda 1, com
  `target: %{game_id:, session_token:}`.
* O card de `/join/:slug` para um lobby aberto tem um estado a mais que os
  outros: **"vaga disponível" vs "já preenchido"**. Ele é o único kind em que o
  link deixa de funcionar por sucesso, não por falha.

### 2.4 De onde o link nasce

Dentro do jogo, não fora dele. Abrir um jogo multiplayer sem par oferece
"criar link" — e daí seguem os dois caminhos da onda 1: copiar, ou mandar pro
canal/PM aberto. O convite direto por `/p2p <nick>` continua existindo e não
muda: são dois caminhos para a mesma sessão, não duas sessões.

### 2.5 Arcade passa pelo mesmo portão

O Arcade já abre aba (`arcade_session_hook.js:29`), mas com
`window.open(url, "_blank")` **sem `noopener`** — então não ganha processo
próprio, e a URL é interna, não compartilhável.

Migrar: rota `/play/arcade/:game` pelo resolver, aberta por âncora com
`rel="noopener"`. O polling que hoje detecta a janela fechada
(`_startWindowPoll`) some — com `noopener` não existe referência para pollar, e
a coordenação passa a ser a da onda 6. Enquanto a onda 6 não chega, o fim da
sessão de arcade é o timeout de inatividade que o `SoloSessionServer` já tem.

---

## 3. TDD

### 3.1 `:unit` / `:integration` — o núcleo

| Asserção | Por quê |
|---|---|
| changeset permite `peer_id` nulo em `open` e exige em `pending` | é a mudança de invariante |
| `open → pending` só com `peer_id` presente | idem |
| `open → expired` fecha com `closed_at` + `closed_reason` | os terminais não afrouxaram |
| **duas reivindicações concorrentes: uma ganha, a outra recebe `:already_claimed`** | é o teste que justifica a escrita condicional |
| reivindicar o próprio link é recusado | |
| usuário bloqueado pelo criador não reivindica | reusa `ignore_list_entries`, tipo `:all` |
| lobby aberto expirado não reivindica | |
| rate limit de criação de lobby aberto | um link por clique vira spam de sessão |

O teste de concorrência é o teste desta onda. Escrever com duas tasks e uma
barreira, não com `sleep`.

### 3.2 `:liveview`

| Asserção |
|---|
| `/join/:slug` de lobby aberto: "vaga disponível" → reivindica → navega para `/play/:game/:token` |
| o mesmo slug, segundo visitante: "já preenchido", sem vazar quem preencheu |
| `/play/:game/:token` com sessão já cheia e você não é participante → recusa |
| a sala de partida é o primeiro render; `[Iniciar]` desabilitado sem todos prontos |
| `[Iniciar]` só para o host; host sai antes de iniciar → sala fecha (P7) |
| depois de iniciada, quem tem vaga entra direto e quem não tem vê "vaga preenchida" (P4) |
| a rota entra direto na seção de jogo, não no console |

### 3.3 Playwright

`e2e/tests/game-open-lobby.spec.ts`:

1. A abre um jogo multiplayer, cria o link, manda no canal;
2. B clica e entra; a partida roda de verdade (canvas, `retro_game_result`);
3. C clica no mesmo link e vê "já preenchido";
4. A partida acaba; o link continua morto.

Lembrar da armadilha de canvas em WAN/CI já conhecida da harness de load:
clique em canvas precisa de `force`.

---

## 4. Obrigações do repositório

- [ ] Migração: `peer_id` nulo, status `open`, `expires_at`. Índice parcial em
      `(token) WHERE peer_id IS NULL` para a escrita condicional.
- [ ] Help topics: "como criar um link de partida", "por que meu link parou de
      funcionar" (porque alguém entrou — é a pergunta que vão fazer).
- [ ] i18n.
- [ ] `SURFACE.txt` para eventos novos de lobby aberto.
- [ ] `PerfBudgets` para `:play` já existe desde a onda 0 — reconferir depois do
      multiplayer.
- [ ] `docs/guide/webrtc-p2p.md` §8.1: a máquina de estados ganhou `open` e
      `peer_id` deixou de ser obrigatório. O guia descreve 7 estados hoje;
      atualizar no mesmo commit da migração.

## 5. Riscos

* **Lobby aberto é uma superfície de abuso nova.** Qualquer pessoa com o link
  ocupa a vaga. Mitigações que precisam existir desde o primeiro commit: expiry
  curto, rate limit de criação, revogação pelo criador (onda 1 já dá isso), e
  bloqueio/ignore respeitado na reivindicação.
* **A janela entre criar e reivindicar é um estado que ninguém tem hoje.** Um
  lobby aberto que nunca é reivindicado precisa morrer sozinho — job de expiração
  no Oban, que é onde trabalho de fundo vive neste repositório, com a
  observabilidade que o §17 exige.
* **`peer_id` nulo atravessa código que assume dois participantes.**
  `Queries.active_sessions_between/2`, `Policy.can_close?/2`, `can_decline?/2`,
  `close_sessions_between/2` — todos precisam de leitura, não de fé. Fazer o
  levantamento antes de mexer no changeset.

## 6. Pronto quando

- `make ci` verde.
- O teste de reivindicação concorrente passa, e falha se a escrita condicional
  virar `read → check → write` (verificar revertendo uma vez).
- Um link de partida postado num canal funciona de ponta a ponta em Playwright.
- O Arcade abre por âncora com `noopener` e a URL dele é compartilhável.
