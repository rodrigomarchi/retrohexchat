"""Curated translations for the universal UI vocabulary.

Machine translation is unreliable for one- and two-word UI labels: with no
sentence around them the model picks the conversational sense over the
interface sense. It rendered "OK" as "Está bem." in pt_BR, "No" as "Numéro"
in fr, "Done" as "Artikel" in de, and "Next" as mojibake in both Chinese
locales. No amount of re-running fixes that — button labels are a glossary,
not a translation task.

Rules encoded here:

- "OK" stays literal everywhere except Chinese, where 确定/確定 is the
  established convention. It is one of the most widely borrowed words in any
  language and reads as the confirm button in all of our locales.
- No label ends in a period. Buttons and menu items are not sentences.
- A term identical to English is fine when the language genuinely borrows it
  ("Menu" in Portuguese, "Server" in German). Those are listed explicitly so
  the intent is visible rather than looking like a missing translation.
- A word that names two things in the product is curated under a gettext
  context, never bare. "Table" is a data table in the component showcase and a
  piece of furniture in the Construct; one bare row turned every showcase
  table into "Tisch". The furniture carries `msgctxt "furniture"`, its row is
  in `_CONTEXT_ROWS`, and a bare msgid never matches it.
"""

from __future__ import annotations

from . import names

# Column order for every row below. Keep in sync with the tuples.
LOCALE_ORDER = (
    "pt_BR",
    "pt_PT",
    "es",
    "fr",
    "de",
    "it",
    "nl",
    "pl",
    "ru",
    "id",
    "ja",
    "zh_hans",
    "zh_hant",
)

