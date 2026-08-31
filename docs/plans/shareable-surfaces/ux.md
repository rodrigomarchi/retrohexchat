# O modelo de produto e as telas

Este arquivo é o desenho. As ondas implementam o que está aqui; quando uma onda e
este arquivo discordarem, este arquivo está errado e é ele que muda primeiro.

Decisões travadas em conversa (2026-08-28) e o raciocínio que sobreviveu a elas
estão no [README §3](README.md).

---

## 1. O conceito: antessala

Toda superfície tem uma **antessala** — a tela onde você chega antes de estar
dentro. Ela existe em duas formas, e a diferença entre elas é se a coisa é um
**lugar** ou um **evento**.

| | Sala de chegada | Sala de partida |
|---|---|---|
| Para | chamada de canal, space | jogo multiplayer, sessão P2P |
| Porque | já está acontecendo; você entra quando quiser | começa junto, alguém decide quando |
| Tem host | não | sim (quem criou) |
| Tem `[Iniciar]` | não — cada um tem `[Entrar]` | sim |
| Tem `[Pronto]` | não | sim |
| Entidade persistida | **nenhuma** — é estado de render | `RetroHexChat.Lobby` |

**Nenhuma antessala tem chat.** A conversa acontece na aba do chat, onde o card
ao vivo já está. Todas têm `[← ao chat]`.

Por que sala de chegada não vira entidade: o roster dela já existe em
`GroupCall.get_summary/1` (chamada) e `VirtualSpace.snapshot/1` (space). Criar
uma tabela para desenhar uma lista que o runtime já sabe seria uma segunda fonte
de verdade.

---

## 2. As telas

### 2.1 O card no chat — ao vivo

O card é uma mensagem de verdade, no histórico do canal ou da PM, com estado que
atualiza sozinho.

```
─ #retro ─────────────────────────────────────────────────
 10:32 <ana> gente, chamada agora

 ┌──────────────────────────────────────────────────────┐
 │ [☎]  Chamada em #retro                    ● AO VIVO  │
 │      ana, bob, carla · 3 participantes               │
 │      [ Entrar ]   [ Copiar link ]                    │
 └──────────────────────────────────────────────────────┘

 10:41 <joao> to indo
```

Três variantes, uma por kind:

```
 ┌──────────────────────────────────────────────────────┐
 │ [☎]  Chamada em #retro                    ● AO VIVO  │
 │      ana, bob, carla · 3 participantes               │
 │      [ Entrar ]   [ Copiar link ]                    │
 └──────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────┐
 │ [◱]  Space de #retro                      ● 7 dentro │
 │      ana, bob, carla e mais 4                        │
 │      [ Entrar ]   [ Copiar link ]                    │
 └──────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────┐
 │ [◆]  Hex Pong · partida de ana         ○ AGUARDANDO  │
 │      1 vaga                                          │
 │      [ Entrar ]   [ Copiar link ]                    │
 └──────────────────────────────────────────────────────┘
```

E os estados terminais — porque um link compartilhado passa a maior parte da vida
morto, e o card precisa ser útil assim:

```
 ┌──────────────────────────────────────────────────────┐
 │ [☎]  Chamada em #retro                    ○ ENCERRADA│
 │      durou 42 min · 5 participantes                  │
 │      [ Abrir #retro ]                                │
 └──────────────────────────────────────────────────────┘

 ┌──────────────────────────────────────────────────────┐
 │ [◆]  Hex Pong · ana venceu bob            ○ TERMINOU │
 │      [ Jogar Hex Pong ]                              │
 └──────────────────────────────────────────────────────┘
```

Um card encerrado sempre oferece a **próxima ação plausível**, nunca um beco.

**Fonte de verdade e como ele fica vivo**

| kind | leitura | como atualiza |
|---|---|---|
| chamada | `GroupCall.get_summary/1` | o `ChatLive` **já** mantém `group_call_channel_summaries` por PubSub — o card lê o assign que existe |
| space | `VirtualSpace.snapshot/1` | `ChannelSpaceServer` já transmite entrada/saída no tópico `space:#canal`; o chat passa a assinar |
| jogo / P2P | `Lobby` | tópico `lobby:<token>`, que o chat já conhece |

