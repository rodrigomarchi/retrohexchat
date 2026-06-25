# Arquitetura-alvo

Este documento descreve **para onde** estamos indo e **por quê**, antes de
descer às fases. É a referência conceitual que todas as fases seguem.

## O princípio central

> Estado de UI de um diálogo deve viver **dentro de um `LiveComponent`
> stateful**, cujo socket é independente do socket do `ChatLive` pai.

Da documentação oficial do `Phoenix.LiveComponent`:

> "O socket do componente não é o mesmo do LiveView pai; ele não contém os
> assigns do pai e atualizá-lo não afeta o socket do pai."

Isso significa que, ao mover um diálogo (ex.: Admin Console, 32 assigns) para
um `LiveComponent`, esses 32 assigns **saem** do `assign_defaults/1` do
`ChatLive` e passam a viver isolados no componente — montados sob demanda,
descartados ao fechar.

## Antes × depois

### Antes (atual)

```
ChatLive (socket raiz)
├── ~260 assigns (estado de domínio + UI de TODOS os diálogos misturados)
├── 31 hooks de handle_event   ──►  todos mexem no mesmo socket
├── render: chat_live.html.heex
│     └── <.admin_console_dialog show={@show_admin_console}
│            results={@admin_console_results}
│            tab={@admin_console_tab} ... (~20 atributos) />
│            (function component STATELESS — estado todo no pai)
```

### Depois (alvo)

```
ChatLive (socket raiz)
├── ~80–100 assigns (estado de domínio + alguns flags show_* p/ montar diálogos)
├── render: chat_live.html.heex
│     └── <.live_component :if={@show_admin_console}
│            module={AdminConsoleComponent}
│            id="admin-console"
│            session={@session} />     ◄── passa só o necessário
│
└── AdminConsoleComponent (socket PRÓPRIO, isolado)
      ├── assigns: results, tab, motd, broadcast_result, ... (os ~32 de antes)
      ├── handle_event/3 com phx-target={@myself}
      └── update/2 recebe o que o pai passa; emite eventos p/ o pai quando
          precisa tocar estado de domínio
```

## Regras de fronteira (fonte de verdade)

Para não cair na armadilha de "pai e componente com cópias do mesmo dado",
aplicamos uma regra simples e explícita:

| Tipo de estado | Dono | Exemplos |
|---|---|---|
| **Domínio** (persiste além do diálogo) | `ChatLive` / contextos | `session`, `channel_users`, `messages` (stream), listas de canais |
| **UI do diálogo** (efêmero, só vive enquanto o diálogo está aberto) | `LiveComponent` | aba ativa, item selecionado, rascunhos de formulário, erros de validação, resultados de busca do diálogo |
| **Visibilidade** (montar/desmontar) | `ChatLive` | `show_admin_console`, `show_channel_central`, ... |

### Comunicação pai ↔ componente

- **Pai → componente:** atributos passados em `live_component/1` (chegam em
  `update/2`). Para atualizações assíncronas pontuais, `send_update/3`.
- **Componente → pai:** o componente emite um evento que o pai trata. Duas
  opções, escolhidas caso a caso:
  1. `phx-target={@myself}` para eventos que **só** afetam o estado do diálogo
     (preferível — não toca o pai).
  2. Para ações que mexem em **estado de domínio** (ex.: executar um comando de
     admin que altera a sessão), o componente chama o contexto diretamente **ou**
     notifica o pai via `send(self(), {:admin_action, ...})` tratado em
     `handle_info` do `ChatLive`.

## Como isto convive com o sistema de hooks atual

O `ChatLive` usa `attach_hook` para compor 31 módulos de eventos
(`live/app/chat_live.ex:569`). A migração **não** quebra esse mecanismo:

- Os eventos hoje tratados por `ChatLive.AdminConsoleEvents` que apenas mexem
  em assigns `admin_console_*` **migram para dentro** do `AdminConsoleComponent`
  (viram `handle_event/3` do componente, com `phx-target={@myself}`).
- Os eventos que tocam **domínio** (ex.: abrir/fechar o diálogo, executar
  efeitos globais) permanecem no hook do `ChatLive`.
- À medida que cada diálogo migra, o módulo `*_events.ex` correspondente
  encolhe ou é removido da lista `@event_hook_fns`
  (`live/app/chat_live.ex:516`) e de `attach_all_hooks/1`.

Resultado: o número de hooks no `ChatLive` cai junto com o número de assigns.

## Por que NÃO usar Flux/LiveEx

A comunidade oferece o [LiveEx](https://github.com/PJUllrich/live_ex) (padrão
Flux) para tornar mudanças de estado observáveis. **Decisão: não adotar**, por:

1. O problema aqui não é *rastrear* mudanças de estado global — é *isolar*
   estado de UI que nunca deveria estar no socket raiz. `LiveComponent` resolve
   isso com ferramenta nativa, sem dependência nova.
2. Adicionar uma camada Flux sobre 260 assigns mantém o acoplamento e só troca
   a sintaxe de acesso.
3. Reavaliar **só se**, após as Fases 1–3, ainda restar estado global
   genuinamente difícil de rastrear (não é o caso esperado).

## Convenções para os novos componentes

- Localização: `live/chat_live/components/<nome>_component.ex`.
- Nome do módulo: `RetroHexChatWeb.ChatLive.Components.<Nome>Component`.
- `use RetroHexChatWeb, :live_component`.
- `@impl true` em `update/2`, `handle_event/3`, `render/1`.
- `@spec` em toda função pública (exigência da `CLAUDE.md`).
- **Sem SVG inline** e **sem cores hardcoded** — seguem as regras de
  `CLAUDE.md` (usar `Icons.*` e classes Tailwind).
- O markup do diálogo (hoje em `components/ui/dialogs/*.ex`) é **reaproveitado**:
  o `LiveComponent` chama o function component de apresentação existente,
  passando seus próprios assigns. Assim não há retrabalho de UI nem risco
  visual.

## Sequência macro (resumo)

1. **Fase 1 — POC:** extrair o **Admin Console** (32 assigns) — maior ganho
   isolado e bom piloto. Ver [03](./03-fase-1-prova-de-conceito-admin-console.md).
2. **Fase 2:** replicar para Channel Central, Account, Address Book, Timers,
   Alias, Custom Menus, Autorespond, URL Catcher. Ver [04](./04-fase-2-demais-dialogos.md).
3. **Fase 3:** agrupar assigns residuais em sub-mapas, remover estado morto,
   revisar a struct `Session`. Ver [05](./05-fase-3-limpeza-estado-residual.md).
4. **Fase 4:** `streams` + decomposição de `p2p_session_live` e
   `game_session_live`. Ver [06](./06-fase-4-p2p-e-game-session.md).
