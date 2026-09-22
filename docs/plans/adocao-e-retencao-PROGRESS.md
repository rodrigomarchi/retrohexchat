# Adoção e retenção — progresso

Diário de execução de [`adocao-e-retencao.md`](adocao-e-retencao.md). Uma entrada
por iteração, com o que ficou pronto, o que foi aprendido e o que mudou de
plano. Aprendizado durável migra para `AGENT-GUIDE.md` ou um playbook de
`guide/` antes deste arquivo ser apagado junto com o plano.

## Estado por item

| Item | Estado |
|---|---|
| 1.1 Expiração de nick e canal | **pronto** (2026-09-22) |
| 1.2 Catálogo com salas frias | não iniciado |
| 1.3 Convite de canal com prévia | não iniciado |
| 2.1 Notificação de desktop | não iniciado |
| 2.2 PWA | não iniciado |
| 2.3 Web Push | não iniciado |
| 3.1 Reações | não iniciado |
| 3.2 Menções | não iniciado |
| 3.3 Régua de não lidas | não iniciado |
| 4.1 Multi-dispositivo | não iniciado |
| 4.2 E-mail opcional | não iniciado |
| 4.3 Fixar mensagem | não iniciado |
| 4.4 Salvar mensagem | não iniciado |
| 5.1 Arquivo público | não iniciado |
| 5.2 Threads | não iniciado |
| 5.3 Eventos | não iniciado |
| 5.4 Avatar no chat | não iniciado |
| 5.5 Emoji do servidor | não iniciado |
| 5.6 Mensagem de voz | não iniciado |

---

## Iterações

### 2026-09-22 — item 1.1, expiração de nick e canal

**Pronto.** `make ci` 18/18.

- Nick passa de 7 para **180 dias**, canal de 7 para **90**, ambos lidos em
  runtime de `config :retro_hex_chat, :expiry` e sobrescritos por
  `RHC_NICK_EXPIRY_DAYS` / `RHC_CHANNEL_EXPIRY_DAYS`. Valor malformado levanta no
  boot em vez de cair no default em silêncio.
- `NickExpiry.configured_expiration_days/0` e `ChanExpiry.configured_expiration_days/0`
  são públicas porque **seis telas citavam "7 dias"** e todas precisavam ler o
  mesmo número.
- `Chat.TimeFormatter.days/1` é o único lugar onde uma quantidade de dias é
  soletrada; todas as frases passaram a interpolar `%{window}`.

**Aprendizados**

- **O teste que já existia não questionava a constante.** Todo caso de
  `nick_expiry_test.exs` passava `expiration_days:` explicitamente, então o 7
  nunca foi exercido por ninguém. Um teste que sempre passa o parâmetro não
  testa o default — e foi por isso que a primeira versão dos casos novos
  **passou por acidente**: uma janela configurada *menor* que 7 é satisfeita
  pela constante antiga. A janela de teste tem de ser mais larga que o valor que
  se quer provar que morreu.
- **Dois testes de worker codificavam a constante sem dizer.**
  `RegisteredChannelExpiryWorkerTest` e `RegisteredNickExpiryWorkerTest`
  atrasavam a atividade em 8 dias e esperavam purga. O assunto deles é o worker,
  não a janela, então agora fixam a janela no `setup`. Regra que vale adiante:
  **teste de worker fixa a política que o worker aplica**, senão ele quebra
  quando a política muda por motivo legítimo.
- **`make i18n.gettext.merge DOMAINS=` quer vírgula, não espaço.**
  `DOMAINS="chat connect help"` roda sem erro e merge-ia só o primeiro. Meia
  hora perdida procurando msgid que o merge nunca tinha criado.
- **`gettext.merge` marcou as frases como `fuzzy` com o "7" cravado dentro.**
  Exatamente a armadilha conhecida: o msgstr sob `#, fuzzy` é o palpite copiado
  de OUTRO msgid. Aceitar aquilo teria colocado "7 dias" em catorze idiomas com
  o servidor varrendo em 180.
- **Sete msgids com plural em catorze idiomas era o desenho errado.** A primeira
  tentativa usou `dngettext` em cada frase, o que multiplica a regra de plural
  por frase. O desenho certo é **um** par plural (`%{count} day`/`%{count} days`)
  num formatador, e `%{window}` em toda frase. Reduziu o problema de plural de
  sete lugares para um, e foi o que tornou a curadoria viável.
- **Placeholder não carrega caso gramatical.** Alemão (`nach 7 Tagen`, dativo) e
  polonês (`po 7 dniach`, locativo) não sobrevivem à substituição: `%{window}`
  produz nominativo/acusativo. As três frases afetadas foram **reescritas** nos
  dois idiomas para uma construção que concorda (`wenn sie %{window} lang
  inaktiv sind`, `gdy są nieaktywne przez %{window}`). Russo e polonês no par
  plural ficam corretos sozinhos porque a forma concorda com o número.
- **Tradução nova derivada da antiga não é tradução automática.** As catorze
  traduções das frases novas saíram da tradução curada que já existia, trocando
  o "7 dias" da língua por `%{window}` — com snapshot antes e auditoria depois
  provando **0 entradas pré-existentes alteradas** e apenas os 7 msgids
  esperados adicionados.
- **A auditoria mentiu primeiro.** O comparador acusou 462 entradas danificadas
  porque `json.load` devolve as chaves de plural como string e `polib` como
  inteiro. Normalizar a chave zerou o número. Vale a regra: quando uma auditoria
  acusa dano em massa numa mudança cirúrgica, o suspeito é a auditoria.

**Arquivos tocados** — `config/config.exs`, `config/runtime.exs`,
`services/nick_expiry.ex`, `services/chan_expiry.ex`, `chat/time_formatter.ex`,
`chat/help_topics/features.ex`, `connect_form_panel.ex`, `chat_live.ex`, quatro
templates de `help_content/` mais seus três módulos hospedeiros, e os catálogos
de `chat`, `connect`, `help`, `help_channels`, `help_features`.