O custo real é o do space, que é uma assinatura nova. Chamada é praticamente de
graça.

**Onde ele entra no código:** `components/ui/chat/message_row.ex:121` já trata
`:p2p_invite` como tipo próprio de mensagem. `:share_card` entra ao lado. O
convite P2P de hoje passa a ser uma variante desse card, não um segundo
componente.

### 2.2 `/join/:slug` — o card público

A primeira coisa que um estranho vê do produto. Pipeline `:landing_live`, sem
`app.js`.

```
        ┌──────────────────────────────────────────┐
        │   R E T R O   H E X   C H A T            │
        │                                          │
        │   ┌────────────────────────────────┐     │
        │   │ [☎] Chamada em #retro          │     │
        │   │     3 pessoas agora            │     │
        │   │                                │     │
        │   │        [ Entrar ]              │     │
        │   └────────────────────────────────┘     │
        │                                          │
        └──────────────────────────────────────────┘
```

Quatro estados:

| estado | botão | texto |
|---|---|---|
| vivo, com sessão, autorizado | `[ Entrar ]` | vai direto pra antessala |
| vivo, **sem sessão** | `[ Conectar e entrar ]` | `/connect?return_to=/join/:slug` |
| vivo, sessão, **não autorizado** | `[ Abrir o chat ]` | a razão vem da `Policy` |
| morto | `[ Abrir o chat ]` | "essa chamada acabou" |

**O que o card público não conta:** nome de canal privado. Um preview de rede
social que diz "Chamada em #diretoria" vaza a existência de um canal que a
pessoa não podia nem listar. Canal público aparece; canal privado vira "Uma
chamada no RetroHexChat".

### 2.3 Antessala de chegada — chamada

```
┌─ Chamada · #retro ─────────────────────────── [_][□][X] ┐
│ Sessão   Chamada   Exibir   Ajuda                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   ┌───────────────────────┐    Já estão dentro          │
│   │                       │      ana                    │
│   │    sua câmera         │      bob                    │
│   │                       │      carla                  │
│   └───────────────────────┘                             │
│                                                         │
│   Câmera    [ FaceTime HD          ▾ ]                  │
│   Microfone [ MacBook Pro Micro    ▾ ]                  │
│   Alto-fal. [ Padrão do sistema    ▾ ]                  │
│                                                         │
│   [x] Entrar com o microfone ligado                     │
│   [ ] Entrar com a câmera ligada                        │
│                                                         │
├─────────────────────────────────────────────────────────┤
│            [ ← ao chat ]            [ Entrar ]          │
├─────────────────────────────────────────────────────────┤
│ pronto para entrar                        3 na chamada  │
└─────────────────────────────────────────────────────────┘
```

Sem host, sem `[Iniciar]`: uma chamada de canal hoje não tem dono, qualquer
membro abre e qualquer um entra quando quer. Isso não regride.

**O que é novo aqui:** a coluna "já estão dentro". O resto é o
`group_call_pre_join_dialog` que já existe
(`components/ui/group_call/pre_join_dialog.ex`), promovido de diálogo do chat a
tela própria.

### 2.4 Antessala do space — o seletor de personagem

O space já tem uma antessala: o seletor de personagem. Ele **é** a antessala;
só ganha o roster.

```
┌─ Space · #retro ───────────────────────────── [_][□][X] ┐
├─────────────────────────────────────────────────────────┤
│                                                         │
│              Escolha seu personagem                     │
│                                                         │
│     ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐           │
│     │ ▓ │ │   │ │   │ │   │ │   │ │   │ │   │           │
│     └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───┘           │
│      herói                                              │
│     ─────────────────────────────────────────           │
│      Lá dentro agora                                    │
│      ana · bob · carla                                  │
│                                                         │
│      [ Compartilhar ]        [ Abrir em uma aba ]       │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ ← Chat                                    3 no space    │
└─────────────────────────────────────────────────────────┘
```

