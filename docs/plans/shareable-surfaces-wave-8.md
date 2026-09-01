# Onda 8 — o card ao vivo na conversa

**Depende de:** ondas 0–6 (shippadas) e da onda 7 (os consertos da auditoria).

**Entrega:** a última promessa aberta do plano de superfícies compartilháveis —
`P3`, uma decisão de produto travada, desenhada no `ux.md §2.1` e nunca
construída. Mais a nicklist, que lê o mesmo summary e por isso vem junto.

Apagar este arquivo quando fechar, movendo as regras duráveis para os guias
**antes**. Junto com ele saem
[`shareable-surfaces-audit.md`](shareable-surfaces-audit.md),
[`shareable-surfaces-wave-7.md`](shareable-surfaces-wave-7.md) e o diário dela —
foi a decisão **Q12**.

---

## 0. De onde isto vem

Do achado **R.2** da auditoria, que é o maior dos quinze e o único que não é bug:
é entrega declarada fechada que não existe. A decisão **Q1** foi dar a ela um
plano próprio em vez de enfiá-la numa onda de conserto, onde sairia como o menor
denominador de uma lista de bugs.

O desenho foi apagado de propósito no `9620e81b`. Recupere antes de decidir
qualquer coisa sobre a tela:

```sh
mkdir -p /tmp/plan && for f in README ux wave-1-join-resolver; do
  git show 9620e81b^:docs/plans/shareable-surfaces/$f.md > /tmp/plan/$f.md
done
```

`ux.md §2.1` é a tela. `README §3` tem `P3`, `P4` e `P6`, que são as decisões que
a governam. `wave-1 §2.4` tem a tabela de o que mantém o card vivo por kind, e
`wave-1 §3.3` tem a tabela de TDD que ninguém cumpriu.

---

## 1. O que existe hoje, medido

`RetroHexChatWeb.Components.UI.ShareMessageCard` tem 69 linhas e desenha um
ícone, um nome, `"shared by X"` e **um** botão `[Join]`. Não lê `@card.live?`.

```sh
wc -l apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/share/share_message_card.ex
grep -n "live?" apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/share/share_message_card.ex   # vazio
sed -n '410,428p' apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/message_viewport.ex
grep -rn "Topics.space\b" apps/*/lib | grep -v priv/gettext   # só o SpaceLive
```

Ele é calculado uma vez, no pipeline que decora as mensagens da tela
(`put_share_cards/1`), sem nenhuma assinatura. E há um efeito colateral pior que
um card cinza: `describe_many/1` **filtra fora** revogados e expirados
(`share_links/service.ex`), então um link revogado não fica cinza — o card
**some** do histórico, e a mensagem fica com um endereço nu no lugar de um card
que explicaria o que houve.

---

## 2. As telas

Do `ux.md §2.1`, sem reinterpretação. Três kinds, dois estados cada.

```
 ┌──────────────────────────────────────────────────────┐
 │ [☎]  Chamada em #retro                    ● AO VIVO  │
 │      ana, bob, carla · 3 participantes               │
 │      [ Entrar ]   [ Copiar link ]                    │
 └──────────────────────────────────────────────────────┘
 ┌──────────────────────────────────────────────────────┐
 │ [◱]  Space de #retro                      ● 7 dentro │
 ├──────────────────────────────────────────────────────┤
 │ [◆]  Hex Pong · partida de ana         ○ AGUARDANDO  │
 │      1 vaga                                          │
 └──────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────┐
 │ [☎]  Chamada em #retro                    ○ ENCERRADA│
 │      durou 42 min · 5 participantes                  │
 │      [ Abrir #retro ]                                │
 ├──────────────────────────────────────────────────────┤
 │ [◆]  Hex Pong · ana venceu bob            ○ TERMINOU │
 │      [ Jogar Hex Pong ]                              │
 └──────────────────────────────────────────────────────┘
```

**Um card encerrado sempre oferece a próxima ação plausível, nunca um beco.** É a
frase de `P3` e é o teste de aceitação da metade terminal.

### 2.1 A regra de privacidade já existe — use-a

O nome do canal só aparece quando um estranho poderia tê-lo listado. Isso agora é
`RetroHexChat.Channels.Visibility.nameable?/1`, com dois consumidores
(`JoinLive` e `SpaceLive`). **O card é o terceiro**, e é o mais exposto: ele
aparece numa conversa cujos leitores podem não estar naquele canal.

Não reimplementar. `wave-1 §3.3` tem a linha: *"um card de canal privado visto
por quem não é membro não revela o nome do canal"*.

### 2.2 O convite P2P vira variante, não um segundo componente

`:p2p_invite` ainda é um tipo próprio em `components/ui/chat/message_row.ex`. O
`ux.md §2.1` diz: *"O convite P2P de hoje passa a ser uma variante desse card,
não um segundo componente."* O teste do `:p2p_invite` é **portado**, não
reescrito — é a instrução literal de `wave-1 §3.3`.

---

## 3. O que mantém o card vivo, por kind

Do `wave-1 §2.4`, conferido contra o código de hoje:

