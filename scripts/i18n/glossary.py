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
"""

from __future__ import annotations

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
    "Done":         ("Concluído", "Concluído", "Hecho", "Terminé", "Fertig", "Fatto", "Klaar", "Gotowe", "Готово", "Selesai", "完了", "完成", "完成"),
    "Apply":        ("Aplicar", "Aplicar", "Aplicar", "Appliquer", "Übernehmen", "Applica", "Toepassen", "Zastosuj", "Применить", "Terapkan", "適用", "应用", "套用"),
    "Save":         ("Salvar", "Guardar", "Guardar", "Enregistrer", "Speichern", "Salva", "Opslaan", "Zapisz", "Сохранить", "Simpan", "保存", "保存", "儲存"),
    "Retry":        ("Tentar novamente", "Repetir", "Reintentar", "Réessayer", "Wiederholen", "Riprova", "Opnieuw proberen", "Ponów", "Повторить", "Coba lagi", "再試行", "重试", "重試"),
    "Continue":     ("Continuar", "Continuar", "Continuar", "Continuer", "Fortfahren", "Continua", "Doorgaan", "Kontynuuj", "Продолжить", "Lanjutkan", "続ける", "继续", "繼續"),
    "Confirm":      ("Confirmar", "Confirmar", "Confirmar", "Confirmer", "Bestätigen", "Conferma", "Bevestigen", "Potwierdź", "Подтвердить", "Konfirmasi", "確認", "确认", "確認"),
    "Accept":       ("Aceitar", "Aceitar", "Aceptar", "Accepter", "Annehmen", "Accetta", "Accepteren", "Akceptuj", "Принять", "Terima", "承認", "接受", "接受"),
    "Decline":      ("Recusar", "Recusar", "Rechazar", "Refuser", "Ablehnen", "Rifiuta", "Weigeren", "Odrzuć", "Отклонить", "Tolak", "拒否", "拒绝", "拒絕"),

    # ── Navigation ────────────────────────────────────────────
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

    # ── Transfer ──────────────────────────────────────────────
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
    "Automation":   ("Automação", "Automação", "Automatización", "Automatisation", "Automatisierung", "Automazione", "Automatisering", "Automatyzacja", "Автоматизация", "Otomatisasi", "自動化", "自动化", "自動化"),

    # ── Connection ────────────────────────────────────────────
    "Connect":      ("Conectar", "Ligar", "Conectar", "Se connecter", "Verbinden", "Connetti", "Verbinden", "Połącz", "Подключиться", "Hubungkan", "接続", "连接", "連線"),
    "Disconnect":   ("Desconectar", "Desligar", "Desconectar", "Se déconnecter", "Trennen", "Disconnetti", "Verbinding verbreken", "Rozłącz", "Отключиться", "Putuskan", "切断", "断开", "斷線"),
    "Connected":    ("Conectado", "Ligado", "Conectado", "Connecté", "Verbunden", "Connesso", "Verbonden", "Połączono", "Подключено", "Terhubung", "接続済み", "已连接", "已連線"),
    "Disconnected": ("Desconectado", "Desligado", "Desconectado", "Déconnecté", "Getrennt", "Disconnesso", "Verbinding verbroken", "Rozłączono", "Отключено", "Terputus", "切断済み", "已断开", "已斷線"),
    "Connecting":   ("Conectando", "A ligar", "Conectando", "Connexion", "Verbindung wird hergestellt", "Connessione", "Verbinden", "Łączenie", "Подключение", "Menghubungkan", "接続中", "连接中", "連線中"),
    "Reconnecting": ("Reconectando", "A reconectar", "Reconectando", "Reconnexion", "Erneut verbinden", "Riconnessione", "Opnieuw verbinden", "Ponowne łączenie", "Переподключение", "Menghubungkan ulang", "再接続中", "重新连接中", "重新連線中"),

    # ── Status ────────────────────────────────────────────────
    "Ready":        ("Pronto", "Pronto", "Listo", "Prêt", "Bereit", "Pronto", "Gereed", "Gotowy", "Готово", "Siap", "準備完了", "就绪", "就緒"),
    "Away":         ("Ausente", "Ausente", "Ausente", "Absent", "Abwesend", "Assente", "Afwezig", "Nieobecny", "Отошёл", "Tidak di tempat", "離席中", "离开", "離開"),
    "Idle":         ("Inativo", "Inativo", "Inactivo", "Inactif", "Inaktiv", "Inattivo", "Inactief", "Bezczynny", "Неактивен", "Diam", "アイドル", "空闲", "閒置"),
    "Online":       ("Online", "Online", "En línea", "En ligne", "Online", "Online", "Online", "Online", "В сети", "Daring", "オンライン", "在线", "線上"),
    "Offline":      ("Offline", "Offline", "Sin conexión", "Hors ligne", "Offline", "Offline", "Offline", "Offline", "Не в сети", "Luring", "オフライン", "离线", "離線"),
    "Loading":      ("Carregando", "A carregar", "Cargando", "Chargement", "Wird geladen", "Caricamento", "Laden", "Ładowanie", "Загрузка", "Memuat", "読み込み中", "加载中", "載入中"),
    "Error":        ("Erro", "Erro", "Error", "Erreur", "Fehler", "Errore", "Fout", "Błąd", "Ошибка", "Kesalahan", "エラー", "错误", "錯誤"),
    "Warning":      ("Aviso", "Aviso", "Advertencia", "Avertissement", "Warnung", "Avviso", "Waarschuwing", "Ostrzeżenie", "Предупреждение", "Peringatan", "警告", "警告", "警告"),
    "Failed":       ("Falhou", "Falhou", "Falló", "Échec", "Fehlgeschlagen", "Non riuscito", "Mislukt", "Niepowodzenie", "Не удалось", "Gagal", "失敗", "失败", "失敗"),
    "Success":      ("Sucesso", "Sucesso", "Éxito", "Succès", "Erfolg", "Successo", "Gelukt", "Powodzenie", "Успешно", "Berhasil", "成功", "成功", "成功"),

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
    "P2P Session":  ("Sessão P2P", "Sessão P2P", "Sesión P2P", "Session P2P", "P2P-Sitzung", "Sessione P2P", "P2P-sessie", "Sesja P2P", "P2P-сессия", "Sesi P2P", "P2Pセッション", "P2P 会话", "P2P 工作階段"),
    "P2P Session Console": ("Console de Sessão P2P", "Consola de Sessão P2P", "Consola de Sesión P2P", "Console de session P2P", "P2P-Sitzungskonsole", "Console di sessione P2P", "P2P-sessieconsole", "Konsola sesji P2P", "Консоль P2P-сессии", "Konsol Sesi P2P", "P2Pセッションコンソール", "P2P 会话控制台", "P2P 工作階段主控台"),
    "P2P Sessions in Chat": ("Sessões P2P no chat", "Sessões P2P no chat", "Sesiones P2P en el chat", "Sessions P2P dans le chat", "P2P-Sitzungen im Chat", "Sessioni P2P nella chat", "P2P-sessies in de chat", "Sesje P2P w czacie", "P2P-сессии в чате", "Sesi P2P dalam Percakapan", "チャットでのP2Pセッション", "P2P 聊天会话", "P2P 聊天對話"),

    # ── Chat actions ──────────────────────────────────────────
    "Mute":         ("Silenciar", "Silenciar", "Silenciar", "Couper le son", "Stummschalten", "Disattiva audio", "Dempen", "Wycisz", "Отключить звук", "Bisukan", "ミュート", "静音", "靜音"),
    "Unmute":       ("Reativar som", "Reativar som", "Activar sonido", "Réactiver le son", "Stummschaltung aufheben", "Riattiva audio", "Dempen opheffen", "Wyłącz wyciszenie", "Включить звук", "Suarakan", "ミュート解除", "取消静音", "取消靜音"),
    "Join":         ("Entrar", "Entrar", "Unirse", "Rejoindre", "Beitreten", "Entra", "Deelnemen", "Dołącz", "Присоединиться", "Gabung", "参加", "加入", "加入"),
    "Leave":        ("Sair", "Sair", "Salir", "Quitter", "Verlassen", "Esci", "Verlaten", "Opuść", "Покинуть", "Keluar", "退出", "离开", "離開"),
    "Start":        ("Iniciar", "Iniciar", "Iniciar", "Démarrer", "Starten", "Avvia", "Starten", "Rozpocznij", "Начать", "Mulai", "開始", "开始", "開始"),
    "Stop":         ("Parar", "Parar", "Detener", "Arrêter", "Stoppen", "Ferma", "Stoppen", "Zatrzymaj", "Остановить", "Berhenti", "停止", "停止", "停止"),
    "Pause":        ("Pausar", "Pausar", "Pausar", "Pause", "Pause", "Pausa", "Pauzeren", "Wstrzymaj", "Пауза", "Jeda", "一時停止", "暂停", "暫停"),
    "Resume":       ("Retomar", "Retomar", "Reanudar", "Reprendre", "Fortsetzen", "Riprendi", "Hervatten", "Wznów", "Продолжить", "Lanjutkan", "再開", "继续", "繼續"),
    "Ignore":       ("Ignorar", "Ignorar", "Ignorar", "Ignorer", "Ignorieren", "Ignora", "Negeren", "Ignoruj", "Игнорировать", "Abaikan", "無視", "忽略", "忽略"),
    "Block":        ("Bloquear", "Bloquear", "Bloquear", "Bloquer", "Blockieren", "Blocca", "Blokkeren", "Zablokuj", "Заблокировать", "Blokir", "ブロック", "屏蔽", "封鎖"),

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
}
# fmt: on


def _validate() -> None:
    from .quality import has_trailing_stop, looks_like_mojibake

    width = len(LOCALE_ORDER)

    for term, row in _ROWS.items():
        if len(row) != width:
            raise ValueError(f"glossary row {term!r} has {len(row)} values, expected {width}")

        for locale_code, value in zip(LOCALE_ORDER, row):
            if not value.strip():
                raise ValueError(f"glossary {term!r} has an empty value for {locale_code}")

            if has_trailing_stop(term, value):
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