Um space não começa nem termina. Ele é um lugar, e a antessala dele é a porta.

**Não existe `[Entrar]` separado: escolher o personagem É entrar.** O card do
personagem é a porta, e um passo de confirmação depois dele seria exatamente a
cerimônia que P5 recusa. (Corrigido em 2026-08-30, onda 3: o desenho original
desta seção mostrava um `[Entrar]` no rodapé e contradizia o próprio P5.)

**O que é novo:** "lá dentro agora", e o rodapé que o host preenche —
**Compartilhar** em ambos, **Abrir em uma aba** só quando ainda se está no chat.
A barra de compartilhar mora aqui e não sobre o mapa: uma barra sobre o mapa
tiraria pixels da coisa que a pessoa veio ver, e o seletor é a única tela que os
dois hosts mostram todas as vezes.

O seletor é `components/ui/space_character_select.ex`, que já existe e já é o
primeiro estado ao entrar no space.

### 2.5 Sala de partida — sessão P2P e jogo multiplayer

A única antessala com estado persistido, e a única com host.

A sessão P2P foi a primeira a ganhá-la (onda 4B), e ela mostra a forma inteira:
o roster à esquerda do que cada um vai usar, porque uma sessão P2P é uma
conversa com câmera e microfone e a escolha dos dispositivos é metade do que
`[Pronto]` significa.

```
┌─ P2P · bob ────────────────────────────────── [_][□][X] ┐
├─────────────────────────────────────────────────────────┤
│  ┌───────────────┐  Na sala                             │
│  │               │    ana  (anfitrião)          pronto  │
│  │   prévia da   │    bob            escolhendo disp.   │
│  │    câmera     │  Esperando bob ficar pronto.         │
│  │               │                                      │
│  └───────────────┘  Padrões de mídia                    │
│                       [x] Começar com microfone         │
│                       [x] Começar com câmera            │
│                                                         │
│                     Microfone  [ Padrão do sistema  ▾ ] │
│                     Câmera     [ Padrão do sistema  ▾ ] │
│                     Alto-fal.  [ Padrão do sistema  ▾ ] │
│                                                         │
│                     ▸ Rota e privacidade   Direto ▾     │
│                                                         │
│  [ Compartilhar ]      [ Abrir em uma aba ]             │
│                        [ Pronto ]   ana: [ Iniciar ]    │
├─────────────────────────────────────────────────────────┤
│ ← Chat                                                  │
└─────────────────────────────────────────────────────────┘
```

Um jogo multiplayer usa a mesma sala sem a metade de dispositivos — um jogo não
tem câmera para escolher — e com o jogo no lugar dela:

```
┌─ Hex Pong · partida de ana ────────────────── [_][□][X] ┐
├─────────────────────────────────────────────────────────┤
│   ┌────┐  Hex Pong                                      │
│   │ ▓▓ │  Pong cyberpunk                                │
│   └────┘  Setas ou W/S para mover a raquete             │
│                                                         │
│   Na sala                                               │
│     ana     (anfitriã)     pronto                       │
│     bob                    escolhendo controles         │
│   Esperando bob ficar pronto.                           │
├─────────────────────────────────────────────────────────┤
│  [ Compartilhar ]   ana: [ Cancelar ]  [ Pronto ]       │
│                                    ana: [ Iniciar ]     │
├─────────────────────────────────────────────────────────┤
│ ← Chat                                                  │
└─────────────────────────────────────────────────────────┘
```

**`[Cancelar]` é P7 com um botão.** Uma sala não sobrevive a quem estava
esperando nela: o host desiste, a sala fecha e o link morre junto, em vez de o
endereço continuar valendo até o prazo passar. Só o host o tem, e ele some no
instante em que a partida começa — depois disso o caminho terminal é o de
sempre, com confirmação.