| kind | leitura | assinatura |
|---|---|---|
| chamada | `GroupCall.get_summary/1` | **nenhuma nova** — o `ChatLive` já mantém `@group_call_channel_summaries` e agora as transmissões saem em `Topics.channel_calls/1` |
| space | `VirtualSpace.roster/1` | **nova** — `Topics.space_roster/1` existe e hoje só o `SpaceLive` assina |
| jogo / P2P | `Lobby` | tópico `lobby:<token>`, que o chat já conhece |

**O único custo novo é o do space, e ele tem um limite que precisa estar no
código:** o chat assina o tópico de um canal **só enquanto houver card visível
daquele canal**, e cancela quando o último sai de vista. Assinar todos os canais
em que a pessoa está transformaria cada passo de cada avatar em tráfego para quem
só quer conversar.

Isso é a parte cara desta onda e é onde ela dá errado se for feita por reflexo.

---

## 4. A nicklist (Q6)

`ux.md §2.7`, segunda bullet: *"A nicklist marca quem está na chamada — dado que
o summary já carrega."* Está aqui e não na onda 7 porque lê **o mesmo summary**
que o card, e fazer duas vezes a mesma leitura é como as duas divergem.

```sh
grep -n "conference\|call" apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/chat/nicklist.ex  # vazio hoje
```

---

## 5. TDD

As linhas de `wave-1 §3.3` que nunca existiram, mais o que a onda 7 aprendeu.

| Camada | Asserção |
|---|---|
| componente | os três kinds renderizam com ícone, título e ação próprios |
| componente | estado encerrado: cinza, **sem** `[Entrar]`, **com** a próxima ação (`Abrir #canal` / `Jogar X`) |
| componente | a contagem de participantes reflete o summary passado, e muda quando ele muda |
| componente | um card de canal privado visto por quem não é membro **não** revela o nome do canal |
| componente | o card de kind `p2p` cobre o que o `:p2p_invite` cobria — **teste portado, não reescrito** |
| `:liveview` | o chat assina `Topics.space_roster/1` ao renderizar um card de space daquele canal, e **cancela** quando o último card sai de vista |
| `:liveview` | um link revogado renderiza o card terminal em vez de sumir do histórico |
| `:liveview` | a nicklist marca quem está na chamada, a partir do summary que o chat já tem |
| Playwright | o card muda sozinho quando alguém entra na sala, sem recarregar |

A penúltima linha é a que impede o card ao vivo de virar um custo silencioso por
canal, e é a que `wave-1 §3.3` colocou numa tabela separada por isso.

**Regras que a onda 7 pagou para aprender:**

* **Um teste que afirma ausência é o mais fácil de escrever verde por acidente.**
  Reverta o conserto uma vez e veja o teste ficar vermelho — foi assim que a
  asserção do K5 nasceu inútil (`toHaveCount(0)` numa nota que não existia).
* **`live/2` sempre conecta.** Um efeito no `mount/3` só aparece com `get/2`.
* **Preferir `render_component` a um teste de LiveView com laço de sleep.**

---

## 6. Obrigações do repositório

- [ ] Help topics: o card ganha `[Copiar link]` e um estado terminal com ação —
      é controle acionável (`AGENT-GUIDE §12`).
- [ ] i18n: extract + merge dos domínios tocados, e **traduzir** — a onda 7
      fechou `help_games` em zero vazios e a régua agora é essa.
- [ ] `PerfBudgets`: o card entra no orçamento de `:chat`; medir antes e depois.
- [ ] `SURFACE.txt` se nascer evento novo.
- [ ] `e2e/TEST_CATALOG.md` regenerado.
- [ ] `make ci` verde — 17/17, Dialyzer incluído.

---

## 7. Riscos

* **A assinatura de space é o custo.** Sem o cancelamento por visibilidade, um
  canal com space movimentado manda delta de avatar para todo mundo que só queria
  ler o chat. Medir com um canal cheio, não com um vazio.
* **O card vira canal lateral de informação.** Toda diferença de mensagem entre
  "não existe" e "existe mas você não pode" é um oráculo. A regra já está em
  `Visibility.nameable?/1`; o risco é alguém desenhar uma variante nova sem ela.
* **`put_share_cards/1` roda no pipeline de decoração de mensagens.** Torná-lo
  reativo sem torná-lo caro é o problema de engenharia desta onda, não o desenho.
* **O `:p2p_invite` tem teste e história.** Portar mal é perder cobertura de um
  fluxo que funciona.

---

## 8. Pronto quando

- [ ] `make ci` verde.
- [ ] Os três kinds × dois estados renderizam como o `ux.md §2.1` desenha.
- [ ] Um card de chamada encerrada oferece `[Abrir #canal]` e não `[Entrar]`.
- [ ] Um link revogado vira card terminal em vez de sumir.
- [ ] A contagem muda sozinha quando alguém entra, provado em Playwright.
- [ ] O chat assina o tópico de space só enquanto há card visível, e cancela.
- [ ] `:p2p_invite` é uma variante do card, com o teste portado.
- [ ] A nicklist marca quem está na chamada.
- [ ] As regras duráveis foram movidas para os guias, e então
      `shareable-surfaces-audit.md`, `-wave-7.md`, `-wave-7-progress.md` e este
      arquivo foram apagados (**Q12**).