# fmt: off
_ROWS = {
    # ── Confirmation and dismissal ────────────────────────────
    "OK":           ("OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "确定", "確定"),
    "Cancel":       ("Cancelar", "Cancelar", "Cancelar", "Annuler", "Abbrechen", "Annulla", "Annuleren", "Anuluj", "Отмена", "Batal", "キャンセル", "取消", "取消"),
    "Yes":          ("Sim", "Sim", "Sí", "Oui", "Ja", "Sì", "Ja", "Tak", "Да", "Ya", "はい", "是", "是"),
    "No":           ("Não", "Não", "No", "Non", "Nein", "No", "Nee", "Nie", "Нет", "Tidak", "いいえ", "否", "否"),
    "Close":        ("Fechar", "Fechar", "Cerrar", "Fermer", "Schließen", "Chiudi", "Sluiten", "Zamknij", "Закрыть", "Tutup", "閉じる", "关闭", "關閉"),
    "Dismiss":      ("Dispensar", "Dispensar", "Descartar", "Ignorer", "Ausblenden", "Ignora", "Negeren", "Odrzuć", "Скрыть", "Abaikan", "非表示", "忽略", "忽略"),
    "Done":         ("Concluído", "Concluído", "Hecho", "Terminé", "Fertig", "Fatto", "Klaar", "Gotowe", "Готово", "Selesai", "完了", "完成", "完成"),
    "Apply":        ("Aplicar", "Aplicar", "Aplicar", "Appliquer", "Übernehmen", "Applica", "Toepassen", "Zastosuj", "Применить", "Terapkan", "適用", "应用", "套用"),
    "Save":         ("Salvar", "Guardar", "Guardar", "Enregistrer", "Speichern", "Salva", "Opslaan", "Zapisz", "Сохранить", "Simpan", "保存", "保存", "儲存"),
    "Retry":        ("Tentar novamente", "Repetir", "Reintentar", "Réessayer", "Wiederholen", "Riprova", "Opnieuw proberen", "Ponów", "Повторить", "Coba lagi", "再試行", "重试", "重試"),
    "Continue":     ("Continuar", "Continuar", "Continuar", "Continuer", "Fortfahren", "Continua", "Doorgaan", "Kontynuuj", "Продолжить", "Lanjutkan", "続ける", "继续", "繼續"),
    "Confirm":      ("Confirmar", "Confirmar", "Confirmar", "Confirmer", "Bestätigen", "Conferma", "Bevestigen", "Potwierdź", "Подтвердить", "Konfirmasi", "確認", "确认", "確認"),
    "Accept":       ("Aceitar", "Aceitar", "Aceptar", "Accepter", "Annehmen", "Accetta", "Accepteren", "Akceptuj", "Принять", "Terima", "承認", "接受", "接受"),
    "Decline":      ("Recusar", "Recusar", "Rechazar", "Refuser", "Ablehnen", "Rifiuta", "Weigeren", "Odrzuć", "Отклонить", "Tolak", "拒否", "拒绝", "拒絕"),

    # ── Conversations sidebar ─────────────────────────────────
    # The pipeline read these as sentences about connecting rather than as the
    # sidebar's vocabulary: "Channels" came back as Cannes in ru and as
    # "attachment" in it and pl, and "Join on connect" as "log in" in fr.
    "Channels":     ("Canais", "Canais", "Canales", "Canaux", "Kanäle", "Canali", "Kanalen", "Kanały", "Каналы", "Kanal", "チャンネル", "频道", "頻道"),
    # "Open" is an adjective here — the channels you have open — and the
    # pipeline read it as the verb: "Abrir canais", "Buka kanal", "打开频道".
    "Open channels": ("Canais abertos", "Canais abertos", "Canales abiertos", "Canaux ouverts", "Offene Kanäle", "Canali aperti", "Open kanalen", "Otwarte kanały", "Открытые каналы", "Kanal terbuka", "開いているチャンネル", "已打开的频道", "已開啟的頻道"),
    "Popular channels": ("Canais populares", "Canais populares", "Canales populares", "Canaux populaires", "Beliebte Kanäle", "Canali popolari", "Populaire kanalen", "Popularne kanały", "Популярные каналы", "Kanal populer", "人気チャンネル", "热门频道", "熱門頻道"),
    "Recent private messages": ("Mensagens privadas recentes", "Mensagens privadas recentes", "Mensajes privados recientes", "Messages privés récents", "Letzte private Nachrichten", "Messaggi privati recenti", "Recente privéberichten", "Ostatnie wiadomości prywatne", "Недавние личные сообщения", "Pesan pribadi terbaru", "最近のプライベートメッセージ", "最近的私信", "最近的私訊"),
    "Join on connect": ("Entrar ao conectar", "Entrar ao ligar", "Entrar al conectar", "Rejoindre à la connexion", "Beim Verbinden betreten", "Entra alla connessione", "Deelnemen bij verbinden", "Dołącz po połączeniu", "Входить при подключении", "Gabung saat terhubung", "接続時に参加", "连接时加入", "連線時加入"),
    "Joined on connect": ("Entra ao conectar", "Entra ao ligar", "Entra al conectar", "Rejoint à la connexion", "Wird beim Verbinden betreten", "Entra alla connessione", "Neemt deel bij verbinden", "Dołącza po połączeniu", "Входит при подключении", "Bergabung saat terhubung", "接続時に参加します", "连接时加入", "連線時加入"),
    "Joined on connect, with a key": ("Entra ao conectar, com senha", "Entra ao ligar, com senha", "Entra al conectar, con clave", "Rejoint à la connexion, avec une clé", "Wird beim Verbinden betreten, mit Schlüssel", "Entra alla connessione, con una chiave", "Neemt deel bij verbinden, met een sleutel", "Dołącza po połączeniu, z kluczem", "Входит при подключении, с ключом", "Bergabung saat terhubung, dengan kunci", "接続時にキーで参加します", "连接时使用密钥加入", "連線時使用金鑰加入"),

    # ── Navigation ────────────────────────────────────────────
    # The public games catalogue. "Modes" matches what the channel-mode
    # dialogs already say in every language, so one row serves both.
    "All games":    ("Todos os jogos", "Todos os jogos", "Todos los juegos", "Tous les jeux", "Alle Spiele", "Tutti i giochi", "Alle spellen", "Wszystkie gry", "Все игры", "Semua game", "すべてのゲーム", "全部游戏", "全部遊戲"),
    "More games":   ("Mais jogos", "Mais jogos", "Más juegos", "Plus de jeux", "Weitere Spiele", "Altri giochi", "Meer spellen", "Więcej gier", "Ещё игры", "Game lainnya", "その他のゲーム", "更多游戏", "更多遊戲"),
    "How to play":  ("Como jogar", "Como jogar", "Cómo jugar", "Comment jouer", "So wird gespielt", "Come si gioca", "Zo speel je", "Jak grać", "Как играть", "Cara bermain", "遊び方", "玩法", "玩法"),
    "Solo arcade":  ("Arcade solo", "Arcade a solo", "Arcade en solitario", "Arcade en solo", "Solo-Arcade", "Arcade in solitaria", "Solo-arcade", "Arcade solo", "Одиночная аркада", "Arkade solo", "ソロアーケード", "单人街机", "單人街機"),
    "Controls":     ("Controles", "Controlos", "Controles", "Commandes", "Steuerung", "Comandi", "Besturing", "Sterowanie", "Управление", "Kontrol", "操作", "控制", "控制"),
    "Modes":        ("Modos", "Modos", "Modos", "Modes", "Moden", "Modalità", "Modi", "Tryby", "Режимы", "Mode", "モード", "模式", "模式"),

    # The mIRC commands page: whether a command typed from mIRC habit works
    # the same here. Verdicts, not adjectives — "Not here" means the command
    # does not exist, never that someone is away.
    "Same":         ("Igual", "Igual", "Igual", "Identique", "Gleich", "Uguale", "Hetzelfde", "Tak samo", "Так же", "Sama", "同じ", "相同", "相同"),
    "Different":    ("Diferente", "Diferente", "Diferente", "Différent", "Anders", "Diverso", "Anders", "Inaczej", "Иначе", "Berbeda", "異なる", "不同", "不同"),
    "Not here":     ("Não existe", "Não existe", "No existe", "Absent", "Fehlt", "Assente", "Ontbreekt", "Brak", "Нет", "Tidak ada", "ここにはない", "没有", "沒有"),
    "Here":         ("Aqui", "Aqui", "Aquí", "Ici", "Hier", "Qui", "Hier", "Tutaj", "Здесь", "Di sini", "ここでは", "这里", "這裡"),
    "In mIRC":      ("No mIRC", "No mIRC", "En mIRC", "Dans mIRC", "In mIRC", "In mIRC", "In mIRC", "W mIRC", "В mIRC", "Di mIRC", "mIRC では", "在 mIRC 中", "在 mIRC 中"),
    "What to know": ("O que saber", "O que saber", "Qué saber", "À savoir", "Gut zu wissen", "Da sapere", "Goed om te weten", "Warto wiedzieć", "Что нужно знать", "Yang perlu diketahui", "知っておくこと", "须知", "須知"),
    "Questions":    ("Perguntas", "Perguntas", "Preguntas", "Questions", "Fragen", "Domande", "Vragen", "Pytania", "Вопросы", "Pertanyaan", "質問", "问题", "問題"),
    "Read next":    ("Leia também", "Leia também", "Lee también", "À lire aussi", "Weiterlesen", "Leggi anche", "Lees ook", "Czytaj dalej", "Читайте также", "Baca juga", "次に読む", "延伸阅读", "延伸閱讀"),
    "Talking":      ("Conversa", "Conversa", "Conversación", "Conversation", "Unterhalten", "Conversazione", "Praten", "Rozmowa", "Общение", "Mengobrol", "会話", "聊天", "聊天"),
    "Channel operators": ("Operadores de canal", "Operadores de canal", "Operadores de canal", "Opérateurs de canal", "Kanal-Operatoren", "Operatori del canale", "Kanaaloperators", "Operatorzy kanału", "Операторы канала", "Operator kanal", "チャンネルオペレーター", "频道管理员", "頻道管理員"),

    # The pager between the pages of one archive day: earlier and later lines,
    # not a previous and next step in a flow.
    "← Earlier":    ("← Antes", "← Antes", "← Antes", "← Plus tôt", "← Früher", "← Prima", "← Eerder", "← Wcześniej", "← Раньше", "← Sebelumnya", "← 前へ", "← 更早", "← 更早"),
    "Later →":      ("Depois →", "Depois →", "Después →", "Plus tard →", "Später →", "Dopo →", "Later →", "Później →", "Позже →", "Berikutnya →", "次へ →", "更晚 →", "更晚 →"),
    "Back":         ("Voltar", "Voltar", "Atrás", "Retour", "Zurück", "Indietro", "Terug", "Wstecz", "Назад", "Kembali", "戻る", "返回", "返回"),
    "Next":         ("Próximo", "Próximo", "Siguiente", "Suivant", "Weiter", "Avanti", "Volgende", "Dalej", "Далее", "Berikutnya", "次へ", "下一步", "下一步"),
    "Previous":     ("Anterior", "Anterior", "Anterior", "Précédent", "Zurück", "Precedente", "Vorige", "Poprzedni", "Назад", "Sebelumnya", "前へ", "上一步", "上一步"),
    "Open":         ("Abrir", "Abrir", "Abrir", "Ouvrir", "Öffnen", "Apri", "Openen", "Otwórz", "Открыть", "Buka", "開く", "打开", "開啟"),
    "Search":       ("Pesquisar", "Procurar", "Buscar", "Rechercher", "Suchen", "Cerca", "Zoeken", "Szukaj", "Поиск", "Cari", "検索", "搜索", "搜尋"),
    "Find":         ("Localizar", "Localizar", "Buscar", "Rechercher", "Suchen", "Trova", "Zoeken", "Znajdź", "Найти", "Temukan", "検索", "查找", "尋找"),

    # ── Editing ───────────────────────────────────────────────
    "Edit":         ("Editar", "Editar", "Editar", "Modifier", "Bearbeiten", "Modifica", "Bewerken", "Edytuj", "Изменить", "Sunting", "編集", "编辑", "編輯"),
    "Delete":       ("Excluir", "Eliminar", "Eliminar", "Supprimer", "Löschen", "Elimina", "Verwijderen", "Usuń", "Удалить", "Hapus", "削除", "删除", "刪除"),
    "Remove":       ("Remover", "Remover", "Quitar", "Retirer", "Entfernen", "Rimuovi", "Verwijderen", "Usuń", "Удалить", "Hapus", "削除", "移除", "移除"),
    "Add":          ("Adicionar", "Adicionar", "Añadir", "Ajouter", "Hinzufügen", "Aggiungi", "Toevoegen", "Dodaj", "Добавить", "Tambah", "追加", "添加", "新增"),
    "Copy":         ("Copiar", "Copiar", "Copiar", "Copier", "Kopieren", "Copia", "Kopiëren", "Kopiuj", "Копировать", "Salin", "コピー", "复制", "複製"),
    "Paste":        ("Colar", "Colar", "Pegar", "Coller", "Einfügen", "Incolla", "Plakken", "Wklej", "Вставить", "Tempel", "貼り付け", "粘贴", "貼上"),
    "Cut":          ("Recortar", "Cortar", "Cortar", "Couper", "Ausschneiden", "Taglia", "Knippen", "Wytnij", "Вырезать", "Potong", "切り取り", "剪切", "剪下"),
    "Rename":       ("Renomear", "Renomear", "Cambiar nombre", "Renommer", "Umbenennen", "Rinomina", "Naam wijzigen", "Zmień nazwę", "Переименовать", "Ganti nama", "名前を変更", "重命名", "重新命名"),
    "Clear":        ("Limpar", "Limpar", "Borrar", "Effacer", "Löschen", "Cancella", "Wissen", "Wyczyść", "Очистить", "Bersihkan", "クリア", "清除", "清除"),
    "Reset":        ("Redefinir", "Repor", "Restablecer", "Réinitialiser", "Zurücksetzen", "Reimposta", "Herstellen", "Resetuj", "Сбросить", "Atur ulang", "リセット", "重置", "重設"),
    "Refresh":      ("Atualizar", "Atualizar", "Actualizar", "Actualiser", "Aktualisieren", "Aggiorna", "Vernieuwen", "Odśwież", "Обновить", "Segarkan", "更新", "刷新", "重新整理"),

    # ── Reordering a row in place ─────────────────────────────
    # Two labels that only ever appear as the accessible name of an arrow
    # button, so there is no sentence to disambiguate them. The engine read
    # "Move up" as the intransitive "to rise" in pt_BR ("Subir") and lost the
    # pairing with "Move down", which it kept transitive.
    "Move up":      ("Mover para cima", "Mover para cima", "Mover arriba", "Déplacer vers le haut", "Nach oben verschieben", "Sposta su", "Omhoog verplaatsen", "Przenieś w górę", "Переместить вверх", "Pindahkan ke atas", "上に移動", "上移", "上移"),
    "Move down":    ("Mover para baixo", "Mover para baixo", "Mover abajo", "Déplacer vers le bas", "Nach unten verschieben", "Sposta giù", "Omlaag verplaatsen", "Przenieś w dół", "Переместить вниз", "Pindahkan ke bawah", "下に移動", "下移", "下移"),

    # ── Rows that are controls ────────────────────────────────
    # "Rooms" names chat channels, and every engine read it as lodging:
    # "Quartos", "Habitaciones", "Chambres", "Zimmer", "客室案内". "Action List"
    # is the component's own name, which German turned into "Artikel".
    "Rooms":        ("Salas", "Salas", "Salas", "Salons", "Räume", "Stanze", "Ruimtes", "Pokoje", "Комнаты", "Ruang", "ルーム", "房间", "房間"),
    "Action List":  ("Lista de Ações", "Lista de Ações", "Lista de acciones", "Liste d'actions", "Aktionsliste", "Elenco azioni", "Actielijst", "Lista akcji", "Список действий", "Daftar Tindakan", "アクションリスト", "操作列表", "操作清單"),

    # The accessible name of a row's remove button. Two words and a placeholder,
    # so the engine has no sentence to read the word order from, and German,
    # Dutch and Japanese all put the verb after the subject.
    "Remove %{nickname}": ("Remover %{nickname}", "Remover %{nickname}", "Quitar %{nickname}", "Retirer %{nickname}", "%{nickname} entfernen", "Rimuovi %{nickname}", "%{nickname} verwijderen", "Usuń %{nickname}", "Удалить %{nickname}", "Hapus %{nickname}", "%{nickname} を削除", "移除 %{nickname}", "移除 %{nickname}"),
    "Remove %{mask}": ("Remover %{mask}", "Remover %{mask}", "Quitar %{mask}", "Retirer %{mask}", "%{mask} entfernen", "Rimuovi %{mask}", "%{mask} verwijderen", "Usuń %{mask}", "Удалить %{mask}", "Hapus %{mask}", "%{mask} を削除", "移除 %{mask}", "移除 %{mask}"),
    "Remove %{name}": ("Remover %{name}", "Remover %{name}", "Quitar %{name}", "Retirer %{name}", "%{name} entfernen", "Rimuovi %{name}", "%{name} verwijderen", "Usuń %{name}", "Удалить %{name}", "Hapus %{name}", "%{name} を削除", "移除 %{name}", "移除 %{name}"),
    "Remove %{channel}": ("Remover %{channel}", "Remover %{channel}", "Quitar %{channel}", "Retirer %{channel}", "%{channel} entfernen", "Rimuovi %{channel}", "%{channel} verwijderen", "Usuń %{channel}", "Удалить %{channel}", "Hapus %{channel}", "%{channel} を削除", "移除 %{channel}", "移除 %{channel}"),
    "Remove %{word}": ("Remover %{word}", "Remover %{word}", "Quitar %{word}", "Retirer %{word}", "%{word} entfernen", "Rimuovi %{word}", "%{word} verwijderen", "Usuń %{word}", "Удалить %{word}", "Hapus %{word}", "%{word} を削除", "移除 %{word}", "移除 %{word}"),
    "Move %{name} up": ("Mover %{name} para cima", "Mover %{name} para cima", "Mover %{name} arriba", "Déplacer %{name} vers le haut", "%{name} nach oben verschieben", "Sposta %{name} su", "%{name} omhoog verplaatsen", "Przenieś %{name} w górę", "Переместить %{name} вверх", "Pindahkan %{name} ke atas", "%{name} を上に移動", "上移 %{name}", "上移 %{name}"),
    "Move %{name} down": ("Mover %{name} para baixo", "Mover %{name} para baixo", "Mover %{name} abajo", "Déplacer %{name} vers le bas", "%{name} nach unten verschieben", "Sposta %{name} giù", "%{name} omlaag verplaatsen", "Przenieś %{name} w dół", "Переместить %{name} вниз", "Pindahkan %{name} ke bawah", "%{name} を下に移動", "下移 %{name}", "下移 %{name}"),
    "Stop %{timer}": ("Parar %{timer}", "Parar %{timer}", "Detener %{timer}", "Arrêter %{timer}", "%{timer} stoppen", "Ferma %{timer}", "%{timer} stoppen", "Zatrzymaj %{timer}", "Остановить %{timer}", "Hentikan %{timer}", "%{timer} を停止", "停止 %{timer}", "停止 %{timer}"),
    "Edit %{nickname}": ("Editar %{nickname}", "Editar %{nickname}", "Editar %{nickname}", "Modifier %{nickname}", "%{nickname} bearbeiten", "Modifica %{nickname}", "%{nickname} bewerken", "Edytuj %{nickname}", "Изменить %{nickname}", "Sunting %{nickname}", "%{nickname} を編集", "编辑 %{nickname}", "編輯 %{nickname}"),
    "Remove rule %{position}": ("Remover a regra %{position}", "Remover a regra %{position}", "Quitar la regla %{position}", "Retirer la règle %{position}", "Regel %{position} entfernen", "Rimuovi la regola %{position}", "Regel %{position} verwijderen", "Usuń regułę %{position}", "Удалить правило %{position}", "Hapus aturan %{position}", "ルール %{position} を削除", "移除规则 %{position}", "移除規則 %{position}"),

    # Two settings labels the engine had already collapsed onto one Japanese
    # word — 免責事項, "disclaimer" — which it also gave Dismiss and Permanent,
    # so none of the three could be told apart. Russian had turned Disable into
    # "инвалид", the noun for a disabled person, and Spanish into a noun where
    # the control is a verb.
    "Disable":      ("Desativar", "Desativar", "Desactivar", "Désactiver", "Deaktivieren", "Disattiva", "Uitschakelen", "Wyłącz", "Отключить", "Nonaktifkan", "無効にする", "禁用", "停用"),
    "Permanent":    ("Permanente", "Permanente", "Permanente", "Permanent", "Dauerhaft", "Permanente", "Permanent", "Stały", "Постоянно", "Permanen", "無期限", "永久", "永久"),

    # The flood miniature's own caption. Short, and two placeholders with no
    # sentence around them to read word order from: half the locales came back
    # with "lines %{count}", and "lines" arrived as the geometric kind —
    # "linhas", "线", "Linien" — rather than lines of text. German dropped the
    # word "muted" altogether, which is the only word that matters.
    "muted after %{count} lines in %{window} seconds": ("silenciado após %{count} linhas em %{window} segundos", "silenciado após %{count} linhas em %{window} segundos", "silenciado tras %{count} líneas en %{window} segundos", "muet après %{count} lignes en %{window} secondes", "stumm nach %{count} Zeilen in %{window} Sekunden", "silenziato dopo %{count} righe in %{window} secondi", "gedempt na %{count} regels in %{window} seconden", "wyciszony po %{count} wierszach w %{window} s", "молчание после %{count} строк за %{window} с", "dibisukan setelah %{count} baris dalam %{window} detik", "%{window}秒間に%{count}行でミュート", "%{window} 秒内 %{count} 行后禁言", "%{window} 秒內 %{count} 行後禁言"),

    # The notify miniature's three captions: two words and a placeholder, so
    # the engine has no sentence to read tense from. "posted" came back as a
    # past participle rather than a verb everywhere — "publicado", "affiché",
    # "veröffentlicht" — and Spanish gave up. Dutch really does say "is
    # offline", which the source-fallback gate cannot tell from an untranslated
    # entry — so the source says "is now online", which is also what the notice
    # means: it fires on the change, not on a state.
    "%{nick} is now online": ("%{nick} está online agora", "%{nick} está online agora", "%{nick} ya está en línea", "%{nick} est maintenant en ligne", "%{nick} ist jetzt online", "%{nick} è ora online", "%{nick} is nu online", "%{nick} jest teraz online", "%{nick} сейчас в сети", "%{nick} sekarang daring", "%{nick} が今オンライン", "%{nick} 现已在线", "%{nick} 現已線上"),
    "%{nick} is now offline": ("%{nick} está offline agora", "%{nick} está offline agora", "%{nick} ya está desconectado", "%{nick} est maintenant hors ligne", "%{nick} ist jetzt offline", "%{nick} è ora offline", "%{nick} is nu offline", "%{nick} jest teraz offline", "%{nick} сейчас не в сети", "%{nick} sekarang luring", "%{nick} が今オフライン", "%{nick} 现已离线", "%{nick} 現已離線"),
    "%{nick} posted": ("%{nick} publicou", "%{nick} publicou", "%{nick} publicó", "%{nick} a publié", "%{nick} hat gepostet", "%{nick} ha pubblicato", "%{nick} plaatste", "%{nick} opublikował", "%{nick} опубликовал", "%{nick} membagikan", "%{nick} が投稿", "%{nick} 发布了", "%{nick} 發佈了"),

    # ── Transfer ──────────────────────────────────────────────
    "Say":          ("Falar", "Dizer", "Decir", "Dire", "Sagen", "Di'", "Zeggen", "Powiedz", "Сказать", "Ucapkan", "話す", "说", "說"),
    "Change character": ("Trocar personagem", "Mudar de personagem", "Cambiar de personaje", "Changer de personnage", "Figur wechseln", "Cambia personaggio", "Personage wisselen", "Zmień postać", "Сменить персонажа", "Ganti karakter", "キャラクターを変更", "更换角色", "更換角色"),
    "Send":         ("Enviar", "Enviar", "Enviar", "Envoyer", "Senden", "Invia", "Verzenden", "Wyślij", "Отправить", "Kirim", "送信", "发送", "傳送"),
    "Upload":       ("Enviar", "Carregar", "Subir", "Téléverser", "Hochladen", "Carica", "Uploaden", "Prześlij", "Загрузить", "Unggah", "アップロード", "上传", "上傳"),
    "Download":     ("Baixar", "Transferir", "Descargar", "Télécharger", "Herunterladen", "Scarica", "Downloaden", "Pobierz", "Скачать", "Unduh", "ダウンロード", "下载", "下載"),
    "Export":       ("Exportar", "Exportar", "Exportar", "Exporter", "Exportieren", "Esporta", "Exporteren", "Eksportuj", "Экспорт", "Ekspor", "エクスポート", "导出", "匯出"),

    # ── Article credit line ───────────────────────────────────
    # Almost entirely placeholder, so the engine has nothing to work with and
    # hands the English straight back: "%{count}h ago" came out unchanged in
    # German and Spanish, "%{count} min read" unchanged in Indonesian. The unit
    # abbreviation is also a per-language convention rather than a translation —
    # Dutch shortens hours to "u", French days to "j", German to "T".
    "%{count}m ago":     ("há %{count}min", "há %{count}min", "hace %{count}min", "il y a %{count}min", "vor %{count}min", "%{count}min fa", "%{count}min geleden", "%{count}min temu", "%{count}мин назад", "%{count}mnt lalu", "%{count}分前", "%{count}分钟前", "%{count}分鐘前"),
    "%{count}h ago":     ("há %{count}h", "há %{count}h", "hace %{count}h", "il y a %{count}h", "vor %{count}h", "%{count}h fa", "%{count}u geleden", "%{count}godz. temu", "%{count}ч назад", "%{count}j lalu", "%{count}時間前", "%{count}小时前", "%{count}小時前"),
    "%{count}d ago":     ("há %{count}d", "há %{count}d", "hace %{count}d", "il y a %{count}j", "vor %{count}T", "%{count}g fa", "%{count}d geleden", "%{count}dni temu", "%{count}д назад", "%{count}h lalu", "%{count}日前", "%{count}天前", "%{count}天前"),
    "%{count} min read": ("%{count} min de leitura", "%{count} min de leitura", "%{count} min de lectura", "%{count} min de lecture", "%{count} Min. Lesezeit", "%{count} min di lettura", "%{count} min lezen", "%{count} min czytania", "%{count} мин чтения", "baca %{count} mnt", "読了 %{count}分", "阅读 %{count} 分钟", "閱讀 %{count} 分鐘"),
    # The card's own call to action, on every link a bot publishes and every
    # link a person pastes. Left to the engine it came back as the narrative
    # sense — "Ler a história completa", "Vollständige Geschichte lesen",
    # "读完整的故事" — a story being told rather than an article to open.
    "Read full story":   ("Ler artigo completo", "Ler artigo completo", "Leer artículo completo", "Lire l'article complet", "Ganzen Artikel lesen", "Leggi l'articolo completo", "Lees het hele artikel", "Przeczytaj cały artykuł", "Читать полностью", "Baca selengkapnya", "全文を読む", "阅读全文", "閱讀全文"),

    # ── Long lists ────────────────────────────────────────────
    # The vocabulary every paginated list draws on. Curated here because these
    # are the labels a reader meets in fourteen different windows: they have to
    # read the same in all of them.
    "Load more":    ("Carregar mais", "Carregar mais", "Cargar más", "Charger plus", "Mehr laden", "Carica altri", "Meer laden", "Załaduj więcej", "Загрузить ещё", "Muat lebih banyak", "さらに読み込む", "加载更多", "載入更多"),
    "Load More":    ("Carregar mais", "Carregar mais", "Cargar más", "Charger plus", "Mehr laden", "Carica altri", "Meer laden", "Załaduj więcej", "Загрузить ещё", "Muat lebih banyak", "さらに読み込む", "加载更多", "載入更多"),
    "Try again":    ("Tentar novamente", "Tentar novamente", "Reintentar", "Réessayer", "Erneut versuchen", "Riprova", "Opnieuw proberen", "Spróbuj ponownie", "Повторить попытку", "Coba lagi", "再試行", "重试", "重試"),
    "End of list":  ("Fim da lista", "Fim da lista", "Fin de la lista", "Fin de la liste", "Ende der Liste", "Fine dell'elenco", "Einde van de lijst", "Koniec listy", "Конец списка", "Akhir daftar", "リストの終わり", "列表结束", "清單結束"),
    "Revoke":       ("Revogar", "Revogar", "Revocar", "Révoquer", "Widerrufen", "Revoca", "Intrekken", "Odwołaj", "Отозвать", "Cabut", "失効", "撤销", "撤銷"),

    # ── Listings ──────────────────────────────────────────────
    # The header menu every table carries. "Columns" alone is the word a model
    # is most likely to read as the architectural one, and the Chinese pair
    # genuinely differ: 列 in Simplified against 欄 in Traditional.
    "Columns":            ("Colunas", "Colunas", "Columnas", "Colonnes", "Spalten", "Colonne", "Kolommen", "Kolumny", "Столбцы", "Kolom", "列", "列", "欄"),
    # Headings of the listing help, and the clearest case in the file for why
    # this table exists. "Ordering" alone reads as a purchase to a model:
    # it came back as "Bestellung", "Commande", "Zamówienia", "заказывать" and
    # "注文する" — an order placed, not rows put in order. "Column" fared no
    # better: German and Russian both chose the pillar ("Säulen", "колонны").
    "Ordering":           ("Ordenação", "Ordenação", "Ordenación", "Tri", "Sortierung", "Ordinamento", "Sorteren", "Sortowanie", "Сортировка", "Pengurutan", "並べ替え", "排序", "排序"),
    "Column Width":       ("Largura da coluna", "Largura da coluna", "Ancho de columna", "Largeur de colonne", "Spaltenbreite", "Larghezza colonna", "Kolombreedte", "Szerokość kolumny", "Ширина столбца", "Lebar kolom", "列の幅", "列宽", "欄寬"),
    "Choosing Columns":   ("Escolher colunas", "Escolher colunas", "Elegir columnas", "Choisir les colonnes", "Spalten auswählen", "Scegliere le colonne", "Kolommen kiezen", "Wybór kolumn", "Выбор столбцов", "Memilih kolom", "列の選択", "选择列", "選擇欄"),
    # An ampersand in the source is its own hazard: Spanish came back with the
    # HTML entity ("Listas &quot; Tablas &quot;") and Chinese with a stray
    # accelerator ("正在选择复制( C)").
    "Listings & Tables":  ("Listagens e tabelas", "Listagens e tabelas", "Listados y tablas", "Listes et tableaux", "Listen und Tabellen", "Elenchi e tabelle", "Lijsten en tabellen", "Listy i tabele", "Списки и таблицы", "Daftar dan tabel", "一覧と表", "列表与表格", "列表與表格"),
    "Selecting & Copying": ("Selecionar e copiar", "Selecionar e copiar", "Seleccionar y copiar", "Sélectionner et copier", "Auswählen und kopieren", "Selezionare e copiare", "Selecteren en kopiëren", "Zaznaczanie i kopiowanie", "Выделение и копирование", "Memilih dan menyalin", "選択とコピー", "选择与复制", "選擇與複製"),
    "Show all columns":   ("Mostrar todas as colunas", "Mostrar todas as colunas", "Mostrar todas las columnas", "Afficher toutes les colonnes", "Alle Spalten anzeigen", "Mostra tutte le colonne", "Alle kolommen tonen", "Pokaż wszystkie kolumny", "Показать все столбцы", "Tampilkan semua kolom", "すべての列を表示", "显示所有列", "顯示所有欄"),
    "Forget":       ("Esquecer", "Esquecer", "Olvidar", "Oublier", "Vergessen", "Dimentica", "Vergeten", "Zapomnij", "Забыть", "Lupakan", "削除", "忘记", "忘記"),

    # ── Background jobs ───────────────────────────────────────
    # A job state, not a description of one. Left to the pipeline "retryable"
    # came back as "réutilisable" (reusable), "do regeneracji" (for
    # regeneration) and "перезаряжаемый" (rechargeable), and four locales gave
    # up and kept the English.
    "%{count} retryable":  ("%{count} a repetir", "%{count} a repetir", "%{count} reintentables", "%{count} à réessayer", "%{count} wiederholbar", "%{count} da riprovare", "%{count} opnieuw te proberen", "%{count} do ponowienia", "%{count} к повтору", "%{count} dapat dicoba lagi", "%{count} 件再試行可能", "%{count} 可重试", "%{count} 可重試"),

    # ── Terms that are names, not words ───────────────────────
    # Acronyms and protocol nouns. Left to the pipeline they collapse onto
    # whatever ordinary word looks nearest: "RSS", "IO" and "Wallops" all
    # became "Autres" in French, which is not a mistranslation so much as a
    # deletion. They are the same string in every locale because they are
    # names.
    "RSS":          ("RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS", "RSS"),
    "IO":           ("IO", "IO", "IO", "IO", "IO", "IO", "IO", "IO", "IO", "IO", "IO", "IO", "IO"),
    "Wallops":      ("Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops", "Wallops"),
    "ETS":          ("ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS", "ETS"),
    "CPU":          ("CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "ЦП", "CPU", "CPU", "CPU", "CPU"),

    # ── Diagnostics panes ─────────────────────────────────────
    # Section headings in the link-preview dialog. One word each, with no
    # sentence around them, which is the shape the pipeline reads worst.
    "Overview":     ("Visão geral", "Visão geral", "Resumen", "Vue d'ensemble", "Überblick", "Panoramica", "Overzicht", "Przegląd", "Обзор", "Ikhtisar", "概要", "概览", "概覽"),
    "Persistence":  ("Persistência", "Persistência", "Persistencia", "Persistance", "Persistenz", "Persistenza", "Persistentie", "Trwałość", "Хранение", "Persistensi", "永続化", "持久化", "持久化"),
    "Previews":     ("Prévias", "Pré-visualizações", "Vistas previas", "Aperçus", "Vorschauen", "Anteprime", "Voorbeelden", "Podglądy", "Предпросмотры", "Pratinjau", "プレビュー", "预览", "預覽"),

    # ── Application chrome ────────────────────────────────────
    "Help":         ("Ajuda", "Ajuda", "Ayuda", "Aide", "Hilfe", "Aiuto", "Help", "Pomoc", "Справка", "Bantuan", "ヘルプ", "帮助", "說明"),
    "Settings":     ("Configurações", "Definições", "Ajustes", "Paramètres", "Einstellungen", "Impostazioni", "Instellingen", "Ustawienia", "Настройки", "Pengaturan", "設定", "设置", "設定"),
    "About":        ("Sobre", "Sobre", "Acerca de", "À propos", "Über", "Informazioni", "Over", "O programie", "О программе", "Tentang", "バージョン情報", "关于", "關於"),
    "Menu":         ("Menu", "Menu", "Menú", "Menu", "Menü", "Menu", "Menu", "Menu", "Меню", "Menu", "メニュー", "菜单", "選單"),
    "File":         ("Arquivo", "Ficheiro", "Archivo", "Fichier", "Datei", "File", "Bestand", "Plik", "Файл", "Berkas", "ファイル", "文件", "檔案"),
    "View":         ("Exibir", "Ver", "Ver", "Affichage", "Ansicht", "Visualizza", "Beeld", "Widok", "Вид", "Tampilan", "表示", "视图", "檢視"),
    "Exit":         ("Sair", "Sair", "Salir", "Quitter", "Beenden", "Esci", "Afsluiten", "Zakończ", "Выход", "Keluar", "終了", "退出", "結束"),
    # Every catalog had kept "Windows" literal: with no sentence around it the
    # pipeline read the operating system, not the things on a desktop. As a Start
    # menu group it is the plural of "window" and has to translate.
    "Windows":      ("Janelas", "Janelas", "Ventanas", "Fenêtres", "Fenster", "Finestre", "Vensters", "Okna", "Окна", "Jendela", "ウィンドウ", "窗口", "視窗"),
    "No windows":   ("Nenhuma janela", "Nenhuma janela", "Sin ventanas", "Aucune fenêtre", "Keine Fenster", "Nessuna finestra", "Geen vensters", "Brak okien", "Нет окон", "Tidak ada jendela", "ウィンドウなし", "无窗口", "無視窗"),
    "Navigate":     ("Navegar", "Navegar", "Navegar", "Naviguer", "Navigieren", "Naviga", "Navigeren", "Nawigacja", "Навигация", "Navigasi", "移動", "导航", "導覽"),
    # Left to the pipeline the menu's own name came back as "Язык языка" and
    # "日本語 English": one word, no sentence, and the model guessed.
    "Language":     ("Idioma", "Língua", "Idioma", "Langue", "Sprache", "Lingua", "Taal", "Język", "Язык", "Bahasa", "言語", "语言", "語言"),
    "Automation":   ("Automação", "Automação", "Automatización", "Automatisation", "Automatisierung", "Automazione", "Automatisering", "Automatyzacja", "Автоматизация", "Otomatisasi", "自動化", "自动化", "自動化"),

    # ── Connection ────────────────────────────────────────────
    "Connect":      ("Conectar", "Ligar", "Conectar", "Se connecter", "Verbinden", "Connetti", "Verbinden", "Połącz", "Подключиться", "Hubungkan", "接続", "连接", "連線"),
    "Disconnect":   ("Desconectar", "Desligar", "Desconectar", "Se déconnecter", "Trennen", "Disconnetti", "Verbinding verbreken", "Rozłącz", "Отключиться", "Putuskan", "切断", "断开", "斷線"),
    "Connected":    ("Conectado", "Ligado", "Conectado", "Connecté", "Verbunden", "Connesso", "Verbonden", "Połączono", "Подключено", "Terhubung", "接続済み", "已连接", "已連線"),
    "Disconnected": ("Desconectado", "Desligado", "Desconectado", "Déconnecté", "Getrennt", "Disconnesso", "Verbinding verbroken", "Rozłączono", "Отключено", "Terputus", "切断済み", "已断开", "已斷線"),
    # Call and session states, shown after the button's name ("Group Call · In
    # progress"). Adjectives agree with that name: feminine where the call is
    # (Chamada, Llamada, Chiamata, Rozmowa), masculine in French and Russian.
    "In progress":  ("Em andamento", "Em curso", "En curso", "En cours", "Läuft", "In corso", "Bezig", "W toku", "Идёт", "Berlangsung", "進行中", "进行中", "進行中"),
    # The people in a call, and the emoji category of the same name — one
    # word that reads for both ("スタッフ", staff, had come back for every one).
    "People":       ("Pessoas", "Pessoas", "Personas", "Personnes", "Personen", "Persone", "Personen", "Osoby", "Люди", "Orang", "人物", "人员", "人員"),
    # The call layout that puts one person large ("Objectif", "Schwerpunkt").
    "Focus":        ("Foco", "Foco", "Enfoque", "Focus", "Fokus", "Focus", "Focus", "Fokus", "Фокус", "Fokus", "フォーカス", "焦点", "焦點"),
    # Registering a nickname or a channel — not signing up as a member
    # ("会員登録") nor logging in ("Anmeldung").
    "Registration": ("Registro", "Registo", "Registro", "Enregistrement", "Registrierung", "Registrazione", "Registratie", "Rejestracja", "Регистрация", "Pendaftaran", "登録", "注册", "註冊"),
    "Pending":      ("Pendente", "Pendente", "Pendiente", "En attente", "Ausstehend", "In attesa", "In afwachting", "Oczekuje", "Ожидает", "Tertunda", "保留中", "待处理", "待處理"),
    "Full":         ("Lotada", "Lotada", "Llena", "Complet", "Voll", "Piena", "Vol", "Pełna", "Заполнен", "Penuh", "満員", "已满", "已滿"),
    "Locked":       ("Trancada", "Trancada", "Bloqueada", "Verrouillé", "Gesperrt", "Bloccata", "Vergrendeld", "Zablokowana", "Заперт", "Terkunci", "ロック中", "已锁定", "已鎖定"),
    "Degraded":     ("Instável", "Instável", "Inestable", "Instable", "Instabil", "Instabile", "Instabiel", "Niestabilna", "Нестабилен", "Tidak stabil", "不安定", "不稳定", "不穩定"),
    "Ending":       ("Encerrando", "A terminar", "Finalizando", "Se termine", "Wird beendet", "In chiusura", "Wordt beëindigd", "Kończy się", "Завершается", "Berakhir", "終了中", "正在结束", "正在結束"),
    "Connecting":   ("Conectando", "A ligar", "Conectando", "Connexion", "Verbindung wird hergestellt", "Connessione", "Verbinden", "Łączenie", "Подключение", "Menghubungkan", "接続中", "连接中", "連線中"),
    "Reconnecting": ("Reconectando", "A reconectar", "Reconectando", "Reconnexion", "Erneut verbinden", "Riconnessione", "Opnieuw verbinden", "Ponowne łączenie", "Переподключение", "Menghubungkan ulang", "再接続中", "重新连接中", "重新連線中"),

    # ── Status ────────────────────────────────────────────────
    "Ready":        ("Pronto", "Pronto", "Listo", "Prêt", "Bereit", "Pronto", "Gereed", "Gotowy", "Готово", "Siap", "準備完了", "就绪", "就緒"),
    "Away":         ("Ausente", "Ausente", "Ausente", "Absent", "Abwesend", "Assente", "Afwezig", "Nieobecny", "Отошёл", "Tidak di tempat", "離席中", "离开", "離開"),
    "Idle":         ("Inativo", "Inativo", "Inactivo", "Inactif", "Inaktiv", "Inattivo", "Inactief", "Bezczynny", "Неактивен", "Diam", "アイドル", "空闲", "閒置"),
    "Online":       ("Online", "Online", "En línea", "En ligne", "Online", "Online", "Online", "Online", "В сети", "Daring", "オンライン", "在线", "線上"),
    "Offline":      ("Offline", "Offline", "Sin conexión", "Hors ligne", "Offline", "Offline", "Offline", "Offline", "Не в сети", "Luring", "オフライン", "离线", "離線"),
    # The user-list heading over the people watching a channel without an
    # account.
    "Visitors":        ("Visitantes", "Visitantes", "Visitantes", "Visiteurs", "Besucher", "Visitatori", "Bezoekers", "Odwiedzający", "Посетители", "Pengunjung", "訪問者", "访客", "訪客"),
    "Loading":      ("Carregando", "A carregar", "Cargando", "Chargement", "Wird geladen", "Caricamento", "Laden", "Ładowanie", "Загрузка", "Memuat", "読み込み中", "加载中", "載入中"),
    "Error":        ("Erro", "Erro", "Error", "Erreur", "Fehler", "Errore", "Fout", "Błąd", "Ошибка", "Kesalahan", "エラー", "错误", "錯誤"),
    "Warning":      ("Aviso", "Aviso", "Advertencia", "Avertissement", "Warnung", "Avviso", "Waarschuwing", "Ostrzeżenie", "Предупреждение", "Peringatan", "警告", "警告", "警告"),
    "Failed":       ("Falhou", "Falhou", "Falló", "Échec", "Fehlgeschlagen", "Non riuscito", "Mislukt", "Niepowodzenie", "Не удалось", "Gagal", "失敗", "失败", "失敗"),
    "Success":      ("Sucesso", "Sucesso", "Éxito", "Succès", "Erfolg", "Successo", "Gelukt", "Powodzenie", "Успешно", "Berhasil", "成功", "成功", "成功"),

    # A nickname's identity card reads one of these three words, so they have
    # to be three distinguishable words in every locale. Left to the engine,
    # "unclaimed" landed on the same ja term as Disable, Dismiss and Permanent.
    "verified":     ("verificado", "verificado", "verificado", "vérifié", "bestätigt", "verificato", "geverifieerd", "zweryfikowany", "подтверждён", "terverifikasi", "確認済み", "已验证", "已驗證"),
    "not verified": ("não verificado", "não verificado", "sin verificar", "non vérifié", "nicht bestätigt", "non verificato", "niet geverifieerd", "niezweryfikowany", "не подтверждён", "belum terverifikasi", "未確認", "未验证", "未驗證"),
    "unclaimed":    ("sem dono", "sem dono", "sin dueño", "non réclamé", "nicht beansprucht", "non reclamato", "niet geclaimd", "nieprzypisany", "не занят", "belum diklaim", "未登録", "未认领", "未認領"),
    "founder":      ("fundador", "fundador", "fundador", "fondateur", "Gründer", "fondatore", "oprichter", "założyciel", "основатель", "pendiri", "設立者", "创建者", "建立者"),

    # ── Sharing a surface ─────────────────────────────────────
    # A share link is followed by people who may never have seen this product,
    # so these are the labels an outsider reads first.
    #
    # There is deliberately no "Enter" here: every other catalog already reads
    # that as the keyboard key — "Entrée", "Eingabe" — and a glossary is global
    # across domains. Going into a room reuses the curated "Join" instead of
    # inventing a synonym for it, which is what a glossary is for.
    "Share":        ("Compartilhar", "Partilhar", "Compartir", "Partager", "Teilen", "Condividi", "Delen", "Udostępnij", "Поделиться", "Bagikan", "共有", "分享", "分享"),
    "Share link":   ("Link de compartilhamento", "Ligação de partilha", "Enlace para compartir", "Lien de partage", "Freigabelink", "Link di condivisione", "Deellink", "Link do udostępnienia", "Ссылка для доступа", "Tautan berbagi", "共有リンク", "分享链接", "分享連結"),
    "Connect and join": ("Conectar e entrar", "Ligar e entrar", "Conectar y entrar", "Se connecter et rejoindre", "Verbinden und beitreten", "Connetti ed entra", "Verbinden en deelnemen", "Połącz i dołącz", "Подключиться и войти", "Hubungkan dan gabung", "接続して参加", "连接并加入", "連線並加入"),
    "Open the chat": ("Abrir o chat", "Abrir o chat", "Abrir el chat", "Ouvrir le chat", "Chat öffnen", "Apri la chat", "Chat openen", "Otwórz czat", "Открыть чат", "Buka obrolan", "チャットを開く", "打开聊天", "開啟聊天"),
    "Link expired": ("Link expirado", "Ligação expirada", "Enlace caducado", "Lien expiré", "Link abgelaufen", "Link scaduto", "Link verlopen", "Link wygasł", "Ссылка истекла", "Tautan kedaluwarsa", "リンクの有効期限切れ", "链接已失效", "連結已失效"),

    # ── A surface in its own tab ──────────────────────────────
    # "Chat" is deliberately absent: it already has a translation per domain,
    # and a glossary entry is global — adding one here would rewrite the word
    # in every catalog that already chose it, which is the mistake "Enter"
    # nearly made above.
    "Open in a tab": ("Abrir em uma aba", "Abrir num separador", "Abrir en una pestaña", "Ouvrir dans un onglet", "In einem Tab öffnen", "Apri in una scheda", "In een tabblad openen", "Otwórz w karcie", "Открыть во вкладке", "Buka di tab", "タブで開く", "在标签页中打开", "在分頁中開啟"),
    "Already inside": ("Já estão dentro", "Já estão dentro", "Ya están dentro", "Déjà dans la salle", "Bereits im Raum", "Già dentro", "Al binnen", "Już w środku", "Уже внутри", "Sudah di dalam", "すでに参加中", "已在房间内", "已在房間內"),

    # ── The P2P session, named the same way everywhere ─────────
    # These three are here because they had drifted apart: one msgid carried
    # two different translations depending on the domain it was extracted
    # into, and `gettext.merge` then fuzzy-matched a fourth string onto one of
    # them. A glossary entry is global, so it is the only thing that keeps the
    # name of a feature identical across every catalog that mentions it.
    # German said "Sitzungsperiode" (a period of time) and Chinese said
    # "conference" for the session itself; both are corrected here.
    "Group Call":   ("Chamada em grupo", "Chamada em grupo", "Llamada grupal", "Appel de groupe", "Gruppengespräch", "Chiamata di gruppo", "Groepsgesprek", "Rozmowa grupowa", "Групповой звонок", "Panggilan grup", "グループ通話", "群组通话", "群組通話"),
    "P2P Session":  ("Sessão P2P", "Sessão P2P", "Sesión P2P", "Session P2P", "P2P-Sitzung", "Sessione P2P", "P2P-sessie", "Sesja P2P", "P2P-сессия", "Sesi P2P", "P2Pセッション", "P2P 会话", "P2P 工作階段"),
    "P2P Session Console": ("Console de Sessão P2P", "Consola de Sessão P2P", "Consola de Sesión P2P", "Console de session P2P", "P2P-Sitzungskonsole", "Console di sessione P2P", "P2P-sessieconsole", "Konsola sesji P2P", "Консоль P2P-сессии", "Konsol Sesi P2P", "P2Pセッションコンソール", "P2P 会话控制台", "P2P 工作階段主控台"),
    "P2P Sessions in Chat": ("Sessões P2P no chat", "Sessões P2P no chat", "Sesiones P2P en el chat", "Sessions P2P dans le chat", "P2P-Sitzungen im Chat", "Sessioni P2P nella chat", "P2P-sessies in de chat", "Sesje P2P w czacie", "P2P-сессии в чате", "Sesi P2P dalam Percakapan", "チャットでのP2Pセッション", "P2P 聊天会话", "P2P 聊天對話"),

    # ── Chat actions ──────────────────────────────────────────
    "Mute":         ("Silenciar", "Silenciar", "Silenciar", "Couper le son", "Stummschalten", "Disattiva audio", "Dempen", "Wycisz", "Отключить звук", "Bisukan", "ミュート", "静音", "靜音"),
    "Unmute":       ("Reativar som", "Reativar som", "Activar sonido", "Réactiver le son", "Stummschaltung aufheben", "Riattiva audio", "Dempen opheffen", "Wyłącz wyciszenie", "Включить звук", "Suarakan", "ミュート解除", "取消静音", "取消靜音"),
    "Join":         ("Entrar", "Entrar", "Unirse", "Rejoindre", "Beitreten", "Entra", "Deelnemen", "Dołącz", "Присоединиться", "Gabung", "参加", "加入", "加入"),
    "Leave":        ("Sair", "Sair", "Salir", "Quitter", "Verlassen", "Esci", "Verlaten", "Opuść", "Покинуть", "Keluar", "退出", "离开", "離開"),
    # A toggle is named by the thing it switches; "Toggle" itself came back
    # untranslated ("Toggle Mikrofon", "Микрофон Toggle", "トグルカメラ").
    "Toggle microphone": ("Ligar/desligar microfone", "Ligar/desligar microfone", "Activar/desactivar micrófono", "Activer/désactiver le micro", "Mikrofon ein/aus", "Attiva/disattiva microfono", "Microfoon aan/uit", "Włącz/wyłącz mikrofon", "Вкл./выкл. микрофон", "Nyalakan/matikan mikrofon", "マイクのオン/オフ", "开关麦克风", "開關麥克風"),
    "Toggle camera":     ("Ligar/desligar câmera", "Ligar/desligar câmara", "Activar/desactivar cámara", "Activer/désactiver la caméra", "Kamera ein/aus", "Attiva/disattiva fotocamera", "Camera aan/uit", "Włącz/wyłącz kamerę", "Вкл./выкл. камеру", "Nyalakan/matikan kamera", "カメラのオン/オフ", "开关摄像头", "開關攝影機"),
    "Leave call":   ("Sair da chamada", "Sair da chamada", "Salir de la llamada", "Quitter l'appel", "Anruf verlassen", "Esci dalla chiamata", "Gesprek verlaten", "Opuść rozmowę", "Покинуть звонок", "Keluar dari panggilan", "通話から退出", "离开通话", "離開通話"),
    "Moderation":   ("Moderação", "Moderação", "Moderación", "Modération", "Moderation", "Moderazione", "Moderatie", "Moderacja", "Модерация", "Moderasi", "モデレーション", "管理", "管理"),
    "Start":        ("Iniciar", "Iniciar", "Iniciar", "Démarrer", "Starten", "Avvia", "Starten", "Rozpocznij", "Начать", "Mulai", "開始", "开始", "開始"),
    "Stop":         ("Parar", "Parar", "Detener", "Arrêter", "Stoppen", "Ferma", "Stoppen", "Zatrzymaj", "Остановить", "Berhenti", "停止", "停止", "停止"),
    "Pause":        ("Pausar", "Pausar", "Pausar", "Pause", "Pause", "Pausa", "Pauzeren", "Wstrzymaj", "Пауза", "Jeda", "一時停止", "暂停", "暫停"),
    "Resume":       ("Retomar", "Retomar", "Reanudar", "Reprendre", "Fortsetzen", "Riprendi", "Hervatten", "Wznów", "Продолжить", "Lanjutkan", "再開", "继续", "繼續"),
    "Ignore":       ("Ignorar", "Ignorar", "Ignorar", "Ignorer", "Ignorieren", "Ignora", "Negeren", "Ignoruj", "Игнорировать", "Abaikan", "無視", "忽略", "忽略"),
    "React":        ("Reagir", "Reagir", "Reaccionar", "Réagir", "Reagieren", "Reagisci", "Reageren", "Zareaguj", "Отреагировать", "Bereaksi", "リアクション", "回应", "回應"),
    "React...":     ("Reagir...", "Reagir...", "Reaccionar...", "Réagir...", "Reagieren...", "Reagisci...", "Reageren...", "Zareaguj...", "Отреагировать...", "Bereaksi...", "リアクション...", "回应...", "回應..."),
    "Block":        ("Bloquear", "Bloquear", "Bloquear", "Bloquer", "Blockieren", "Blocca", "Blokkeren", "Zablokuj", "Заблокировать", "Blokir", "ブロック", "屏蔽", "封鎖"),
    # The first of what an account opens, in the card that greets a visitor:
    # writing in the chat, beside Space and Group Call.
    "Talk":         ("Conversar", "Conversar", "Conversar", "Discuter", "Chatten", "Chattare", "Chatten", "Rozmawiaj", "Общаться", "Mengobrol", "会話", "聊天", "聊天"),

    # ── Account ───────────────────────────────────────────────
    "Login":        ("Entrar", "Entrar", "Iniciar sesión", "Connexion", "Anmelden", "Accedi", "Inloggen", "Zaloguj", "Вход", "Masuk", "ログイン", "登录", "登入"),
    "Logout":       ("Sair", "Sair", "Cerrar sesión", "Déconnexion", "Abmelden", "Esci", "Uitloggen", "Wyloguj", "Выход", "Keluar", "ログアウト", "登出", "登出"),
    "Register":     ("Registrar", "Registar", "Registrarse", "S'inscrire", "Registrieren", "Registrati", "Registreren", "Zarejestruj", "Регистрация", "Daftar", "登録", "注册", "註冊"),
    "Username":     ("Nome de usuário", "Nome de utilizador", "Nombre de usuario", "Nom d'utilisateur", "Benutzername", "Nome utente", "Gebruikersnaam", "Nazwa użytkownika", "Имя пользователя", "Nama pengguna", "ユーザー名", "用户名", "使用者名稱"),
    "Password":     ("Senha", "Palavra-passe", "Contraseña", "Mot de passe", "Passwort", "Password", "Wachtwoord", "Hasło", "Пароль", "Kata sandi", "パスワード", "密码", "密碼"),
    "Name":         ("Nome", "Nome", "Nombre", "Nom", "Name", "Nome", "Naam", "Nazwa", "Имя", "Nama", "名前", "名称", "名稱"),
    # Distinct from Help on purpose: zh_hant uses 說明 for the Help menu, so a
    # description field must not land on the same word.
    "Description":  ("Descrição", "Descrição", "Descripción", "Description", "Beschreibung", "Descrizione", "Beschrijving", "Opis", "Описание", "Deskripsi", "説明", "描述", "描述"),
    "Status":       ("Status", "Estado", "Estado", "Statut", "Status", "Stato", "Status", "Status", "Статус", "Status", "ステータス", "状态", "狀態"),
    "Server":       ("Servidor", "Servidor", "Servidor", "Serveur", "Server", "Server", "Server", "Serwer", "Сервер", "Server", "サーバー", "服务器", "伺服器"),
    "Channel":      ("Canal", "Canal", "Canal", "Canal", "Kanal", "Canale", "Kanaal", "Kanał", "Канал", "Kanal", "チャンネル", "频道", "頻道"),

    # ── Text formatting ───────────────────────────────────────
    # The composer's toolbar. Every one of these came back from the engine as
    # the wrong sense: "Bold" as "Bolzen" (a metal bolt) in de, "Bulleted list"
    # as "Lista de balas" (bullets as ammunition) in pt_BR, "Write" as "ログイン"
    # in ja. A toolbar button has no sentence around it to disambiguate.
    "Bold":         ("Negrito", "Negrito", "Negrita", "Gras", "Fett", "Grassetto", "Vet", "Pogrubienie", "Полужирный", "Tebal", "太字", "粗体", "粗體"),
    "Italic":       ("Itálico", "Itálico", "Cursiva", "Italique", "Kursiv", "Corsivo", "Cursief", "Kursywa", "Курсив", "Miring", "斜体", "斜体", "斜體"),
    "Strikethrough": ("Tachado", "Tachado", "Tachado", "Barré", "Durchgestrichen", "Barrato", "Doorhalen", "Przekreślenie", "Зачёркнутый", "Coret", "取り消し線", "删除线", "刪除線"),
    "Code":         ("Código", "Código", "Código", "Code", "Code", "Codice", "Code", "Kod", "Код", "Kode", "コード", "代码", "程式碼"),
    "Quote":        ("Citação", "Citação", "Cita", "Citation", "Zitat", "Citazione", "Citaat", "Cytat", "Цитата", "Kutipan", "引用", "引用", "引用"),
    "Heading":      ("Título", "Título", "Encabezado", "Titre", "Überschrift", "Titolo", "Kop", "Nagłówek", "Заголовок", "Judul", "見出し", "标题", "標題"),
    "Link":         ("Link", "Ligação", "Enlace", "Lien", "Link", "Collegamento", "Link", "Odnośnik", "Ссылка", "Tautan", "リンク", "链接", "連結"),
    "Preview":      ("Visualizar", "Pré-visualizar", "Vista previa", "Aperçu", "Vorschau", "Anteprima", "Voorbeeld", "Podgląd", "Предпросмотр", "Pratinjau", "プレビュー", "预览", "預覽"),
    "Write":        ("Escrever", "Escrever", "Escribir", "Écrire", "Schreiben", "Scrivi", "Schrijven", "Pisz", "Написать", "Tulis", "作成", "编写", "編寫"),
    # A name, not a word: translating it produced "Marcação" in pt_BR and
    # "Markiert" in de, and collapsed onto "Notation" in both Chinese locales.
    "Markdown":     ("Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown", "Markdown"),

    # ── Attachment kinds ──────────────────────────────────────
    # File-type labels on an attachment card. "Office" is the product family
    # and stays literal; "Archive" is the compressed-file kind, kept distinct
    # from File so the two cards do not read the same.
    "Text":         ("Texto", "Texto", "Texto", "Texte", "Text", "Testo", "Tekst", "Tekst", "Текст", "Teks", "テキスト", "文本", "文字"),
    "Image":        ("Imagem", "Imagem", "Imagen", "Image", "Bild", "Immagine", "Afbeelding", "Obraz", "Изображение", "Gambar", "画像", "图片", "圖片"),
    "Audio":        ("Áudio", "Áudio", "Audio", "Audio", "Audio", "Audio", "Audio", "Dźwięk", "Аудио", "Audio", "音声", "音频", "音訊"),
    "Video":        ("Vídeo", "Vídeo", "Vídeo", "Vidéo", "Video", "Video", "Video", "Wideo", "Видео", "Video", "動画", "视频", "影片"),
    "PDF":          ("PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF", "PDF"),
    "Archive":      ("Compactado", "Compactado", "Comprimido", "Archive", "Archiv", "Archivio", "Archief", "Archiwum", "Архив", "Arsip", "アーカイブ", "压缩包", "壓縮檔"),
    "Office":       ("Office", "Office", "Office", "Office", "Office", "Office", "Office", "Office", "Office", "Office", "Office", "Office", "Office"),

    # ── Section and state labels ──────────────────────────────
    "Commands":     ("Comandos", "Comandos", "Comandos", "Commandes", "Befehle", "Comandi", "Opdrachten", "Polecenia", "Команды", "Perintah", "コマンド", "命令", "指令"),
    "Welcome":      ("Bem-vindo", "Bem-vindo", "Bienvenido", "Bienvenue", "Willkommen", "Benvenuto", "Welkom", "Witamy", "Добро пожаловать", "Selamat datang", "ようこそ", "欢迎", "歡迎"),
    "Setup":        ("Configuração", "Configuração", "Configuración", "Installation", "Einrichtung", "Configurazione", "Installatie", "Konfiguracja", "Установка", "Penyiapan", "セットアップ", "安装", "安裝"),
    "Requirements": ("Requisitos", "Requisitos", "Requisitos", "Prérequis", "Voraussetzungen", "Requisiti", "Vereisten", "Wymagania", "Требования", "Persyaratan", "要件", "要求", "需求"),
    "Sending":      ("Enviando", "A enviar", "Enviando", "Envoi", "Senden", "Invio", "Verzenden", "Wysyłanie", "Отправка", "Mengirim", "送信", "发送", "傳送"),
    # Beside the pulsing dot while a voice message is being recorded.
    "Recording":    ("Gravando", "A gravar", "Grabando", "Enregistrement", "Aufnahme", "Registrazione", "Opnemen", "Nagrywanie", "Запись", "Merekam", "録音中", "录音中", "錄音中"),
    # The pronoun on your own messages, not a form of address.
    "You":          ("Você", "Você", "Tú", "Vous", "Du", "Tu", "Jij", "Ty", "Вы", "Anda", "あなた", "你", "你"),
    # The user-list heading over the two people in a private conversation, where
    # a channel would name a role. A group of people, not a share or a stake.
    "Participants": ("Participantes", "Participantes", "Participantes", "Participants", "Teilnehmer", "Partecipanti", "Deelnemers", "Uczestnicy", "Участники", "Peserta", "参加者", "参与者", "參與者"),

    # ── mIRC colour names ─────────────────────────────────────
    # The palette a nickname or a line of text can be painted with. Named
    # colours, not hex — a person picks "Teal" from a list, so the list has to
    # be in their language.
    "Cyan":         ("Ciano", "Ciano", "Cian", "Cyan", "Cyan", "Ciano", "Cyaan", "Cyjan", "Голубой", "Sian", "シアン", "青色", "青色"),
    "Magenta":      ("Magenta", "Magenta", "Magenta", "Magenta", "Magenta", "Magenta", "Magenta", "Magenta", "Пурпурный", "Magenta", "マゼンタ", "洋红", "洋紅"),
    "Teal":         ("Verde-azulado", "Verde-azulado", "Verde azulado", "Sarcelle", "Blaugrün", "Verde acqua", "Blauwgroen", "Morski", "Бирюзовый", "Biru kehijauan", "青緑", "蓝绿", "藍綠"),
    "Orange":       ("Laranja", "Laranja", "Naranja", "Orange", "Orange", "Arancione", "Oranje", "Pomarańczowy", "Оранжевый", "Oranye", "オレンジ", "橙色", "橙色"),
    "Maroon":       ("Bordô", "Bordô", "Granate", "Bordeaux", "Kastanienbraun", "Bordeaux", "Kastanjebruin", "Bordowy", "Бордовый", "Merah marun", "栗色", "栗色", "栗色"),

    # ── The chat's own furniture ──────────────────────────────
    "Status":       ("Status", "Estado", "Estado", "Statut", "Status", "Stato", "Status", "Status", "Состояние", "Status", "ステータス", "状态", "狀態"),
    "Chat":         ("Chat", "Conversa", "Chat", "Discussion", "Chat", "Chat", "Chat", "Czat", "Чат", "Obrolan", "チャット", "聊天", "聊天"),
    "Online":       ("Online", "Online", "En línea", "En ligne", "Online", "Online", "Online", "Dostępny", "В сети", "Daring", "オンライン", "在线", "線上"),
    "Offline":      ("Offline", "Offline", "Desconectado", "Hors ligne", "Offline", "Offline", "Offline", "Offline", "Не в сети", "Luring", "オフライン", "离线", "離線"),
    "Server":       ("Servidor", "Servidor", "Servidor", "Serveur", "Server", "Server", "Server", "Serwer", "Сервер", "Server", "サーバー", "服务器", "伺服器"),
    "Browser":      ("Navegador", "Navegador", "Navegador", "Navigateur", "Browser", "Browser", "Browser", "Przeglądarka", "Браузер", "Peramban", "ブラウザー", "浏览器", "瀏覽器"),
    "Audio":        ("Áudio", "Áudio", "Audio", "Audio", "Audio", "Audio", "Audio", "Dźwięk", "Звук", "Audio", "オーディオ", "音频", "音訊"),
    "Video":        ("Vídeo", "Vídeo", "Vídeo", "Vidéo", "Video", "Video", "Video", "Wideo", "Видео", "Video", "ビデオ", "视频", "視訊"),
    "Emoji":        ("Emoji", "Emoji", "Emoji", "Émoji", "Emoji", "Emoji", "Emoji", "Emoji", "Эмодзи", "Emoji", "絵文字", "表情符号", "表情符號"),
    "Bots":         ("Bots", "Bots", "Bots", "Bots", "Bots", "Bot", "Bots", "Boty", "Боты", "Bot", "ボット", "机器人", "機器人"),
    "Admin":        ("Admin", "Admin", "Admin", "Admin", "Admin", "Admin", "Beheer", "Admin", "Админ", "Admin", "管理", "管理", "管理"),
    "Timers":       ("Timers", "Temporizadores", "Temporizadores", "Minuteries", "Timer", "Timer", "Timers", "Liczniki", "Таймеры", "Pengatur waktu", "タイマー", "计时器", "計時器"),
    "Kick":         ("Expulsar", "Expulsar", "Expulsar", "Expulser", "Kicken", "Espelli", "Kicken", "Wyrzuć", "Выгнать", "Keluarkan", "キック", "踢出", "踢出"),
    "Nick":         ("Apelido", "Alcunha", "Apodo", "Pseudo", "Nick", "Nick", "Nick", "Nick", "Ник", "Nama panggilan", "ニック", "昵称", "暱稱"),
    "Auto":         ("Auto", "Auto", "Auto", "Auto", "Auto", "Auto", "Auto", "Auto", "Авто", "Otomatis", "自動", "自动", "自動"),
    "Jitter":       ("Jitter", "Jitter", "Fluctuación", "Gigue", "Jitter", "Jitter", "Jitter", "Jitter", "Джиттер", "Jitter", "ジッター", "抖动", "抖動"),
    # The coin-op cabinet, never the row of arches. Measured: the pipeline gave
    # es "Arcada" and zh "拱门/拱門", which are the architecture.
    "Arcade":       ("Arcade", "Arcade", "Arcade", "Arcade", "Arcade", "Arcade", "Arcade", "Arcade", "Аркада", "Arcade", "アーケード", "街机", "街機"),

    # The channel key, shown masked. Italian dropped the asterisks entirely
    # ("Chiave:"), Indonesian and Polish spaced them out ("* * *"), and
    # Japanese collapsed the whole string onto "メニュー" — the word menu,
    # from nowhere. A masked value is not text to translate.
    "Key: ***":     ("Chave: ***", "Chave: ***", "Clave: ***", "Clé : ***", "Schlüssel: ***", "Chiave: ***", "Sleutel: ***", "Klucz: ***", "Ключ: ***", "Kunci: ***", "キー: ***", "密钥: ***", "密鑰: ***"),

    # Help-topic search keywords. Two words with no sentence around them:
    # Japanese reduced both to "メニュー", so searching the help in Japanese
    # for either one matched nothing the other did not, and German read "nick"
    # as spitz and produced "Spitzmenü" — a pointed menu.
    "nick menu":    ("menu do nick", "menu do nick", "menú del nick", "menu du pseudo", "Nick-Menü", "menu del nick", "nick-menu", "menu nicka", "меню ника", "menu nick", "ニックメニュー", "昵称菜单", "暱稱菜單"),
    # Three labels the admin banners introduced. Short and standalone, so the
    # engine has no sentence to read them from: "Console" is the terminal, not
    # a games console, and "Preserved" heads the list of what a wipe keeps.
    # A sample chat line in the Highlight banner. Japanese answered it with
    # the web boilerplate お問い合わせ ("contact us") whether or not it had a
    # full stop to parse — four words with no context is a glossary entry, not
    # a translation task.
    "I will be there.": ("Estarei l\u00e1.", "Estarei l\u00e1.", "All\u00ed estar\u00e9.", "J'y serai.", "Ich werde da sein.", "Ci sar\u00f2.", "Ik zal er zijn.", "B\u0119d\u0119 tam.", "\u042f \u0431\u0443\u0434\u0443 \u0442\u0430\u043c.", "Saya akan ada di sana.", "\u884c\u304d\u307e\u3059\u3002", "\u6211\u4f1a\u53bb\u7684\u3002", "\u6211\u6703\u53bb\u7684\u3002"),

    "never":        ("nunca", "nunca", "nunca", "jamais", "nie", "mai", "nooit", "nigdy", "\u043d\u0438\u043a\u043e\u0433\u0434\u0430", "tidak pernah", "\u306a\u3057", "\u4ece\u672a", "\u5f9e\u672a"),

    "Console":      ("Console", "Consola", "Consola", "Console", "Konsole", "Console", "Console", "Konsola", "\u041a\u043e\u043d\u0441\u043e\u043b\u044c", "Konsol", "\u30b3\u30f3\u30bd\u30fc\u30eb", "\u63a7\u5236\u53f0", "\u4e3b\u63a7\u53f0"),
    "Preserved":    ("Preservado", "Preservado", "Conservado", "Conserv\u00e9", "Erhalten", "Conservato", "Behouden", "Zachowane", "\u0421\u043e\u0445\u0440\u0430\u043d\u044f\u0435\u0442\u0441\u044f", "Dipertahankan", "\u4fdd\u6301", "\u4fdd\u7559", "\u4fdd\u7559"),
    "Sign-up":      ("Cadastro", "Registo", "Registro", "Inscription", "Registrierung", "Registrazione", "Registratie", "Rejestracja", "\u0420\u0435\u0433\u0438\u0441\u0442\u0440\u0430\u0446\u0438\u044f", "Pendaftaran", "\u767b\u9332", "\u6ce8\u518c", "\u8a3b\u518a"),

    # The Construct's build palette: pieces of furniture and the tools that act
    # on a placed one. Single nouns and verbs with nothing around them; "Turn"
    # is the rotation, never a turn in a game. "Table" is in _CONTEXT_ROWS.
    "Build":        ("Construir", "Construir", "Construir", "Construire", "Bauen", "Costruisci", "Bouwen", "Buduj", "Строить", "Bangun", "建てる", "建造", "建造"),
    "Chair":        ("Cadeira", "Cadeira", "Silla", "Chaise", "Stuhl", "Sedia", "Stoel", "Krzesło", "Стул", "Kursi", "椅子", "椅子", "椅子"),
    "Tree":         ("Árvore", "Árvore", "Árbol", "Arbre", "Baum", "Albero", "Boom", "Drzewo", "Дерево", "Pohon", "木", "树", "樹"),
    "Lamp":         ("Luminária", "Candeeiro", "Lámpara", "Lampe", "Lampe", "Lampada", "Lamp", "Lampa", "Лампа", "Lampu", "ランプ", "灯", "燈"),
    "Use":          ("Usar", "Usar", "Usar", "Utiliser", "Benutzen", "Usa", "Gebruiken", "Użyj", "Использовать", "Gunakan", "使う", "使用", "使用"),
    # The URL Catcher's count: a label and a number, so no language has to
    # agree a noun with it.
    "Links: %{count}": ("Links: %{count}", "Links: %{count}", "Enlaces: %{count}", "Liens : %{count}", "Links: %{count}", "Link: %{count}", "Links: %{count}", "Linki: %{count}", "Ссылки: %{count}", "Tautan: %{count}", "リンク: %{count}", "链接：%{count}", "連結：%{count}"),
    # A Space's gates ask before they move you, and its help names what lights
    # up as you walk past.
    "Go into the Construct?": ("Entrar no Constructo?", "Entrar no Constructo?", "¿Entrar al Constructo?", "Entrer dans le Construct ?", "Ins Konstrukt gehen?", "Entrare nel Costrutto?", "Het Construct in gaan?", "Wejść do Konstruktu?", "Войти в Конструкт?", "Masuk ke Konstruk?", "コンストラクトに入りますか?", "进入构造空间?", "進入構造空間?"),
    "Go into the office?": ("Entrar no escritório?", "Entrar no escritório?", "¿Entrar en la oficina?", "Entrer dans le bureau ?", "Ins Büro gehen?", "Entrare in ufficio?", "Het kantoor in gaan?", "Wejść do biura?", "Войти в офис?", "Masuk ke kantor?", "オフィスに入りますか?", "进入办公室?", "進入辦公室?"),
    "Go into the game room?": ("Entrar na sala de jogos?", "Entrar na sala de jogos?", "¿Entrar en la sala de juegos?", "Entrer dans la salle de jeux ?", "In den Spieleraum gehen?", "Entrare nella sala giochi?", "De speelkamer in gaan?", "Wejść do pokoju gier?", "Войти в игровую комнату?", "Masuk ke ruang permainan?", "ゲームルームに入りますか?", "进入游戏房间?", "進入遊戲房間?"),
    "Go back to the End of Time?": ("Voltar ao End of Time?", "Voltar ao End of Time?", "¿Volver al End of Time?", "Retourner à l'End of Time ?", "Zurück zum End of Time?", "Tornare all'End of Time?", "Terug naar het End of Time?", "Wrócić do End of Time?", "Вернуться в End of Time?", "Kembali ke End of Time?", "End of Time に戻りますか?", "返回 End of Time?", "返回 End of Time?"),
    "Things you can use": ("Coisas que você pode usar", "Coisas que pode usar", "Cosas que puedes usar", "Ce que vous pouvez utiliser", "Was Sie benutzen können", "Cose che puoi usare", "Wat je kunt gebruiken", "Rzeczy, których możesz użyć", "Что можно использовать", "Hal yang bisa dipakai", "使えるもの", "可以使用的东西", "可以使用的東西"),
    "Turn":         ("Girar", "Rodar", "Girar", "Tourner", "Drehen", "Ruota", "Draaien", "Obróć", "Повернуть", "Putar", "回転", "旋转", "旋轉"),
    # More pieces, the palette's tabs and the floor's paints. "Arcade cabinet"
    # is the coin-op machine; "Floor" is what you stand on, never a storey.
    "Armchair":     ("Poltrona", "Poltrona", "Sillón", "Fauteuil", "Sessel", "Poltrona", "Fauteuil", "Fotel", "Кресло", "Kursi berlengan", "アームチェア", "扶手椅", "扶手椅"),
    "Bookshelf":    ("Estante", "Estante", "Estantería", "Bibliothèque", "Bücherregal", "Libreria", "Boekenkast", "Regał", "Книжная полка", "Rak buku", "本棚", "书架", "書架"),
    "Plant":        ("Planta", "Planta", "Planta", "Plante", "Pflanze", "Pianta", "Plant", "Roślina", "Растение", "Tanaman", "植物", "植物", "植物"),
    "Wall":         ("Parede", "Parede", "Pared", "Mur", "Wand", "Parete", "Muur", "Ściana", "Стена", "Dinding", "壁", "墙", "牆"),
    "Door":         ("Porta", "Porta", "Puerta", "Porte", "Tür", "Porta", "Deur", "Drzwi", "Дверь", "Pintu", "ドア", "门", "門"),
    "Teleporter":   ("Teletransporte", "Teletransportador", "Teletransportador", "Téléporteur", "Teleporter", "Teletrasporto", "Teleporter", "Teleporter", "Телепорт", "Teleporter", "テレポーター", "传送器", "傳送器"),
    "Coin":         ("Moeda", "Moeda", "Moneda", "Pièce", "Münze", "Moneta", "Munt", "Moneta", "Монета", "Koin", "コイン", "硬币", "硬幣"),
    "Arcade cabinet": ("Fliperama", "Máquina de arcade", "Máquina recreativa", "Borne d'arcade", "Spielautomat", "Cabinato arcade", "Arcadekast", "Automat do gier", "Игровой автомат", "Mesin arcade", "アーケード筐体", "街机", "街機"),
    "Furniture":    ("Móveis", "Mobiliário", "Muebles", "Meubles", "Möbel", "Mobili", "Meubels", "Meble", "Мебель", "Perabot", "家具", "家具", "家具"),
    "Structure":    ("Estrutura", "Estrutura", "Estructura", "Structure", "Bauteile", "Struttura", "Constructie", "Konstrukcja", "Конструкции", "Struktur", "構造", "结构", "結構"),
    "Floor":        ("Piso", "Chão", "Suelo", "Sol", "Boden", "Pavimento", "Vloer", "Podłoga", "Пол", "Lantai", "床", "地板", "地板"),
    "Wood":         ("Madeira", "Madeira", "Madera", "Bois", "Holz", "Legno", "Hout", "Drewno", "Дерево", "Kayu", "木材", "木材", "木材"),
    "Stone":        ("Pedra", "Pedra", "Piedra", "Pierre", "Stein", "Pietra", "Steen", "Kamień", "Камень", "Batu", "石", "石材", "石材"),
    "Grass":        ("Grama", "Relva", "Césped", "Herbe", "Gras", "Erba", "Gras", "Trawa", "Трава", "Rumput", "芝生", "草地", "草地"),
    "Red carpet":   ("Carpete vermelho", "Alcatifa vermelha", "Alfombra roja", "Moquette rouge", "Roter Teppich", "Moquette rossa", "Rood tapijt", "Czerwony dywan", "Красный ковёр", "Karpet merah", "赤いカーペット", "红地毯", "紅地毯"),
    "Blue carpet":  ("Carpete azul", "Alcatifa azul", "Alfombra azul", "Moquette bleue", "Blauer Teppich", "Moquette blu", "Blauw tapijt", "Niebieski dywan", "Синий ковёр", "Karpet biru", "青いカーペット", "蓝地毯", "藍地毯"),
    "Arcade carpet": ("Carpete de fliperama", "Alcatifa de arcada", "Alfombra arcade", "Moquette d'arcade", "Arcade-Teppich", "Moquette arcade", "Arcadetapijt", "Dywan arcade", "Ковёр аркады", "Karpet arkade", "ゲーセンのカーペット", "街机地毯", "街機地毯"),
    "Checkerboard": ("Xadrez", "Xadrez", "Ajedrezado", "Damier", "Schachbrett", "Scacchiera", "Dambord", "Szachownica", "Шахматный узор", "Papan catur", "市松模様", "棋盘格", "棋盤格"),
    "Erase":        ("Apagar", "Apagar", "Borrar", "Effacer", "Radieren", "Cancella", "Wissen", "Wymaż", "Стереть", "Hapus", "消す", "擦除", "擦除"),
    # The Construct's library: one noun per piece, and its palette tabs. "End
    # of Time" is a place's name and stays as the game named it.
    "Sofa":         ("Sofá", "Sofá", "Sofá", "Canapé", "Sofa", "Divano", "Bank", "Sofa", "Диван", "Sofa", "ソファ", "沙发", "沙發"),
    "Long table":   ("Mesa comprida", "Mesa comprida", "Mesa larga", "Grande table", "Lange Tafel", "Tavolo lungo", "Lange tafel", "Długi stół", "Длинный стол", "Meja panjang", "長テーブル", "长桌", "長桌"),
    "Coffee table": ("Mesinha de centro", "Mesa de centro", "Mesa de centro", "Table basse", "Couchtisch", "Tavolino", "Salontafel", "Stolik kawowy", "Журнальный столик", "Meja kopi", "ローテーブル", "茶几", "茶几"),
    "Bed":          ("Cama", "Cama", "Cama", "Lit", "Bett", "Letto", "Bed", "Łóżko", "Кровать", "Tempat tidur", "ベッド", "床", "床"),
    "Nightstand":   ("Criado-mudo", "Mesa de cabeceira", "Mesita de noche", "Table de chevet", "Nachttisch", "Comodino", "Nachtkastje", "Szafka nocna", "Тумбочка", "Nakas", "ナイトテーブル", "床头柜", "床頭櫃"),
    "Wardrobe":     ("Guarda-roupa", "Roupeiro", "Armario", "Armoire", "Kleiderschrank", "Armadio", "Kledingkast", "Szafa", "Шкаф", "Lemari", "洋服ダンス", "衣柜", "衣櫃"),
    "Dresser":      ("Cômoda", "Cómoda", "Cómoda", "Commode", "Kommode", "Cassettiera", "Ladekast", "Komoda", "Комод", "Meja rias", "チェスト", "五斗柜", "五斗櫃"),
    "TV stand":     ("Rack de TV", "Móvel de TV", "Mueble de TV", "Meuble TV", "TV-Möbel", "Mobile TV", "Tv-meubel", "Szafka RTV", "Тумба под ТВ", "Rak TV", "テレビ台", "电视柜", "電視櫃"),
    "Fridge":       ("Geladeira", "Frigorífico", "Nevera", "Réfrigérateur", "Kühlschrank", "Frigorifero", "Koelkast", "Lodówka", "Холодильник", "Kulkas", "冷蔵庫", "冰箱", "冰箱"),
    "Kitchen counter": ("Bancada da cozinha", "Bancada da cozinha", "Encimera", "Plan de travail", "Küchenzeile", "Bancone da cucina", "Aanrecht", "Blat kuchenny", "Кухонная стойка", "Meja dapur", "キッチンカウンター", "厨房台面", "廚房檯面"),
    "Piano":        ("Piano", "Piano", "Piano", "Piano", "Klavier", "Pianoforte", "Piano", "Pianino", "Пианино", "Piano", "ピアノ", "钢琴", "鋼琴"),
    "Fireplace":    ("Lareira", "Lareira", "Chimenea", "Cheminée", "Kamin", "Camino", "Open haard", "Kominek", "Камин", "Perapian", "暖炉", "壁炉", "壁爐"),
    "Grandfather clock": ("Relógio de pêndulo", "Relógio de pêndulo", "Reloj de pie", "Horloge comtoise", "Standuhr", "Orologio a pendolo", "Staande klok", "Zegar stojący", "Напольные часы", "Jam berdiri", "柱時計", "落地钟", "落地鐘"),
    "Table lamp":   ("Abajur", "Candeeiro de mesa", "Lámpara de mesa", "Lampe de table", "Tischlampe", "Lampada da tavolo", "Tafellamp", "Lampka", "Настольная лампа", "Lampu meja", "テーブルランプ", "台灯", "檯燈"),
    "Vase":         ("Vaso", "Jarra", "Jarrón", "Vase", "Vase", "Vaso", "Vaas", "Wazon", "Ваза", "Vas", "花瓶", "花瓶", "花瓶"),
    "Office desk":  ("Mesa de escritório", "Secretária", "Escritorio", "Bureau", "Schreibtisch", "Scrivania", "Bureau", "Biurko", "Письменный стол", "Meja kantor", "オフィスデスク", "办公桌", "辦公桌"),
    "Office chair": ("Cadeira de escritório", "Cadeira de escritório", "Silla de oficina", "Chaise de bureau", "Bürostuhl", "Sedia da ufficio", "Bureaustoel", "Krzesło biurowe", "Офисное кресло", "Kursi kantor", "オフィスチェア", "办公椅", "辦公椅"),
    "Meeting table": ("Mesa de reunião", "Mesa de reuniões", "Mesa de reuniones", "Table de réunion", "Konferenztisch", "Tavolo riunioni", "Vergadertafel", "Stół konferencyjny", "Стол для совещаний", "Meja rapat", "会議テーブル", "会议桌", "會議桌"),
    "File cabinet": ("Arquivo", "Arquivador", "Archivador", "Classeur", "Aktenschrank", "Schedario", "Archiefkast", "Szafka na dokumenty", "Картотека", "Lemari arsip", "ファイルキャビネット", "文件柜", "檔案櫃"),
    "Printer":      ("Impressora", "Impressora", "Impresora", "Imprimante", "Drucker", "Stampante", "Printer", "Drukarka", "Принтер", "Printer", "プリンター", "打印机", "印表機"),
    "Whiteboard":   ("Quadro branco", "Quadro branco", "Pizarra blanca", "Tableau blanc", "Whiteboard", "Lavagna bianca", "Whiteboard", "Tablica suchościeralna", "Маркерная доска", "Papan tulis", "ホワイトボード", "白板", "白板"),
    "Water cooler": ("Bebedouro", "Bebedouro", "Dispensador de agua", "Fontaine à eau", "Wasserspender", "Distributore d'acqua", "Waterkoeler", "Dystrybutor wody", "Кулер", "Dispenser air", "ウォーターサーバー", "饮水机", "飲水機"),
    "Coffee machine": ("Cafeteira", "Máquina de café", "Cafetera", "Machine à café", "Kaffeemaschine", "Macchina del caffè", "Koffiezetapparaat", "Ekspres do kawy", "Кофемашина", "Mesin kopi", "コーヒーマシン", "咖啡机", "咖啡機"),
    "Vending machine": ("Máquina de lanches", "Máquina de venda", "Máquina expendedora", "Distributeur", "Snackautomat", "Distributore automatico", "Snoepautomaat", "Automat z przekąskami", "Торговый автомат", "Mesin penjual", "自動販売機", "自动售货机", "自動販賣機"),
    "Coat rack":    ("Cabideiro", "Cabide de pé", "Perchero", "Portemanteau", "Garderobenständer", "Appendiabiti", "Kapstok", "Wieszak", "Вешалка", "Gantungan baju", "コートラック", "衣帽架", "衣帽架"),
    "Cactus":       ("Cacto", "Cato", "Cactus", "Cactus", "Kaktus", "Cactus", "Cactus", "Kaktus", "Кактус", "Kaktus", "サボテン", "仙人掌", "仙人掌"),
    # The Office's own pieces: the counter at the door, the low wall between
    # desks, the basket for paper, the plant nearly a person tall.
    "Reception desk": ("Balcão de recepção", "Balcão de receção", "Mostrador de recepción", "Comptoir d'accueil", "Empfangstresen", "Bancone della reception", "Receptiebalie", "Lada recepcyjna", "Стойка ресепшена", "Meja resepsionis", "受付カウンター", "前台", "櫃台"),
    "Cubicle partition": ("Divisória", "Divisória", "Mampara", "Cloison de bureau", "Trennwand", "Divisorio", "Scheidingswand", "Ścianka działowa", "Перегородка", "Sekat kubikel", "パーティション", "隔板", "隔板"),
    "Wastebasket":  ("Lixeira", "Cesto de papéis", "Papelera", "Corbeille", "Papierkorb", "Cestino", "Prullenbak", "Kosz na śmieci", "Мусорная корзина", "Tempat sampah", "ゴミ箱", "废纸篓", "廢紙簍"),
    "Workstation":  ("Estação de trabalho", "Posto de trabalho", "Puesto de trabajo", "Poste de travail", "Arbeitsplatz", "Postazione di lavoro", "Werkplek", "Stanowisko pracy", "Рабочее место", "Meja kerja", "ワークステーション", "工位", "工作站"),
    "Glass wall":   ("Parede de vidro", "Parede de vidro", "Pared de cristal", "Cloison vitrée", "Glaswand", "Parete di vetro", "Glazen wand", "Ściana szklana", "Стеклянная стена", "Dinding kaca", "ガラスの壁", "玻璃墙", "玻璃牆"),
    "Glass door":   ("Porta de vidro", "Porta de vidro", "Puerta de cristal", "Porte vitrée", "Glastür", "Porta a vetri", "Glazen deur", "Szklane drzwi", "Стеклянная дверь", "Pintu kaca", "ガラスのドア", "玻璃门", "玻璃門"),
    "Tall plant":   ("Planta alta", "Planta alta", "Planta alta", "Grande plante", "Große Pflanze", "Pianta alta", "Grote plant", "Wysoka roślina", "Высокое растение", "Tanaman tinggi", "背の高い植物", "高大盆栽", "高大盆栽"),
    "Bush":         ("Arbusto", "Arbusto", "Arbusto", "Buisson", "Busch", "Cespuglio", "Struik", "Krzew", "Куст", "Semak", "茂み", "灌木", "灌木"),
    "Flower bed":   ("Canteiro", "Canteiro", "Parterre", "Parterre", "Blumenbeet", "Aiuola", "Bloemperk", "Rabata", "Клумба", "Petak bunga", "花壇", "花坛", "花壇"),
    "Boulder":      ("Pedra grande", "Rochedo", "Roca", "Rocher", "Felsbrocken", "Masso", "Rotsblok", "Głaz", "Валун", "Batu besar", "大岩", "巨石", "巨石"),
    "Park bench":   ("Banco de praça", "Banco de jardim", "Banco de parque", "Banc public", "Parkbank", "Panchina", "Parkbank", "Ławka", "Скамейка", "Bangku taman", "ベンチ", "公园长椅", "公園長椅"),
    "Fountain":     ("Fonte", "Fonte", "Fuente", "Fontaine", "Brunnen", "Fontana", "Fontein", "Fontanna", "Фонтан", "Air mancur", "噴水", "喷泉", "噴泉"),
    "Fence":        ("Cerca", "Vedação", "Valla", "Clôture", "Zaun", "Recinzione", "Hek", "Płot", "Забор", "Pagar", "柵", "栅栏", "柵欄"),
    "Street lamp":  ("Poste de luz", "Candeeiro de rua", "Farola", "Réverbère", "Straßenlaterne", "Lampione", "Lantaarnpaal", "Latarnia", "Фонарь", "Lampu jalan", "街灯", "路灯", "路燈"),
    "Pond":         ("Lago", "Lago", "Estanque", "Mare", "Teich", "Laghetto", "Vijver", "Staw", "Пруд", "Kolam", "池", "池塘", "池塘"),
    "Palm tree":    ("Palmeira", "Palmeira", "Palmera", "Palmier", "Palme", "Palma", "Palmboom", "Palma", "Пальма", "Pohon palem", "ヤシの木", "棕榈树", "棕櫚樹"),
    "Pine tree":    ("Pinheiro", "Pinheiro", "Pino", "Pin", "Kiefer", "Pino", "Den", "Sosna", "Сосна", "Pohon pinus", "松の木", "松树", "松樹"),
    "Giant mushroom": ("Cogumelo gigante", "Cogumelo gigante", "Seta gigante", "Champignon géant", "Riesenpilz", "Fungo gigante", "Reuzenpaddenstoel", "Olbrzymi grzyb", "Гигантский гриб", "Jamur raksasa", "巨大キノコ", "巨型蘑菇", "巨型蘑菇"),
    "Pool table":   ("Mesa de sinuca", "Mesa de bilhar", "Mesa de billar", "Table de billard", "Billardtisch", "Tavolo da biliardo", "Pooltafel", "Stół bilardowy", "Бильярдный стол", "Meja biliar", "ビリヤード台", "台球桌", "撞球桌"),
    "Ping-pong table": ("Mesa de pingue-pongue", "Mesa de pingue-pongue", "Mesa de ping-pong", "Table de ping-pong", "Tischtennisplatte", "Tavolo da ping-pong", "Pingpongtafel", "Stół do ping-ponga", "Стол для пинг-понга", "Meja pingpong", "卓球台", "乒乓球桌", "桌球桌"),
    "Beanbag":      ("Pufe", "Pufe", "Puf", "Pouf", "Sitzsack", "Pouf", "Zitzak", "Pufa", "Кресло-мешок", "Beanbag", "ビーズクッション", "懒人沙发", "懶骨頭"),
    "Gaming chair": ("Cadeira gamer", "Cadeira gaming", "Silla gamer", "Chaise gaming", "Gaming-Stuhl", "Sedia da gaming", "Gamestoel", "Fotel gamingowy", "Игровое кресло", "Kursi gaming", "ゲーミングチェア", "电竞椅", "電競椅"),
    "Neon sign":    ("Letreiro neon", "Letreiro néon", "Letrero de neón", "Enseigne néon", "Neonschild", "Insegna al neon", "Neonbord", "Neon", "Неоновая вывеска", "Papan neon", "ネオンサイン", "霓虹灯牌", "霓虹燈牌"),
    "Server rack":  ("Rack de servidor", "Bastidor de servidores", "Rack de servidores", "Baie de serveurs", "Serverschrank", "Rack server", "Serverkast", "Szafa serwerowa", "Серверная стойка", "Rak server", "サーバーラック", "服务器机架", "伺服器機櫃"),
    "Robot":        ("Robô", "Robô", "Robot", "Robot", "Roboter", "Robot", "Robot", "Robot", "Робот", "Robot", "ロボット", "机器人", "機器人"),
    "Retro console": ("Console retrô", "Consola retro", "Consola retro", "Console rétro", "Retro-Konsole", "Console retrò", "Retroconsole", "Konsola retro", "Ретро-приставка", "Konsol retro", "レトロゲーム機", "复古游戏机", "復古遊戲機"),
    "Jukebox":      ("Jukebox", "Jukebox", "Rocola", "Juke-box", "Jukebox", "Jukebox", "Jukebox", "Szafa grająca", "Музыкальный автомат", "Jukebox", "ジュークボックス", "点唱机", "點唱機"),
    "Cryo pod":     ("Cápsula criogênica", "Cápsula criogénica", "Cápsula criogénica", "Caisson cryogénique", "Kryokapsel", "Capsula criogenica", "Cryocapsule", "Kapsuła kriogeniczna", "Криокапсула", "Kapsul kriogenik", "冷凍睡眠カプセル", "冷冻舱", "冷凍艙"),
    "Hologram":     ("Holograma", "Holograma", "Holograma", "Hologramme", "Hologramm", "Ologramma", "Hologram", "Hologram", "Голограмма", "Hologram", "ホログラム", "全息投影", "全像投影"),
    "Racing arcade": ("Fliperama de corrida", "Arcade de corridas", "Arcade de carreras", "Borne de course", "Rennautomat", "Cabinato da corsa", "Racekast", "Automat wyścigowy", "Гоночный автомат", "Arcade balap", "レースゲーム筐体", "赛车街机", "賽車街機"),
    "Neon totem":   ("Totem de neon", "Totem de néon", "Tótem de neón", "Totem néon", "Neonsäule", "Totem al neon", "Neontotem", "Neonowy totem", "Неоновый тотем", "Totem neon", "ネオンタワー", "霓虹灯柱", "霓虹燈柱"),
    "Old TV":       ("TV antiga", "Televisão antiga", "Televisor antiguo", "Vieille télé", "Alter Fernseher", "Vecchia TV", "Oude tv", "Stary telewizor", "Старый телевизор", "TV tua", "古いテレビ", "老电视", "老電視"),
    "Campfire":     ("Fogueira", "Fogueira", "Hoguera", "Feu de camp", "Lagerfeuer", "Falò", "Kampvuur", "Ognisko", "Костёр", "Api unggun", "たき火", "篝火", "營火"),
    "Spirit Bomb":  ("Genki Dama", "Genki Dama", "Genkidama", "Genki Dama", "Genki-Dama", "Genki Dama", "Genki Dama", "Genki Dama", "Гэнки-дама", "Genki Dama", "元気玉", "元气弹", "元氣彈"),
    "Wingback chair": ("Poltrona de orelhas", "Poltrona de orelhas", "Sillón orejero", "Fauteuil à oreilles", "Ohrensessel", "Poltrona bergère", "Oorfauteuil", "Fotel uszak", "Кресло с ушами", "Kursi sayap", "ウィングチェア", "翼背椅", "翼背椅"),
    "Victorian lamp": ("Poste vitoriano", "Candeeiro vitoriano", "Farola victoriana", "Réverbère victorien", "Viktorianische Laterne", "Lampione vittoriano", "Victoriaanse lantaarn", "Wiktoriańska latarnia", "Викторианский фонарь", "Lampu Victoria", "ヴィクトリア朝の街灯", "维多利亚路灯", "維多利亞路燈"),
    "Bucket": ("Balde", "Balde", "Cubo", "Seau", "Eimer", "Secchio", "Emmer", "Wiadro", "Ведро", "Ember", "バケツ", "水桶", "水桶"),
    "Signpost": ("Placa indicativa", "Placa de direções", "Poste indicador", "Panneau indicateur", "Wegweiser", "Cartello direzionale", "Wegwijzer", "Drogowskaz", "Указатель", "Papan penunjuk arah", "道しるべ", "路标", "路標"),
    "CRT TV": ("TV de tubo", "Televisão de tubo", "Televisor de tubo", "Télé cathodique", "Röhrenfernseher", "TV a tubo catodico", "Beeldbuistelevisie", "Telewizor kineskopowy", "Кинескопный телевизор", "TV tabung", "ブラウン管テレビ", "显像管电视", "映像管電視"),
    "Golden gate": ("Portão dourado", "Portão dourado", "Verja dorada", "Portail doré", "Goldenes Tor", "Cancello dorato", "Gouden poort", "Złota brama", "Золотые ворота", "Gerbang emas", "金の門", "金色大门", "金色大門"),
    "Golden railing": ("Grade dourada", "Gradeamento dourado", "Barandilla dorada", "Balustrade dorée", "Goldenes Geländer", "Ringhiera dorata", "Gouden reling", "Złota balustrada", "Золотая ограда", "Pagar emas", "金の手すり", "金色栏杆", "金色欄杆"),
    "Iron fence": ("Grade de ferro", "Gradeamento de ferro", "Valla de hierro", "Clôture en fer", "Eisenzaun", "Recinzione in ferro", "IJzeren hek", "Żelazne ogrodzenie", "Железная ограда", "Pagar besi", "鉄の柵", "铁栅栏", "鐵柵欄"),
    "Big top": ("Lona de circo", "Tenda de circo grande", "Carpa de circo", "Grand chapiteau", "Zirkuszelt", "Tendone del circo", "Grote circustent", "Namiot cyrkowy", "Шапито", "Tenda sirkus besar", "サーカスの大テント", "马戏大帐篷", "馬戲大帳篷"),
    "Fortune-teller's tent": ("Tenda da cartomante", "Tenda da cartomante", "Carpa de la adivina", "Tente de la voyante", "Wahrsagerzelt", "Tenda della chiromante", "Tent van de waarzegster", "Namiot wróżki", "Шатёр гадалки", "Tenda peramal", "占い師のテント", "占卜帐篷", "占卜帳篷"),
    "Circus tent": ("Tenda de circo", "Tenda de circo", "Carpa de circo pequeña", "Chapiteau", "Kleines Zirkuszelt", "Tenda da circo", "Circustent", "Mały namiot cyrkowy", "Цирковой шатёр", "Tenda sirkus", "サーカステント", "马戏帐篷", "馬戲帳篷"),
    "Purple tent": ("Tenda roxa", "Tenda roxa", "Carpa morada", "Tente violette", "Lila Zelt", "Tenda viola", "Paarse tent", "Fioletowy namiot", "Фиолетовый шатёр", "Tenda ungu", "紫のテント", "紫色帐篷", "紫色帳篷"),
    "Pennant tent": ("Tenda com flâmula", "Tenda com flâmula", "Carpa con banderín", "Tente à fanion", "Wimpelzelt", "Tenda con stendardo", "Tent met wimpel", "Namiot z proporczykiem", "Шатёр с вымпелом", "Tenda berpanji", "旗付きテント", "三角旗帐篷", "三角旗帳篷"),
    "Striped tent": ("Tenda listrada", "Tenda às riscas", "Carpa a rayas", "Tente rayée", "Gestreiftes Zelt", "Tenda a righe", "Gestreepte tent", "Namiot w paski", "Полосатый шатёр", "Tenda belang", "しま模様のテント", "条纹帐篷", "條紋帳篷"),
    "Weapon stall": ("Barraca de armas", "Banca de armas", "Puesto de armas", "Étal d'armes", "Waffenstand", "Bancarella di armi", "Wapenkraam", "Stragan z bronią", "Оружейная лавка", "Kios senjata", "武器の屋台", "武器摊", "武器攤"),
    "Snack stall": ("Barraca de lanches", "Banca de petiscos", "Puesto de comida", "Stand de friandises", "Imbissstand", "Chiosco di snack", "Snackkraam", "Stoisko z przekąskami", "Ларёк с закусками", "Kios jajanan", "軽食の屋台", "小吃摊", "小吃攤"),
    "Fair gate": ("Portal da feira", "Portal da feira", "Arco de la feria", "Portail de la foire", "Jahrmarktstor", "Ingresso della fiera", "Kermispoort", "Brama jarmarku", "Ворота ярмарки", "Gerbang pasar malam", "お祭りの門", "集市大门", "市集大門"),
    "Bunting": ("Bandeirinhas", "Bandeirolas", "Banderines", "Guirlande de fanions", "Wimpelkette", "Bandierine", "Vlaggenlijn", "Girlanda z chorągiewek", "Гирлянда флажков", "Untaian bendera", "万国旗", "彩旗串", "彩旗串"),
    "Flagpole": ("Mastro com bandeira", "Mastro com bandeira", "Mástil con bandera", "Mât à drapeau", "Fahnenmast", "Pennone", "Vlaggenmast", "Maszt z flagą", "Флагшток", "Tiang bendera", "旗竿", "旗杆", "旗桿"),
    "Paper lantern": ("Lanterna de papel", "Lanterna de papel", "Farolillo de papel", "Lanterne en papier", "Papierlaterne", "Lanterna di carta", "Papieren lantaarn", "Papierowy lampion", "Бумажный фонарик", "Lampion kertas", "提灯", "纸灯笼", "紙燈籠"),
    "Fair fountain": ("Chafariz da feira", "Chafariz da feira", "Fuente de la feria", "Fontaine de la foire", "Jahrmarktsbrunnen", "Fontana della fiera", "Kermisfontein", "Fontanna jarmarku", "Ярмарочный фонтан", "Air mancur pasar malam", "お祭りの噴水", "集市喷泉", "市集噴泉"),
    "Crates": ("Caixotes", "Caixotes", "Cajas", "Caisses", "Kisten", "Casse", "Kratten", "Skrzynie", "Ящики", "Peti", "木箱", "木箱", "木箱"),
    "Planter": ("Floreira", "Floreira", "Jardinera", "Jardinière", "Blumenkasten", "Fioriera", "Plantenbak", "Donica", "Цветочный ящик", "Pot tanaman", "プランター", "花槽", "花槽"),
    "Wooden bench": ("Banco de madeira", "Banco de madeira", "Banco de madera", "Banc en bois", "Holzbank", "Panca di legno", "Houten bank", "Drewniana ławka", "Деревянная скамья", "Bangku kayu", "木のベンチ", "木长椅", "木長椅"),
    "Fair notice board": ("Mural da feira", "Quadro da feira", "Tablón de la feria", "Panneau de la foire", "Jahrmarktstafel", "Bacheca della fiera", "Kermisbord", "Tablica jarmarku", "Ярмарочная доска", "Papan pasar malam", "お祭りの看板", "集市告示牌", "市集告示牌"),
    "Hedge": ("Cerca viva", "Sebe", "Seto", "Haie", "Hecke", "Siepe", "Heg", "Żywopłot", "Живая изгородь", "Pagar tanaman", "生け垣", "树篱", "樹籬"),
    "Potted tree": ("Árvore em vaso", "Árvore em vaso", "Árbol en maceta", "Arbre en pot", "Kübelbaum", "Albero in vaso", "Boom in pot", "Drzewko w donicy", "Дерево в кадке", "Pohon dalam pot", "鉢植えの木", "盆栽树", "盆栽樹"),
    "Bell tower": ("Torre do sino", "Torre do sino", "Campanario", "Clocher", "Glockenturm", "Campanile", "Klokkentoren", "Dzwonnica", "Колокольня", "Menara lonceng", "鐘楼", "钟楼", "鐘樓"),
    "Brazier": ("Braseiro", "Braseiro", "Brasero", "Brasero", "Feuerschale", "Braciere", "Vuurschaal", "Kosz żarowy", "Жаровня", "Anglo api", "かがり火台", "火盆", "火盆"),
    "Magic portal": ("Portal mágico", "Portal mágico", "Portal mágico", "Portail magique", "Magisches Portal", "Portale magico", "Magisch portaal", "Magiczny portal", "Волшебный портал", "Portal sihir", "魔法のポータル", "魔法传送门", "魔法傳送門"),
    "Sparkle": ("Brilho", "Brilho", "Destello", "Étincelle", "Funkeln", "Scintilla", "Fonkeling", "Iskra", "Искорка", "Kilauan", "きらめき", "闪光", "閃光"),
    "Ancient gate": ("Portão antigo", "Portão antigo", "Puerta antigua", "Porte antique", "Uraltes Tor", "Portale antico", "Oude poort", "Starożytna brama", "Древние врата", "Gerbang kuno", "古代の門", "远古之门", "遠古之門"),
    "Stone altar": ("Altar de pedra", "Altar de pedra", "Altar de piedra", "Autel de pierre", "Steinaltar", "Altare di pietra", "Stenen altaar", "Kamienny ołtarz", "Каменный алтарь", "Altar batu", "石の祭壇", "石祭坛", "石祭壇"),
    "Stone totem": ("Totem de pedra", "Totem de pedra", "Tótem de piedra", "Totem de pierre", "Steintotem", "Totem di pietra", "Stenen totem", "Kamienny totem", "Каменный тотем", "Totem batu", "石のトーテム", "石图腾", "石圖騰"),
    "Stone arch": ("Arco de pedra", "Arco de pedra", "Arco de piedra", "Arche de pierre", "Steinbogen", "Arco di pietra", "Stenen boog", "Kamienny łuk", "Каменная арка", "Lengkung batu", "石のアーチ", "石拱门", "石拱門"),
    "Glowing arch": ("Arco luminoso", "Arco luminoso", "Arco luminoso", "Arche lumineuse", "Leuchtender Bogen", "Arco luminoso", "Lichtende boog", "Świecący łuk", "Светящаяся арка", "Lengkung bercahaya", "光るアーチ", "发光拱门", "發光拱門"),
    "Stone column": ("Coluna de pedra", "Coluna de pedra", "Columna de piedra", "Colonne de pierre", "Steinsäule", "Colonna di pietra", "Stenen zuil", "Kamienna kolumna", "Каменная колонна", "Pilar batu", "石の柱", "石柱", "石柱"),
    "End of Time lamppost": ("Poste do End of Time", "Candeeiro do End of Time", "Farola del End of Time", "Réverbère de l'End of Time", "Laterne des End of Time", "Lampione dell'End of Time", "Lantaarnpaal van End of Time", "Latarnia z End of Time", "Фонарь End of Time", "Tiang lampu End of Time", "End of Timeの街灯", "End of Time路灯", "End of Time路燈"),
    "Code gate": ("Portal de código", "Portal de código", "Portal de código", "Portail de code", "Code-Tor", "Portale di codice", "Codepoort", "Brama kodu", "Врата кода", "Gerbang kode", "コードの門", "代码之门", "程式碼之門"),
    "Garden":       ("Jardim", "Jardim", "Jardín", "Jardin", "Garten", "Giardino", "Tuin", "Ogród", "Сад", "Taman", "庭", "花园", "花園"),
    "Gamer":        ("Gamer", "Gaming", "Gamer", "Gaming", "Gaming", "Gaming", "Gaming", "Gaming", "Гейминг", "Gaming", "ゲーマー", "游戏", "遊戲"),
    "End of Time":  ("End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time", "End of Time"),
    "Topic":        ("Tópico", "Tópico", "Tema", "Sujet", "Thema", "Argomento", "Onderwerp", "Temat", "Тема", "Topik", "トピック", "主题", "主題"),

    "nicklist menu": ("menu da lista de nicks", "menu da lista de nicks", "menú de la lista de nicks", "menu de la liste des pseudos", "Nicklisten-Menü", "menu della lista nick", "nicklijst-menu", "menu listy nicków", "меню списка ников", "menu daftar nick", "ニックリストメニュー", "昵称列表菜单", "暱稱列表菜單"),

    # ── The Space's character creator ─────────────────────────
    # "Enter" stays out (see Sharing a surface): going into the map is "Walk in".
    "Make your character": ("Crie seu personagem", "Cria a tua personagem", "Crea tu personaje", "Créez votre personnage", "Erstelle deinen Charakter", "Crea il tuo personaggio", "Maak je personage", "Stwórz swoją postać", "Создайте персонажа", "Buat karaktermu", "キャラクターを作る", "创建你的角色", "建立你的角色"),
    "Walk in":      ("Entrar", "Entrar", "Entrar", "Entrer", "Eintreten", "Entra", "Naar binnen", "Wejdź", "Войти", "Masuk", "入る", "进入", "進入"),
    "Wear this":    ("Vestir este", "Vestir este", "Ponerme este", "Porter celui-ci", "Diesen tragen", "Indossa questo", "Dit dragen", "Załóż to", "Надеть это", "Pakai ini", "これを着る", "穿上这个", "穿上這個"),
    "Surprise me":  ("Surpreenda-me", "Surpreende-me", "Sorpréndeme", "Surprends-moi", "Überrasch mich", "Sorprendimi", "Verras me", "Zaskocz mnie", "Удиви меня", "Kejutkan aku", "おまかせ", "随机一个", "隨機一個"),
    "Turn left":    ("Virar à esquerda", "Virar à esquerda", "Girar a la izquierda", "Tourner à gauche", "Nach links drehen", "Ruota a sinistra", "Naar links draaien", "Obróć w lewo", "Повернуть влево", "Putar ke kiri", "左に回す", "向左转", "向左轉"),
    "Turn right":   ("Virar à direita", "Virar à direita", "Girar a la derecha", "Tourner à droite", "Nach rechts drehen", "Ruota a destra", "Naar rechts draaien", "Obróć w prawo", "Повернуть вправо", "Putar ke kanan", "右に回す", "向右转", "向右轉"),
    "Main colour":  ("Cor principal", "Cor principal", "Color principal", "Couleur principale", "Hauptfarbe", "Colore principale", "Hoofdkleur", "Kolor główny", "Основной цвет", "Warna utama", "メインカラー", "主色", "主色"),
    "Trim colour":  ("Cor do detalhe", "Cor do debrum", "Color del ribete", "Couleur des finitions", "Besatzfarbe", "Colore delle rifiniture", "Bieskleur", "Kolor wykończenia", "Цвет отделки", "Warna list", "縁取りの色", "饰边颜色", "飾邊顏色"),
    "Hair colour":  ("Cor do cabelo", "Cor do cabelo", "Color del pelo", "Couleur des cheveux", "Haarfarbe", "Colore dei capelli", "Haarkleur", "Kolor włosów", "Цвет волос", "Warna rambut", "髪の色", "发色", "髮色"),
    "Bald":         ("Careca", "Careca", "Calvo", "Chauve", "Glatze", "Calvo", "Kaal", "Łysy", "Лысый", "Botak", "スキンヘッド", "光头", "光頭"),
    "Character":    ("Personagem", "Personagem", "Personaje", "Personnage", "Charakter", "Personaggio", "Personage", "Postać", "Персонаж", "Karakter", "キャラクター", "角色", "角色"),
    "Skin":         ("Pele", "Pele", "Piel", "Peau", "Haut", "Pelle", "Huid", "Skóra", "Кожа", "Kulit", "肌", "肤色", "膚色"),
    # A face item's one dye, and the pad's two emote buttons.
    "Colour":       ("Cor", "Cor", "Color", "Couleur", "Farbe", "Colore", "Kleur", "Kolor", "Цвет", "Warna", "色", "颜色", "顏色"),
    "Wave":         ("Acenar", "Acenar", "Saludar", "Saluer", "Winken", "Saluta", "Zwaaien", "Pomachaj", "Помахать", "Melambai", "手を振る", "挥手", "揮手"),
    "Wave hello":   ("Acenar", "Acenar", "Saludar con la mano", "Saluer de la main", "Winken", "Salutare con la mano", "Zwaaien", "Pomachaj", "Помахать рукой", "Melambaikan tangan", "手を振る", "挥手问好", "揮手問好"),
    "Start or stop dancing": ("Começar ou parar de dançar", "Começar ou parar de dançar", "Empezar o dejar de bailar", "Commencer ou arrêter de danser", "Tanzen beginnen oder beenden", "Iniziare o smettere di ballare", "Beginnen of stoppen met dansen", "Zacznij lub przestań tańczyć", "Начать или закончить танец", "Mulai atau berhenti menari", "踊り始める・やめる", "开始或停止跳舞", "開始或停止跳舞"),
    "Dance":        ("Dançar", "Dançar", "Bailar", "Danser", "Tanzen", "Balla", "Dansen", "Tańcz", "Танцевать", "Menari", "踊る", "跳舞", "跳舞"),
    # ── The one desktop's way in ─────────────────────────────
    # "Enter" read as typing: "Digite a conversa", "Geben Sie den Chat ein",
    # "チャットを入力してください". It is going in, never keying something.
    "Enter the chat": ("Entrar no chat", "Entrar no chat", "Entrar al chat", "Entrer dans le chat", "Zum Chat", "Entra nella chat", "Naar de chat", "Wejdź na czat", "Войти в чат", "Masuk ke obrolan", "チャットに入る", "进入聊天", "進入聊天"),
    "About this site": ("Sobre este site", "Sobre este site", "Sobre este sitio", "À propos de ce site", "Über diese Website", "Informazioni su questo sito", "Over deze site", "O tej witrynie", "Об этом сайте", "Tentang situs ini", "このサイトについて", "关于本站", "關於本站"),
    # pt_BR "Janela de Ligação" is European; de "Fenster schließen" is Close Window.
    "Connect Window": ("Janela de Conexão", "Janela de Ligação", "Ventana de conexión", "Fenêtre de connexion", "Verbindungsfenster", "Finestra di connessione", "Verbindingsvenster", "Okno połączenia", "Окно подключения", "Jendela Sambungan", "接続ウィンドウ", "连接窗口", "連線視窗"),
    # ja had collapsed five of these onto "サイトマップ" (Sitemap); es "Underline"
    # was "Subsidio", de "Untergliederung", and zh "URLs" was "URL( URL)".
    "Search URLs...": ("Buscar URLs...", "Procurar URLs...", "Buscar URLs...", "Rechercher des URL...", "URLs suchen...", "Cerca URL...", "URL's zoeken...", "Szukaj adresów URL...", "Поиск URL-адресов...", "Cari URL...", "URLを検索...", "搜索 URL...", "搜尋網址..."),
    "URL":          ("URL", "URL", "URL", "URL", "URL", "URL", "URL", "URL", "URL", "URL", "URL", "网址", "網址"),
    "URLs":         ("URLs", "URLs", "URLs", "URL", "URLs", "URL", "URL's", "Adresy URL", "URL-адреса", "URL", "URL", "网址", "網址"),
    "Underline":    ("Sublinhado", "Sublinhado", "Subrayado", "Souligné", "Unterstrichen", "Sottolineato", "Onderstrepen", "Podkreślenie", "Подчёркивание", "Garis bawah", "下線", "下划线", "底線"),
    "home page":    ("página inicial", "página inicial", "página principal", "page d'accueil", "Startseite", "pagina iniziale", "startpagina", "strona główna", "главная страница", "beranda", "ホームページ", "主页", "首頁"),
    "On this page": ("Nesta página", "Nesta página", "En esta página", "Sur cette page", "Auf dieser Seite", "In questa pagina", "Op deze pagina", "Na tej stronie", "На этой странице", "Di halaman ini", "このページの内容", "本页内容", "本頁內容"),
    # ── A game's channel and its results ──────────────────────
    # "Draw" is the result of a match, never the verb.
    "Ranking":        ("Ranking", "Classificação", "Clasificación", "Classement", "Rangliste", "Classifica", "Ranglijst", "Ranking", "Рейтинг", "Peringkat", "ランキング", "排行榜", "排行榜"),
    "Rematch":        ("Revanche", "Desforra", "Revancha", "Revanche", "Revanche", "Rivincita", "Revanche", "Rewanż", "Реванш", "Tanding ulang", "再戦", "再战", "再戰"),
    "Draw":           ("Empate", "Empate", "Empate", "Match nul", "Unentschieden", "Pareggio", "Gelijkspel", "Remis", "Ничья", "Seri", "引き分け", "平局", "平手"),
    "Find a partner": ("Procurar parceiro", "Procurar parceiro", "Buscar compañero", "Trouver un partenaire", "Mitspieler finden", "Trova un compagno", "Medespeler zoeken", "Znajdź partnera", "Найти партнёра", "Cari lawan main", "相手を探す", "寻找对手", "尋找對手"),
    "Personal best":  ("Recorde pessoal", "Recorde pessoal", "Récord personal", "Record personnel", "Persönliche Bestleistung", "Record personale", "Persoonlijk record", "Rekord osobisty", "Личный рекорд", "Rekor pribadi", "自己ベスト", "个人最佳", "個人最佳"),
    "Computer":       ("Computador", "Computador", "Computadora", "Ordinateur", "Computer", "Computer", "Computer", "Komputer", "Компьютер", "Komputer", "コンピューター", "电脑", "電腦"),
    "Ended early":    ("Encerrada antes", "Terminada antes", "Terminó antes", "Fin anticipée", "Vorzeitig beendet", "Finita prima", "Vroeg beëindigd", "Zakończona wcześniej", "Завершена досрочно", "Berakhir lebih awal", "途中終了", "提前结束", "提前結束"),
    "Rating":         ("Rating", "Classificação Elo", "Puntuación Elo", "Classement Elo", "Elo-Wertung", "Punteggio Elo", "Elo-rating", "Ranking Elo", "Рейтинг Эло", "Peringkat Elo", "レーティング", "等级分", "等級分"),
    # Watching a match and the way to it. "Match" is a game played: the engine
    # gave "correspondência", "coincidencia" and "Übereinstimmung".
    "Watch the match":  ("Assistir à partida", "Assistir à partida", "Ver la partida", "Regarder la partie", "Spiel ansehen", "Guarda la partita", "Wedstrijd bekijken", "Oglądaj mecz", "Смотреть матч", "Tonton pertandingan", "試合を観戦", "观看比赛", "觀看比賽"),
    "Watch the Match":  ("Assistir à partida", "Assistir à partida", "Ver la partida", "Regarder la partie", "Spiel ansehen", "Guarda la partita", "Wedstrijd bekijken", "Oglądaj mecz", "Смотреть матч", "Tonton pertandingan", "試合を観戦", "观看比赛", "觀看比賽"),
    "Watching a match": ("Assistindo a uma partida", "A assistir a uma partida", "Viendo una partida", "Regarder une partie", "Ein Spiel ansehen", "Guardare una partita", "Een wedstrijd bekijken", "Oglądanie meczu", "Просмотр матча", "Menonton pertandingan", "試合を観戦中", "观看比赛", "觀看比賽"),
    "Against the computer":        ("Contra o computador", "Contra o computador", "Contra la computadora", "Contre l'ordinateur", "Gegen den Computer", "Contro il computer", "Tegen de computer", "Z komputerem", "Против компьютера", "Lawan komputer", "コンピューターと対戦", "对战电脑", "對戰電腦"),
    "Invite":                      ("Convidar", "Convidar", "Invitar", "Inviter", "Einladen", "Invita", "Uitnodigen", "Zaproś", "Пригласить", "Undang", "招待", "邀请", "邀請"),
    "Play with somebody you know": ("Jogar com alguém que você conhece", "Jogar com alguém que conheces", "Jugar con alguien que conoces", "Jouer avec quelqu'un que vous connaissez", "Mit jemandem spielen, den Sie kennen", "Gioca con qualcuno che conosci", "Spelen met iemand die je kent", "Zagraj z kimś znajomym", "Играть со знакомым", "Main dengan orang yang dikenal", "知り合いと遊ぶ", "和认识的人玩", "和認識的人玩"),
    "Other ways to play":          ("Outras formas de jogar", "Outras formas de jogar", "Otras formas de jugar", "Autres façons de jouer", "Andere Spielmöglichkeiten", "Altri modi di giocare", "Andere manieren om te spelen", "Inne sposoby gry", "Другие способы играть", "Cara lain bermain", "ほかの遊び方", "其他玩法", "其他玩法"),
    "Create a match link":         ("Criar um link de partida", "Criar um link de partida", "Crear un enlace de partida", "Créer un lien de partie", "Spiel-Link erstellen", "Crea un link alla partita", "Wedstrijdlink maken", "Utwórz link do meczu", "Создать ссылку на матч", "Buat tautan pertandingan", "対戦リンクを作成", "创建比赛链接", "建立比賽連結"),
    # The reader's own record in a game.
    "Wins":                        ("Vitórias", "Vitórias", "Victorias", "Victoires", "Siege", "Vittorie", "Overwinningen", "Wygrane", "Победы", "Menang", "勝ち", "胜", "勝"),
    "Losses":                      ("Derrotas", "Derrotas", "Derrotas", "Défaites", "Niederlagen", "Sconfitte", "Nederlagen", "Porażki", "Поражения", "Kalah", "負け", "负", "負"),
    "Draws":                       ("Empates", "Empates", "Empates", "Nuls", "Unentschieden", "Pareggi", "Gelijkspelen", "Remisy", "Ничьи", "Seri", "引き分け", "平", "和"),
    "Matches":                     ("Partidas", "Partidas", "Partidas", "Parties", "Spiele", "Partite", "Wedstrijden", "Mecze", "Матчи", "Pertandingan", "試合数", "比赛", "比賽"),
    "Best score":                  ("Melhor pontuação", "Melhor pontuação", "Mejor puntuación", "Meilleur score", "Bestes Ergebnis", "Miglior punteggio", "Beste score", "Najlepszy wynik", "Лучший счёт", "Skor terbaik", "ベストスコア", "最高分", "最高分"),
    "Against people":              ("Contra pessoas", "Contra pessoas", "Contra personas", "Contre des joueurs", "Gegen Menschen", "Contro persone", "Tegen mensen", "Z ludźmi", "Против людей", "Lawan orang", "対人戦", "对战真人", "對戰真人"),
    "Your latest matches":         ("Suas últimas partidas", "As suas últimas partidas", "Tus últimas partidas", "Vos dernières parties", "Ihre letzten Spiele", "Le tue ultime partite", "Je laatste wedstrijden", "Twoje ostatnie mecze", "Ваши последние матчи", "Pertandingan terakhir Anda", "最近の試合", "你最近的比赛", "你最近的比賽"),
    "Place %{rank} of %{players}": ("%{rank}º de %{players}", "%{rank}.º de %{players}", "Puesto %{rank} de %{players}", "%{rank}e sur %{players}", "Platz %{rank} von %{players}", "%{rank}° su %{players}", "Plaats %{rank} van %{players}", "Miejsce %{rank} z %{players}", "Место %{rank} из %{players}", "Peringkat %{rank} dari %{players}", "%{players}人中%{rank}位", "第%{rank}名，共%{players}人", "第%{rank}名，共%{players}人"),
    "Play now":         ("Jogar agora", "Jogar agora", "Jugar ahora", "Jouer maintenant", "Jetzt spielen", "Gioca ora", "Nu spelen", "Graj teraz", "Играть сейчас", "Main sekarang", "今すぐ遊ぶ", "立即游玩", "立即遊玩"),
    "Log in":           ("Entrar", "Entrar", "Entrar", "Se connecter", "Anmelden", "Accedi", "Inloggen", "Zaloguj", "Войти", "Masuk", "ログイン", "登录", "登入"),
    "How to register":  ("Como se registrar", "Como se registar", "Cómo registrarse", "Comment s'inscrire", "So registrieren Sie sich", "Come registrarsi", "Zo registreer je", "Jak się zarejestrować", "Как зарегистрироваться", "Cara mendaftar", "登録方法", "如何注册", "如何註冊"),
    "Match over":     ("Partida encerrada", "Partida terminada", "Partida terminada", "Partie terminée", "Spiel vorbei", "Partita finita", "Wedstrijd voorbij", "Mecz zakończony", "Матч окончен", "Pertandingan selesai", "試合終了", "比赛结束", "比賽結束"),
}

# A menu path, or a status with its mark, is built from the labels it names —
# never translated as a phrase, which moved the arrow ("Iniciar o Navegador ▸")
# and read the menu as a browser.
_ROWS["Start ▸ Navigate"] = tuple(
    f"{start} ▸ {navigate}" for start, navigate in zip(_ROWS["Start"], _ROWS["Navigate"], strict=True)
)
_ROWS["↻ Reconnecting:"] = tuple(f"↻ {reconnecting}:" for reconnecting in _ROWS["Reconnecting"])

# Rows for a msgid that means something else elsewhere in the product, keyed by
# (msgctxt, msgid). Only an entry carrying that context is curated by them.
_CONTEXT_ROWS = {
    # Starting a game, never playing a recording (the bare "Play" is media).
    # A watched match's own words: "Live" on a match is not "available" as
    # elsewhere, and "Watch" is watching a game being played.
    ("match", "Watch"): ("Assistir", "Assistir", "Ver", "Regarder", "Zuschauen", "Guarda", "Kijken", "Oglądaj", "Смотреть", "Tonton", "観戦", "观战", "觀戰"),
    ("match", "Live"): ("Ao vivo", "Em direto", "En directo", "En direct", "Live", "In diretta", "Live", "Na żywo", "В эфире", "Langsung", "ライブ", "直播", "直播"),
    ("match", "Ended"): ("Encerrada", "Terminada", "Terminada", "Terminée", "Beendet", "Terminata", "Afgelopen", "Zakończona", "Завершена", "Selesai", "終了済み", "已结束", "已結束"),
    # The reader's own tab in a game's home: never the pronoun in a sentence.
    ("player", "You"): ("Você", "Você", "Tú", "Vous", "Du", "Tu", "Jij", "Ty", "Вы", "Kamu", "あなた", "你", "你"),
    ("game", "Play"): ("Jogar", "Jogar", "Jugar", "Jouer", "Spielen", "Gioca", "Spelen", "Graj", "Играть", "Main", "遊ぶ", "玩", "玩"),
    ("furniture", "Table"): ("Mesa", "Mesa", "Mesa", "Table", "Tisch", "Tavolo", "Tafel", "Stół", "Стол", "Meja", "テーブル", "桌子", "桌子"),
    # The Construct's other pieces whose English names mean something else
    # elsewhere: a die is never dying, a sign never a signature, a board never
    # a committee, a screen never a filter, a corner never a nook of a room.
    ("wall", "Corner"): ("Canto", "Canto", "Esquina", "Angle", "Ecke", "Angolo", "Hoek", "Narożnik", "Угол", "Sudut", "角", "墙角", "牆角"),
    # What pressing does, over whatever the use button reaches in a Space:
    # imperatives on a prompt, never a play in a theatre or a wristwatch.
    ("space prompt", "Enter the Construct"): ("Entrar no Constructo", "Entrar no Constructo", "Entrar al Constructo", "Entrer dans le Construct", "Ins Konstrukt", "Entra nel Costrutto", "Naar het Construct", "Wejdź do Konstruktu", "Войти в Конструкт", "Masuk ke Konstruk", "コンストラクトへ", "进入构造空间", "進入構造空間"),
    ("space prompt", "Enter the office"): ("Entrar no escritório", "Entrar no escritório", "Entrar en la oficina", "Entrer dans le bureau", "Ins Büro", "Entra in ufficio", "Naar het kantoor", "Wejdź do biura", "Войти в офис", "Masuk ke kantor", "オフィスへ", "进入办公室", "進入辦公室"),
    ("space prompt", "Enter the game room"): ("Entrar na sala de jogos", "Entrar na sala de jogos", "Entrar en la sala de juegos", "Entrer dans la salle de jeux", "In den Spieleraum", "Entra nella sala giochi", "Naar de speelkamer", "Wejdź do pokoju gier", "Войти в игровую комнату", "Masuk ke ruang permainan", "ゲームルームへ", "进入游戏房间", "進入遊戲房間"),
    ("space prompt", "Back to the End of Time"): ("Voltar ao End of Time", "Voltar ao End of Time", "Volver al End of Time", "Retour à l'End of Time", "Zurück zum End of Time", "Torna all'End of Time", "Terug naar het End of Time", "Wróć do End of Time", "Назад в End of Time", "Kembali ke End of Time", "End of Time に戻る", "返回 End of Time", "返回 End of Time"),
    ("space prompt", "Sit"): ("Sentar", "Sentar", "Sentarse", "S'asseoir", "Hinsetzen", "Siediti", "Zitten", "Usiądź", "Сесть", "Duduk", "座る", "坐下", "坐下"),
    ("space prompt", "Stand up"): ("Levantar", "Levantar", "Levantarse", "Se lever", "Aufstehen", "Alzati", "Opstaan", "Wstań", "Встать", "Berdiri", "立ち上がる", "起身", "起身"),
    ("space prompt", "Switch the light"): ("Acender ou apagar", "Acender ou apagar", "Encender o apagar", "Allumer ou éteindre", "Licht schalten", "Accendi o spegni", "Licht aan of uit", "Włącz lub wyłącz", "Включить или выключить", "Nyalakan atau matikan", "明かりを切り替える", "开关灯", "開關燈"),
    ("space prompt", "Open or close"): ("Abrir ou fechar", "Abrir ou fechar", "Abrir o cerrar", "Ouvrir ou fermer", "Öffnen oder schließen", "Apri o chiudi", "Openen of sluiten", "Otwórz lub zamknij", "Открыть или закрыть", "Buka atau tutup", "開け閉めする", "开关门", "開關門"),
    ("space prompt", "Teleport"): ("Teletransportar", "Teletransportar", "Teletransportarse", "Se téléporter", "Teleportieren", "Teletrasportati", "Teleporteren", "Teleportuj się", "Телепортироваться", "Teleportasi", "テレポート", "传送", "傳送"),
    ("space prompt", "Roll the die"): ("Jogar o dado", "Lançar o dado", "Tirar el dado", "Lancer le dé", "Würfeln", "Lancia il dado", "Gooi de dobbelsteen", "Rzuć kostką", "Бросить кубик", "Lempar dadu", "サイコロを振る", "掷骰子", "擲骰子"),
    ("space prompt", "Flip the coin"): ("Jogar a moeda", "Atirar a moeda", "Lanzar la moneda", "Lancer la pièce", "Münze werfen", "Lancia la moneta", "Gooi de munt", "Rzuć monetą", "Подбросить монету", "Lempar koin", "コインを投げる", "抛硬币", "擲硬幣"),
    ("space prompt", "Read"): ("Ler", "Ler", "Leer", "Lire", "Lesen", "Leggi", "Lezen", "Czytaj", "Читать", "Baca", "読む", "阅读", "閱讀"),
    ("space prompt", "Play"): ("Jogar", "Jogar", "Jugar", "Jouer", "Spielen", "Gioca", "Spelen", "Graj", "Играть", "Main", "遊ぶ", "玩", "玩"),
    ("space prompt", "Read the board"): ("Ler o quadro", "Ler o quadro", "Leer el tablón", "Lire le panneau", "Brett lesen", "Leggi la bacheca", "Lees het bord", "Czytaj tablicę", "Читать доску", "Baca papan", "掲示板を読む", "查看公告板", "查看公告板"),
    ("space prompt", "Watch"): ("Assistir", "Ver", "Ver", "Regarder", "Ansehen", "Guarda", "Kijken", "Oglądaj", "Смотреть", "Tonton", "見る", "观看", "觀看"),
    ("construct palette", "Fun"): ("Diversão", "Diversão", "Diversión", "Divertissement", "Spaß", "Divertimento", "Plezier", "Zabawa", "Развлечения", "Hiburan", "遊び", "娱乐", "娛樂"),
    ("construct palette", "Fair"): ("Feira", "Feira", "Feria", "Foire", "Jahrmarkt", "Fiera", "Kermis", "Jarmark", "Ярмарка", "Pasar malam", "お祭り", "集市", "市集"),
    ("construct palette", "Fantasy"): ("Fantasia", "Fantasia", "Fantasía", "Fantastique", "Fantasy", "Fantasy", "Fantasy", "Fantasy", "Фэнтези", "Fantasi", "ファンタジー", "奇幻", "奇幻"),
    ("game piece", "Die"): ("Dado", "Dado", "Dado", "Dé", "Würfel", "Dado", "Dobbelsteen", "Kostka", "Кубик", "Dadu", "サイコロ", "骰子", "骰子"),
    ("signpost", "Sign"): ("Placa", "Placa", "Letrero", "Panneau", "Schild", "Cartello", "Bord", "Tabliczka", "Табличка", "Papan", "看板", "标牌", "標牌"),
    ("notice board", "Board"): ("Mural", "Quadro", "Tablón", "Panneau d'affichage", "Pinnwand", "Bacheca", "Prikbord", "Tablica", "Доска", "Papan pengumuman", "掲示板", "公告板", "公告板"),
    # The Office behind the End of Time's wooden door: a room, never a post
    # or a function ("the office of mayor").
    ("space room", "Office"): ("Escritório", "Escritório", "Oficina", "Bureau", "Büro", "Ufficio", "Kantoor", "Biuro", "Офис", "Kantor", "オフィス", "办公室", "辦公室"),
    ("space room", "The Office"): ("O escritório", "O escritório", "La oficina", "Le bureau", "Das Büro", "L'ufficio", "Het kantoor", "Biuro", "Офис", "Kantor", "オフィス", "办公室", "辦公室"),
    # The Game Room behind the neon door: a room to play in, never a match or
    # a sports hall.
    ("space room", "Game Room"): ("Sala de jogos", "Sala de jogos", "Sala de juegos", "Salle de jeux", "Spieleraum", "Sala giochi", "Speelkamer", "Pokój gier", "Игровая комната", "Ruang permainan", "ゲームルーム", "游戏房间", "遊戲房間"),
    ("space room", "The Game Room"): ("A sala de jogos", "A sala de jogos", "La sala de juegos", "La salle de jeux", "Der Spieleraum", "La sala giochi", "De speelkamer", "Pokój gier", "Игровая комната", "Ruang permainan", "ゲームルーム", "游戏房间", "遊戲房間"),
    ("construct palette", "Office"): ("Escritório", "Escritório", "Oficina", "Bureau", "Büro", "Ufficio", "Kantoor", "Biuro", "Офис", "Kantor", "オフィス", "办公室", "辦公室"),
    ("garden", "Mailbox"): ("Caixa de correio", "Caixa do correio", "Buzón", "Boîte aux lettres", "Briefkasten", "Cassetta postale", "Brievenbus", "Skrzynka pocztowa", "Почтовый ящик", "Kotak surat", "郵便受け", "信箱", "信箱"),
    ("kitchen", "Stove"): ("Fogão", "Fogão", "Cocina", "Cuisinière", "Herd", "Fornello", "Fornuis", "Kuchenka", "Плита", "Kompor", "コンロ", "炉灶", "爐灶"),
    ("television", "Screen"): ("Telão", "Ecrã", "Pantalla", "Écran", "Bildschirm", "Schermo", "Scherm", "Ekran", "Экран", "Layar", "スクリーン", "屏幕", "螢幕"),
    # The Construct's key that lets go of the piece in hand: never a drop of
    # water, never dropping a table from a database.
    ("let go of a piece", "Drop"): ("Soltar", "Largar", "Soltar", "Lâcher", "Loslassen", "Lascia", "Loslaten", "Puść", "Отпустить", "Lepas", "手放す", "放下", "放下"),
    # The Space's character creator: its tabs, pieces and colours, each in the
    # sense the creator means (a body type, a skin tone, a cloth dye).
    ("character creator", "Body"): ("Corpo", "Corpo", "Cuerpo", "Corps", "Körper", "Corpo", "Lichaam", "Ciało", "Тело", "Tubuh", "体型", "体型", "體型"),
    ("character creator", "Skin"): ("Pele", "Pele", "Piel", "Peau", "Haut", "Pelle", "Huid", "Skóra", "Кожа", "Kulit", "肌", "肤色", "膚色"),
    ("character creator", "Outfit"): ("Roupa", "Roupa", "Atuendo", "Tenue", "Kleidung", "Abito", "Kleding", "Strój", "Одежда", "Pakaian", "服装", "服装", "服裝"),
    ("character creator", "Hair"): ("Cabelo", "Cabelo", "Pelo", "Cheveux", "Haare", "Capelli", "Haar", "Włosy", "Волосы", "Rambut", "髪", "头发", "頭髮"),
    ("character creator", "Headwear"): ("Chapéu", "Chapéu", "Sombrero", "Couvre-chef", "Kopfbedeckung", "Copricapo", "Hoofddeksel", "Nakrycie głowy", "Головной убор", "Penutup kepala", "帽子", "帽子", "帽子"),
    ("character creator", "Face"): ("Rosto", "Rosto", "Cara", "Visage", "Gesicht", "Viso", "Gezicht", "Twarz", "Лицо", "Wajah", "顔", "脸", "臉"),
    ("character body", "Average"): ("Médio", "Médio", "Medio", "Moyen", "Mittel", "Medio", "Gemiddeld", "Przeciętne", "Среднее", "Sedang", "標準", "标准", "標準"),
    ("character outfit", "Undershirt"): ("Regata", "Camisola interior", "Camiseta interior", "Maillot de corps", "Unterhemd", "Canottiera", "Onderhemd", "Podkoszulek", "Майка", "Kaus dalam", "肌着", "背心", "背心"),
    ("character outfit", "Tunic"): ("Túnica", "Túnica", "Túnica", "Tunique", "Tunika", "Tunica", "Tuniek", "Tunika", "Туника", "Tunik", "チュニック", "束腰外衣", "束腰外衣"),
    ("character hair", "Long"): ("Longo", "Comprido", "Largo", "Longs", "Lang", "Lunghi", "Lang", "Długie", "Длинные", "Panjang", "ロング", "长发", "長髮"),
    ("character outfit", "Robe"): ("Manto", "Manto", "Túnica larga", "Robe", "Robe", "Veste", "Gewaad", "Szata", "Мантия", "Jubah", "ローブ", "长袍", "長袍"),
    ("character outfit", "Armour"): ("Armadura", "Armadura", "Armadura", "Armure", "Rüstung", "Armatura", "Harnas", "Zbroja", "Доспехи", "Baju zirah", "鎧", "盔甲", "盔甲"),
    ("character outfit", "Jacket"): ("Jaqueta", "Casaco", "Chaqueta", "Veste", "Jacke", "Giacca", "Jas", "Kurtka", "Куртка", "Jaket", "ジャケット", "夹克", "夾克"),
    ("character outfit", "Dress"): ("Vestido", "Vestido", "Vestido", "Robe courte", "Kleid", "Vestito", "Jurk", "Sukienka", "Платье", "Gaun", "ワンピース", "连衣裙", "連身裙"),
    ("character hair", "Short"): ("Curto", "Curto", "Corto", "Courts", "Kurz", "Corti", "Kort", "Krótkie", "Короткие", "Pendek", "ショート", "短发", "短髮"),
    ("character hair", "Ponytail"): ("Rabo de cavalo", "Rabo de cavalo", "Coleta", "Queue-de-cheval", "Pferdeschwanz", "Coda di cavallo", "Paardenstaart", "Kucyk", "Хвост", "Kuncir kuda", "ポニーテール", "马尾", "馬尾"),
    ("character hair", "Afro"): ("Black power", "Afro", "Afro", "Afro", "Afro", "Afro", "Afro", "Afro", "Афро", "Afro", "アフロ", "爆炸头", "爆炸頭"),
    ("character hair", "Mohawk"): ("Moicano", "Moicano", "Cresta", "Crête", "Irokese", "Moicana", "Hanenkam", "Irokez", "Ирокез", "Mohawk", "モヒカン", "莫西干", "莫西干"),
    ("character headwear", "Beanie"): ("Gorro", "Gorro", "Gorro", "Bonnet", "Mütze", "Berretto", "Muts", "Czapka", "Шапка", "Kupluk", "ニット帽", "毛线帽", "毛線帽"),
    ("character headwear", "Wizard hat"): ("Chapéu de mago", "Chapéu de mago", "Sombrero de mago", "Chapeau de mage", "Zauberhut", "Cappello da mago", "Tovenaarshoed", "Czapka czarodzieja", "Колпак волшебника", "Topi penyihir", "魔法使いの帽子", "巫师帽", "巫師帽"),
    ("character headwear", "Hood"): ("Capuz", "Capuz", "Capucha", "Capuche", "Kapuze", "Cappuccio", "Kap", "Kaptur", "Капюшон", "Tudung", "フード", "兜帽", "兜帽"),
    ("character headwear", "Crown"): ("Coroa", "Coroa", "Corona", "Couronne", "Krone", "Corona", "Kroon", "Korona", "Корона", "Mahkota", "王冠", "王冠", "王冠"),
    ("character face item", "Beard"): ("Barba", "Barba", "Barba", "Barbe", "Bart", "Barba", "Baard", "Broda", "Борода", "Janggut", "あごひげ", "胡子", "鬍子"),
    ("character face item", "Moustache"): ("Bigode", "Bigode", "Bigote", "Moustache", "Schnurrbart", "Baffi", "Snor", "Wąsy", "Усы", "Kumis", "口ひげ", "八字胡", "八字鬍"),
    ("character face item", "Glasses"): ("Óculos", "Óculos", "Gafas", "Lunettes", "Brille", "Occhiali", "Bril", "Okulary", "Очки", "Kacamata", "メガネ", "眼镜", "眼鏡"),
    ("character face item", "Eyepatch"): ("Tapa-olho", "Pala", "Parche", "Cache-œil", "Augenklappe", "Benda", "Ooglap", "Opaska na oko", "Повязка на глаз", "Penutup mata", "眼帯", "眼罩", "眼罩"),
    ("character headwear", "Adventurer hat"): ("Chapéu de aventureiro", "Chapéu de aventureiro", "Sombrero de aventurero", "Chapeau d'aventurier", "Abenteurerhut", "Cappello da avventuriero", "Avonturiershoed", "Kapelusz podróżnika", "Шляпа искателя приключений", "Topi petualang", "冒険者の帽子", "冒险者帽", "冒險者帽"),
    ("no headwear", "None"): ("Nenhum", "Nenhum", "Ninguno", "Aucun", "Keine", "Nessuno", "Geen", "Brak", "Нет", "Tidak ada", "なし", "无", "無"),
    ("no face item", "None"): ("Nenhum", "Nenhum", "Ninguno", "Aucun", "Keines", "Nessuno", "Geen", "Brak", "Нет", "Tidak ada", "なし", "无", "無"),
    ("skin colour", "Porcelain"): ("Porcelana", "Porcelana", "Porcelana", "Porcelaine", "Porzellan", "Porcellana", "Porselein", "Porcelanowa", "Фарфоровый", "Porselen", "ポーセリン", "瓷白", "瓷白"),
    ("skin colour", "Fair"): ("Clara", "Clara", "Clara", "Claire", "Hell", "Chiara", "Licht", "Jasna", "Светлый", "Cerah", "色白", "白皙", "白皙"),
    ("skin colour", "Light tan"): ("Bronzeada clara", "Bronzeado claro", "Bronceado claro", "Hâlée claire", "Leicht gebräunt", "Abbronzata chiara", "Lichtgebruind", "Lekko opalona", "Светло-смуглый", "Sawo terang", "小麦色", "浅麦色", "淺麥色"),
    ("skin colour", "Olive"): ("Oliva", "Azeitona", "Oliva", "Olivâtre", "Oliv", "Olivastra", "Olijf", "Oliwkowa", "Оливковый", "Zaitun", "オリーブ", "橄榄色", "橄欖色"),
    ("skin colour", "Tan"): ("Morena", "Morena", "Morena", "Mate", "Gebräunt", "Ambrata", "Getint", "Śniada", "Смуглый", "Sawo matang", "褐色", "棕褐色", "棕褐色"),
    ("skin colour", "Brown"): ("Marrom", "Castanha", "Marrón", "Brune", "Braun", "Bruna", "Bruin", "Brązowa", "Коричневый", "Cokelat", "ブラウン", "棕色", "棕色"),
    ("skin colour", "Deep brown"): ("Marrom escura", "Castanha escura", "Marrón oscuro", "Brun foncé", "Dunkelbraun", "Bruno scuro", "Donkerbruin", "Ciemnobrązowa", "Тёмно-коричневый", "Cokelat tua", "ダークブラウン", "深棕色", "深棕色"),
    ("skin colour", "Ebony"): ("Ébano", "Ébano", "Ébano", "Ébène", "Ebenholz", "Ebano", "Ebbenhout", "Hebanowa", "Эбеновый", "Eboni", "エボニー", "乌木色", "烏木色"),
    ("hair colour", "Black"): ("Preto", "Preto", "Negro", "Noir", "Schwarz", "Nero", "Zwart", "Czarne", "Чёрный", "Hitam", "黒", "黑色", "黑色"),
    ("hair colour", "Dark brown"): ("Castanho-escuro", "Castanho-escuro", "Castaño oscuro", "Châtain foncé", "Dunkelbraun", "Castano scuro", "Donkerbruin", "Ciemnobrązowe", "Тёмно-каштановый", "Cokelat tua", "ダークブラウン", "深棕色", "深棕色"),
    ("hair colour", "Brown"): ("Castanho", "Castanho", "Castaño", "Châtain", "Braun", "Castano", "Bruin", "Brązowe", "Каштановый", "Cokelat", "ブラウン", "棕色", "棕色"),
    ("hair colour", "Auburn"): ("Ruivo-escuro", "Arruivado", "Caoba", "Auburn", "Kastanienrot", "Ramato", "Kastanjebruin", "Kasztanowe", "Рыжевато-каштановый", "Merah kecokelatan", "赤褐色", "赤褐色", "赤褐色"),
    ("hair colour", "Copper"): ("Acobreado", "Acobreado", "Cobrizo", "Cuivré", "Kupfer", "Rame", "Koperrood", "Miedziane", "Медный", "Tembaga", "カッパー", "铜色", "銅色"),
    ("hair colour", "Blonde"): ("Loiro", "Loiro", "Rubio", "Blond", "Blond", "Biondo", "Blond", "Blond", "Блонд", "Pirang", "金髪", "金色", "金色"),
    ("hair colour", "Platinum"): ("Platinado", "Platinado", "Platino", "Platine", "Platinblond", "Platino", "Platinablond", "Platynowe", "Платиновый", "Platinum", "プラチナ", "铂金色", "鉑金色"),
    ("hair colour", "Grey"): ("Grisalho", "Grisalho", "Canoso", "Gris", "Grau", "Grigio", "Grijs", "Siwe", "Седой", "Abu-abu", "グレー", "灰色", "灰色"),
    ("hair colour", "White"): ("Branco", "Branco", "Blanco", "Blanc", "Weiß", "Bianco", "Wit", "Białe", "Белый", "Putih", "白", "白色", "白色"),
    ("hair colour", "Blue"): ("Azul", "Azul", "Azul", "Bleu", "Blau", "Blu", "Blauw", "Niebieskie", "Синий", "Biru", "青", "蓝色", "藍色"),
    ("hair colour", "Green"): ("Verde", "Verde", "Verde", "Vert", "Grün", "Verde", "Groen", "Zielone", "Зелёный", "Hijau", "緑", "绿色", "綠色"),
    ("hair colour", "Pink"): ("Rosa", "Cor-de-rosa", "Rosa", "Rose", "Rosa", "Rosa", "Roze", "Różowe", "Розовый", "Merah muda", "ピンク", "粉色", "粉色"),
    ("cloth colour", "Crimson"): ("Carmesim", "Carmesim", "Carmesí", "Cramoisi", "Karmesin", "Cremisi", "Karmozijn", "Karmazynowy", "Малиновый", "Merah tua", "クリムゾン", "深红", "深紅"),
    ("cloth colour", "Scarlet"): ("Escarlate", "Escarlate", "Escarlata", "Écarlate", "Scharlachrot", "Scarlatto", "Scharlaken", "Szkarłatny", "Алый", "Merah terang", "スカーレット", "猩红", "猩紅"),
    ("cloth colour", "Orange"): ("Laranja", "Laranja", "Naranja", "Orange", "Orange", "Arancione", "Oranje", "Pomarańczowy", "Оранжевый", "Oranye", "オレンジ", "橙色", "橙色"),
    ("cloth colour", "Gold"): ("Dourado", "Dourado", "Dorado", "Or", "Gold", "Oro", "Goud", "Złoty", "Золотой", "Emas", "ゴールド", "金色", "金色"),
    ("cloth colour", "Lime"): ("Lima", "Lima", "Lima", "Citron vert", "Limette", "Lime", "Limoen", "Limonkowy", "Лаймовый", "Hijau limau", "ライム", "青柠色", "萊姆色"),
    ("cloth colour", "Forest"): ("Verde-floresta", "Verde-floresta", "Verde bosque", "Vert forêt", "Waldgrün", "Verde foresta", "Bosgroen", "Leśna zieleń", "Лесной зелёный", "Hijau hutan", "フォレストグリーン", "森林绿", "森林綠"),
    ("cloth colour", "Teal"): ("Verde-azulado", "Verde-azulado", "Verde azulado", "Bleu canard", "Petrol", "Verde acqua", "Petrol", "Morski", "Сине-зелёный", "Hijau toska", "ティール", "青绿色", "藍綠色"),
    ("cloth colour", "Sky"): ("Azul-celeste", "Azul-celeste", "Celeste", "Bleu ciel", "Himmelblau", "Azzurro", "Hemelsblauw", "Błękitny", "Небесный", "Biru langit", "スカイブルー", "天蓝色", "天藍色"),
    ("cloth colour", "Navy"): ("Azul-marinho", "Azul-marinho", "Azul marino", "Bleu marine", "Marineblau", "Blu navy", "Marineblauw", "Granatowy", "Тёмно-синий", "Biru dongker", "ネイビー", "海军蓝", "海軍藍"),
    ("cloth colour", "Royal blue"): ("Azul-royal", "Azul-real", "Azul real", "Bleu roi", "Königsblau", "Blu reale", "Koningsblauw", "Królewski błękit", "Королевский синий", "Biru royal", "ロイヤルブルー", "宝蓝色", "寶藍色"),
    ("cloth colour", "Violet"): ("Violeta", "Violeta", "Violeta", "Violet", "Violett", "Viola", "Violet", "Fioletowy", "Фиолетовый", "Ungu", "バイオレット", "紫罗兰色", "紫羅蘭色"),
    ("cloth colour", "Plum"): ("Ameixa", "Ameixa", "Ciruela", "Prune", "Pflaume", "Prugna", "Pruim", "Śliwkowy", "Сливовый", "Plum", "プラム", "梅子色", "梅子色"),
    ("cloth colour", "Rose"): ("Rosa", "Rosa", "Rosa", "Rose", "Rosé", "Rosa", "Rozerood", "Różany", "Розовый", "Merah mawar", "ローズ", "玫瑰色", "玫瑰色"),
    ("cloth colour", "Leather"): ("Couro", "Couro", "Cuero", "Cuir", "Leder", "Cuoio", "Leer", "Skórzany", "Кожаный", "Kulit", "レザー", "皮革色", "皮革色"),
    ("cloth colour", "Charcoal"): ("Grafite", "Carvão", "Carbón", "Anthracite", "Anthrazit", "Antracite", "Antraciet", "Grafitowy", "Угольный", "Arang", "チャコール", "炭灰色", "炭灰色"),
    ("cloth colour", "Ivory"): ("Marfim", "Marfim", "Marfil", "Ivoire", "Elfenbein", "Avorio", "Ivoor", "Kość słoniowa", "Слоновая кость", "Gading", "アイボリー", "象牙色", "象牙色"),
}
# fmt: on

# How gettext itself joins a context to its msgid in a compiled catalog.
CONTEXT_SEPARATOR = "\x04"


def key(msgid: str, msgctxt: str | None = None) -> str:
    """The glossary key of a catalog entry: its msgid, behind its context if any."""
    return f"{msgctxt}{CONTEXT_SEPARATOR}{msgid}" if msgctxt else msgid


def source_of(term: str) -> str:
    """The English label a glossary key curates, without its context."""
    return term.rsplit(CONTEXT_SEPARATOR, 1)[-1]


_ROWS.update({key(msgid, msgctxt): row for (msgctxt, msgid), row in _CONTEXT_ROWS.items()})

# The product's own names, as each language writes them (`names.py`), are
# labels too wherever they stand alone.
_ROWS.update(
    {name: tuple(names.form(name, code) for code in LOCALE_ORDER) for name in names.NAMES}
)


def _validate() -> None:
    from .quality import has_trailing_stop, looks_like_mojibake

    width = len(LOCALE_ORDER)

    for term, row in _ROWS.items():
        if len(row) != width:
            raise ValueError(f"glossary row {term!r} has {len(row)} values, expected {width}")

        for locale_code, value in zip(LOCALE_ORDER, row):
            if not value.strip():
                raise ValueError(f"glossary {term!r} has an empty value for {locale_code}")

            if has_trailing_stop(source_of(term), value):
                raise ValueError(f"glossary {term!r} for {locale_code} ends in a full stop: {value!r}")

            if looks_like_mojibake(value):
                raise ValueError(f"glossary {term!r} for {locale_code} looks corrupted: {value!r}")


_validate()

GLOSSARY: dict[str, dict[str, str]] = {
    term: dict(zip(LOCALE_ORDER, row)) for term, row in _ROWS.items()
}


def for_locale(locale_code: str) -> dict[str, str]:
    """Curated source -> translation pairs for one locale."""
    return {
        term: translations[locale_code]
        for term, translations in GLOSSARY.items()
        if locale_code in translations
    }


def terms() -> frozenset[str]:
    return frozenset(GLOSSARY)