**O que a sala do jogo mostra no lugar dos dispositivos é o jogo** — ícone, nome
e controles, do catálogo. Não é decoração: é a única resposta para "no que eu
acabei de entrar", e quem chegou por um link colado num canal não viu mais nada
antes desta tela. Não há seletor: **o link nomeia a partida**, e escolher outro
jogo aqui seria a sala contradizendo o endereço que trouxe a pessoa.

Por isso também não há aceitar/recusar depois: seguir o link *é* o consentimento
para aquele jogo. Quando os dois estão prontos e o host aperta `[Iniciar]`, a
partida que começa é a do link, sem uma segunda pergunta.

(Corrigido em 2026-08-31, onda 5: o desenho original mostrava "Dificuldade da IA
(só host)". Dificuldade é do jogo contra a máquina; numa partida entre duas
pessoas não existe IA para regular, e o controle era da tela solo copiado para
uma tela que não o tem.)

* Host = quem criou. Host sai antes de iniciar → a sala fecha e o link morre.
* **`[Pronto]` são duas coisas ao mesmo tempo**: o que você escolheu, e o seu
  cliente pronto para receber. A segunda metade não é opcional nem cosmética —
  a primeira oferta é descartada se o outro lado ainda não estiver escutando, e
  a sala existe para essa espera ter nome.
* `[Iniciar]` só habilita quando os dois lados estão prontos, e só quem convidou
  o tem: o criador é sempre o ofertante.
* A linha abaixo do roster diz **por quem se está esperando**, sempre. Era o
  estado em que a pessoa ficava sem saber por quê.
* Quem chega depois do início **não volta para a sala**: uma sessão que já está
  correndo entrega a superfície direto. Num jogo cheio, o card do link diz "vaga
  preenchida". O link nunca vira um beco silencioso.
* **Uma sessão só fica viva numa janela por vez.** Abrir a mesma sessão em outro
  lugar a move para lá, e a janela que a perdeu diz isso e oferece trazê-la de
  volta — mesmo contrato do takeover de chat.

### 2.6 As superfícies

Depois da antessala. Todas seguem a mesma anatomia: um desktop Win98 com **uma
janela fixada e maximizada** — a mesma forma que `/chat` tem hoje.

```
┌─ Chamada · #retro ─────────────────────────── [_][□][X] ┐
│ Sessão   Chamada   Exibir   Ajuda                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│    ┌───────────┐  ┌───────────┐  ┌───────────┐          │
│    │   ana     │  │   bob     │  │  carla    │          │
│    │           │  │        🎤 │  │           │          │
│    └───────────┘  └───────────┘  └───────────┘          │
│                                     ┌───────┐           │
│                                     │ você  │           │
│                                     └───────┘           │
├─────────────────────────────────────────────────────────┤
│ [🎤][📷][🖥][😀][⚙]                   [ ← ao chat ] [Sair]│
├─────────────────────────────────────────────────────────┤
│ conectado · 42 kbps ↑ · #retro            3 participantes│
└─────────────────────────────────────────────────────────┘
 ▓ Iniciar │ [☎] Chamada #retro │              │ 14:32
```

```
┌─ Space · #retro ───────────────────────────── [_][□][X] ┐
├─────────────────────────────────────────────────────────┤
│                                                         │
│              ╱╲    ╱╲    ╱╲                             │
│             ╱  ╲  ╱  ╲  ╱  ╲     ▓ ana                  │
│            ╱ ▓  ╲╱    ╲╱    ╲                           │
│            ╲ você ╲   ╱╲    ╱      ▓ bob                │
│             ╲    ╱╲ ╱  ╲  ╱                  [↑]        │
│              ╲  ╱  ╲    ╲╱                 [←][→]  (⚔)  │
│                                              [↓]        │
├─────────────────────────────────────────────────────────┤
│ ← Chat                                       7 no space │
└─────────────────────────────────────────────────────────┘
```

A superfície do space é o mapa e nada mais: o pad de direção fica **sobre** o
canvas, onde sempre esteve, e o rodapé é a barra de status da janela. Duas
diferenças em relação às outras duas superfícies, e ambas porque um space é um
lugar e não um evento:

* **não há `[Sair]`.** Não existe sessão para encerrar — sair de um lugar é
  andar para fora dele, e `← Chat` já é essa porta. Um diálogo de confirmação
  para fechar algo que não está sendo desmontado seria cerimônia.
* **o botão de tela cheia não aparece.** Numa aba própria a página já é o space;
  ele continua existindo no modo embutido, onde o mapa vive espremido dentro de
  uma aba dentro de uma janela.

Três coisas valem para as três superfícies:

1. **`[← ao chat]` está sempre visível.** Se a aba do chat existe, ele foca ela;
   se não existe (você veio de fora), ele abre `/chat`. O botão nunca some.
2. **A barra de status fala da superfície**, não do servidor — é a regra do
   desktop: "a bandeja fala pela máquina; isto fala pela janela".
3. **`[Sair]` pede confirmação e é o único caminho terminal.** Fechar a aba do
   navegador é saída inesperada: `disconnect_call`, janela de reconexão
   preservada. **Não vale para o space**, que não tem nada de terminal: ver
   §2.6 acima.

### 2.7 O que muda no chat

```
─ #retro ─────────────────────────────┬─ Usuários ─────
 10:32 <ana> gente, chamada agora     │  @ana      ☎
                                      │  +bob      ☎
 ┌──────────────────────────────────┐ │   carla    ☎
 │ [☎] Chamada em #retro  ● AO VIVO │ │   joao
 │     ana, bob, carla · 3          │ │
 │     [ Entrar ]  [ Copiar link ]  │ │
 └──────────────────────────────────┘ │
                                      │
 10:41 <joao> to indo                 │
──────────────────────────────────────┴────────────────
 [Status] [#retro] [Space] [☎ Chamada ▸ em outra aba]
─────────────────────────────────────────────────────
 >_
```

* A aba `[☎ Chamada]` na barra ganha um estado novo: **"em outra aba"**, com a
  ação `Focar` em vez de `Abrir`.
* A nicklist marca quem está na chamada — dado que o summary já carrega.
* Nada some do chat. A janela do desktop continua existindo e hospeda a mesma
  superfície aninhada (mobile, e quem prefere não sair da aba).

---

## 3. Novo versus reuso

O que este plano **cria**:

| Novo | Onde |
|---|---|
| card `:share_card` na conversa (3 kinds × 2 estados) | `components/ui/chat/` |
| página pública `/join/:slug` | `live/join_live.ex` |
| roster "já estão dentro" / "lá dentro agora" | `components/ui/` |
| sala de partida (host, pronto, iniciar) | `components/ui/lobby/` + `RetroHexChat.Lobby` |
| shell de superfície satélite | reusa `desktop/1` + `desktop_window/1` |

O que ele **reusa sem tocar**:

`group_call/pre_join_dialog.ex` (vira a antessala de chamada),
`space_character_select.ex` (vira a antessala do space),
`group_call/panel.ex` e os outros 11 módulos de `components/ui/group_call/**`,
`components/ui/p2p/**`, `components/ui/lobby/**`, `components/ui/media_session/**`,
`games/retro_games_panel.ex`, `layout/desktop.ex`, `menu_bar`, taskbar,
`window_status_bar_field`.

A regra: nenhuma tela deste documento é markup novo de tela. Se uma delas pedir
markup próprio, ela está errada — `AGENT-GUIDE` §9.

---

## 4. O que ainda não está decidido

1. **O Start menu nas satélites.** Hoje ele é superconjunto em todas as telas do
   window manager — +177 nós por tela. Uma superfície de propósito único carregar
   a lista inteira em cinza é peso sem uso. Decidido na
   [onda 6 §2.3](wave-6-cross-tab-and-bundle.md).
2. **Guest pass.** A decisão atual é que o link não concede autorização: quem
   chega de fora conecta com um nick, e as regras de hoje valem — o que significa
   que um link de conferência num canal só funciona pra quem já é membro. É a
   escolha certa para a primeira versão e é a que mais limita o alcance social.
   [README §7](README.md).
