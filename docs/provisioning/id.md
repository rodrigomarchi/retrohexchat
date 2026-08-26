# RetroHexChat — Indonesian Rooms — `id`

Ten channels, twelve bots, twenty-nine verified feeds — the largest wire of any
language here. Documentation in English for the operator; everything a user
reads is in Indonesian.

Indonesia is the one language where the section feed beat the publisher feed.
Antara, CNN Indonesia, Tempo and Detik each publish a separate address per desk,
and all of them answered; the whole-site feeds mostly did not. So every room is
fed by three or four newsrooms at once, each on the desk that room is about,
which is why `#ekonomi` and `#olahraga` carry more sources than any room in the
English script.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Pemasangan id
#  10 kanal · 12 bot · feed diperiksa satu per satu
# ══════════════════════════════════════════════════════════

# ── 1. Kanal ─────────────────────────────────────────────

/join #indonesia
/cs register
/topic Kanal berbahasa Indonesia — masuk, duduk, ngobrol. Kopinya gratis.
/mode +tn

/join #berita
/cs register
/topic Berita — Tempo, CNN Indonesia dan Republika, langsung dari feed. !Rina sumber menampilkan daftarnya.
/mode +tn

/join #politik
/cs register
/topic Politik — Antara, Sindonews dan Okezone. Kabar dari Senayan dan sekitarnya.
/mode +tn

/join #dunia
/cs register
/topic Dunia — BBC Indonesia dan CNN Indonesia Internasional. Kabar luar negeri, bahasa sendiri.
/mode +tn

/join #teknologi
/cs register
/topic Teknologi — detikInet, Antara Tekno, CNN Indonesia Teknologi dan Hybrid. Dukungan proyek ada di proyeknya; di sini kita ngobrol.
/mode +tn

/join #olahraga
/cs register
/topic Olahraga — detikSport, Antara, CNN Indonesia dan Tempo Bola. Klasemen, transfer, dan debat biasa.
/mode +tn

/join #ekonomi
/cs register
/topic Ekonomi — CNBC Indonesia, Katadata, Antara, Tempo Bisnis dan CNN Indonesia. Judul berita bukan rekomendasi.
/mode +tn

/join #hiburan
/cs register
/topic Hiburan — Antara, CNN Indonesia dan Tempo Seleb. Film, musik, dan gosip yang sudah terverifikasi.
/mode +tn

/join #gayahidup
/cs register
/topic Gaya hidup — CNN Indonesia dan Tempo Gaya. Makan, jalan, kesehatan, kebiasaan.
/mode +tn

/join #gim
/cs register
/topic Gim — Gamebrott di saluran. Mau benar-benar main? Buka menu Games: 18 klasik langsung di peramban.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Satpam — moderasi, semua kanal
# ══════════════════════════════════════════════════════════
# Tiap bahasa punya moderator sendiri: peringatan yang tak terbaca bukan
# peringatan. Diam saat orang masuk dan keluar — dia ada di sepuluh kanal, dan
# penjaga yang menyapa dua kali terlihat seperti kerusakan.
/bot create Satpam Kepala keamanan dan ketenangan kanal
/bot set Satpam prefix !
/bot set Satpam cooldown 1000
/bot set Satpam mod_action warn
/bot set Satpam mod_spam 5
/bot set Satpam mod_flood 8
/bot set Satpam mod_warn \c04\b[Satpam]\o Pelan-pelan, {nickname}. \c05Sopan dulu\o — di sini ruang obrolan, bukan pasar.
/bot set Satpam greeting none
/bot set Satpam farewell none
/bot set Satpam mention_response \c04\b[Satpam]\o Saya mengawasi. \c05Selalu\o. Jaga sikap, kita pasti akur.

/bot addcmd Satpam aturan \c04\b[Satpam]\o Versi pendek: \c05jangan menyebalkan\o. Versi panjang tidak ada.
/bot addcmd Satpam lapor \c04\b[Satpam]\o Lihat yang aneh? \c05Beri tahu admin\o. Saya urus yang otomatis, manusia urus sisanya.

/bot join Satpam #indonesia
/bot join Satpam #berita
/bot join Satpam #politik
/bot join Satpam #dunia
/bot join Satpam #teknologi
/bot join Satpam #olahraga
/bot join Satpam #ekonomi
/bot join Satpam #hiburan
/bot join Satpam #gayahidup
/bot join Satpam #gim

# ══════════════════════════════════════════════════════════
#  3. Ayu — tuan rumah #indonesia
# ══════════════════════════════════════════════════════════
# Sambutan lewat notice pribadi: pendatang baru dapat arahan di dalam kanal
# tanpa memenuhi riwayat obrolan orang lain.
/bot create Ayu Tuan rumah kanal Indonesia
/bot set Ayu prefix !
/bot set Ayu cooldown 1000
/bot set Ayu dice_default 1d20
/bot set Ayu greeting \c03\b[Ayu]\o Halo {nickname}! Saya Ayu. \c02Coba !kanal\o, !selamatpagi atau !inggris. Anggap rumah sendiri.
/bot set Ayu greeting_delivery private_notice
/bot set Ayu greeter_repeat_window 43200
/bot set Ayu public_greeting \c03\b[Ayu]\o \b{nickname}\o baru masuk. Duduk dulu.
/bot set Ayu onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Ayu onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Ayu farewell none
/bot set Ayu mention_response \c03\b[Ayu]\o Dipanggil? Saya di sini. \c02Coba !kanal\o.

/bot addcmd Ayu kanal \c03\b[Ayu]\o #indonesia #berita #politik #dunia #teknologi #olahraga #ekonomi #hiburan #gayahidup #gim — \c02sepuluh kanal berbahasa Indonesia\o, dan semuanya ada isinya.
/bot addcmd Ayu selamatpagi \c03\b[Ayu]\o \c02Selamat pagi\o, {nickname}. Kopi sudah jadi, papan ketik bersih, hari dimulai.
/bot addcmd Ayu inggris \c03\b[Ayu]\o Ada juga kanal berbahasa Inggris, {nickname}: \c02#lobby, #tech, #news\o dan lainnya. Bahasa diganti dari bilah alat.
/bot addcmd Ayu redaksi \c03\b[Ayu]\o Tiap kanal di sini diisi \c02tiga sampai lima ruang redaksi sekaligus\o, {nickname} — Antara, CNN Indonesia, Tempo dan Detik punya feed terpisah per desk.

/bot join Ayu #indonesia

# ══════════════════════════════════════════════════════════
#  4. Bot feed — satu per kanal
# ══════════════════════════════════════════════════════════
# Setiap alamat di bawah diambil dengan fetcher produksi dan dibaca parser
# aplikasi sebelum ditulis di sini. Pemeriksaan pertama menerbitkan halaman
# yang diterima lalu mencatatnya; setelah itu hanya yang baru yang keluar.
#
# Bacaan pertama keluar bertahap, bukan sekaligus: proteksi flood ada di sesi
# tiap pembaca dan otomatis mengabaikan yang melewatinya. Tidak ada yang dibuang
# — feed yang punya antrean kembali dalam waktu kurang dari satu menit.

# ── Bagus — #indonesia ───────────────────────────────────
# Tanpa sambutan: di kanal ini yang menyambut adalah Ayu.
/bot create Bagus Wartawan piket
/bot set Bagus prefix !
/bot set Bagus cooldown 1000
/bot set Bagus rss_interval 20
/bot set Bagus greeting none
/bot set Bagus farewell none
/bot set Bagus mention_response \c03\b[Bagus]\o Saya membaca Antara dan Detik. \c02!sumber\o menampilkan feed-nya.
/bot addcmd Bagus sumber \c03\b[Bagus]\o Antara dan Detik, diperiksa \c02tiap dua puluh menit\o.
/bot join Bagus #indonesia
/bot rss add Bagus https://www.antaranews.com/rss/terkini.xml #indonesia
/bot rss add Bagus https://news.detik.com/berita/rss #indonesia

# ── Rina — #berita ───────────────────────────────────────
/bot create Rina Redaktur meja berita
/bot set Rina prefix !
/bot set Rina cooldown 1000
/bot set Rina rss_interval 20
/bot set Rina greeting \c02\b[Rina]\o Selamat datang di #berita, {nickname}. \c14Judul datang sendiri\o — !sumber menyebut asalnya.
/bot set Rina greeting_delivery private_notice
/bot set Rina greeter_repeat_window 43200
/bot set Rina public_greeting \c02\b[Rina]\o \b{nickname}\o masuk ke redaksi.
/bot set Rina onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Rina onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Rina farewell none
/bot set Rina mention_response \c02\b[Rina]\o Saya menerbitkan apa yang dikirim feed. \c14!sumber\o untuk daftarnya, !pertama untuk sisanya.
/bot addcmd Rina sumber \c02\b[Rina]\o Tempo, CNN Indonesia dan Republika, diperiksa \c14tiap dua puluh menit\o.
/bot addcmd Rina pertama \c02\b[Rina]\o Pemeriksaan pertama menerbitkan halaman saat ini lalu mencatatnya. Sesudah itu \c14hanya yang baru yang keluar\o.
/bot join Rina #berita
/bot rss add Rina https://rss.tempo.co/nasional #berita
/bot rss add Rina https://www.cnnindonesia.com/nasional/rss #berita
/bot rss add Rina https://www.republika.co.id/rss #berita

# ── Joko — #politik ──────────────────────────────────────
/bot create Joko Pengamat Senayan
/bot set Joko prefix !
/bot set Joko cooldown 1000
/bot set Joko rss_interval 20
/bot set Joko greeting \c07\b[Joko]\o Selamat datang, {nickname}. \c11Antara, Sindonews dan Okezone\o masuk sendiri ke sini. !sumber untuk daftarnya.
/bot set Joko greeting_delivery private_notice
/bot set Joko greeter_repeat_window 43200
/bot set Joko public_greeting \c07\b[Joko]\o \b{nickname}\o bergabung. Selamat datang.
/bot set Joko onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Joko onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Joko farewell none
/bot set Joko mention_response \c07\b[Joko]\o Tiga ruang redaksi politik. \c11!sumber\o menyebut yang mana.
/bot addcmd Joko sumber \c07\b[Joko]\o Antara Politik, Sindonews dan Okezone, diperiksa \c11tiap dua puluh menit\o.
/bot join Joko #politik
/bot rss add Joko https://www.antaranews.com/rss/politik.xml #politik
/bot rss add Joko https://nasional.sindonews.com/rss #politik
/bot rss add Joko https://sindikasi.okezone.com/index.php/rss/0/RSS2.0 #politik

# ── Dewi — #dunia ────────────────────────────────────────
/bot create Dewi Koresponden luar negeri
/bot set Dewi prefix !
/bot set Dewi cooldown 1000
/bot set Dewi rss_interval 30
/bot set Dewi greeting \c10\b[Dewi]\o Halo {nickname}. \c06BBC Indonesia dan CNN Indonesia Internasional\o di saluran. !sumber untuk daftarnya.
/bot set Dewi greeting_delivery private_notice
/bot set Dewi greeter_repeat_window 43200
/bot set Dewi public_greeting \c10\b[Dewi]\o \b{nickname}\o sudah di sini.
/bot set Dewi onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Dewi onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Dewi farewell none
/bot set Dewi mention_response \c10\b[Dewi]\o Kabar dunia, bahasa sendiri. \c06!sumber\o menyebut keduanya.
/bot addcmd Dewi sumber \c10\b[Dewi]\o BBC Indonesia dan CNN Indonesia Internasional, diperiksa \c06tiap setengah jam\o.
/bot join Dewi #dunia
/bot rss add Dewi https://feeds.bbci.co.uk/indonesia/rss.xml #dunia
/bot rss add Dewi https://www.cnnindonesia.com/internasional/rss #dunia

# ── Adi — #teknologi ─────────────────────────────────────
/bot create Adi Pemerhati teknologi
/bot set Adi prefix !
/bot set Adi cooldown 1000
/bot set Adi rss_interval 30
/bot set Adi greeting \c12\b[Adi]\o Halo {nickname}. \c10Empat sumber teknologi\o jatuh ke sini sendiri. !sumber untuk daftarnya, !dukungan sebelum bertanya.
/bot set Adi greeting_delivery private_notice
/bot set Adi greeter_repeat_window 43200
/bot set Adi public_greeting \c12\b[Adi]\o \b{nickname}\o masuk. Selamat datang.
/bot set Adi onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Adi onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Adi farewell none
/bot set Adi mention_response \c12\b[Adi]\o detikInet, Antara Tekno, CNN Indonesia Teknologi dan Hybrid. \c10!sumber\o menyebut semuanya.
/bot addcmd Adi sumber \c12\b[Adi]\o detikInet, Antara Tekno, CNN Indonesia Teknologi dan Hybrid, diperiksa \c10tiap setengah jam\o.
/bot addcmd Adi dukungan \c12\b[Adi]\o Dukungan sebuah proyek ada di proyeknya, {nickname} — yang menjawab dengan baik adalah yang merawatnya. \c10Di sini kita ngobrol\o.
/bot join Adi #teknologi
/bot rss add Adi https://inet.detik.com/rss #teknologi
/bot rss add Adi https://www.antaranews.com/rss/tekno.xml #teknologi
/bot rss add Adi https://www.cnnindonesia.com/teknologi/rss #teknologi
/bot rss add Adi https://hybrid.co.id/feed #teknologi

# ── Yusuf — #olahraga ────────────────────────────────────
/bot create Yusuf Juru catat tribun
/bot set Yusuf prefix !
/bot set Yusuf cooldown 1000
/bot set Yusuf rss_interval 20
/bot set Yusuf greeting \c09\b[Yusuf]\o Halo {nickname}! \c03Empat meja olahraga\o di saluran. !sumber untuk daftarnya, !klub kalau memaksa.
/bot set Yusuf greeting_delivery private_notice
/bot set Yusuf greeter_repeat_window 43200
/bot set Yusuf public_greeting \c09\b[Yusuf]\o \b{nickname}\o turun ke lapangan.
/bot set Yusuf onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Yusuf onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Yusuf farewell none
/bot set Yusuf mention_response \c09\b[Yusuf]\o Bola bergulir. \c03!sumber\o menyebut yang saya baca.
/bot addcmd Yusuf sumber \c09\b[Yusuf]\o detikSport, Antara Olahraga, CNN Indonesia Olahraga dan Tempo Bola, diperiksa \c03tiap dua puluh menit\o.
/bot addcmd Yusuf klub \c09\b[Yusuf]\o Klub saya rahasia, {nickname}. \c03Bot yang punya klub\o kehilangan separuh kanal di derbi pertama.
/bot join Yusuf #olahraga
/bot rss add Yusuf https://sport.detik.com/rss #olahraga
/bot rss add Yusuf https://www.antaranews.com/rss/olahraga.xml #olahraga
/bot rss add Yusuf https://www.cnnindonesia.com/olahraga/rss #olahraga
/bot rss add Yusuf https://rss.tempo.co/bola #olahraga

# ── Sari — #ekonomi ──────────────────────────────────────
# Lima feed adalah batas per bot; yang ini pas di batasnya.
/bot create Sari Pemantau pasar
/bot set Sari prefix !
/bot set Sari cooldown 1000
/bot set Sari rss_interval 30
/bot set Sari rss_max_feeds 5
/bot set Sari greeting \c07\b[Sari]\o Selamat datang, {nickname}. \c02Lima meja ekonomi\o di saluran — !sumber untuk daftarnya, !ingat sebelum percaya.
/bot set Sari greeting_delivery private_notice
/bot set Sari greeter_repeat_window 43200
/bot set Sari public_greeting \c07\b[Sari]\o \b{nickname}\o masuk pasar.
/bot set Sari onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Sari onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Sari farewell none
/bot set Sari mention_response \c07\b[Sari]\o Lima sumber ekonomi sekaligus. \c02!sumber\o menyebut semuanya.
/bot addcmd Sari sumber \c07\b[Sari]\o CNBC Indonesia, Katadata, Antara Ekonomi, Tempo Bisnis dan CNN Indonesia Ekonomi, diperiksa \c02tiap setengah jam\o.
/bot addcmd Sari ingat \c07\b[Sari]\o Judul berita bukan rekomendasi, {nickname}. \c02Saya membaca feed\o, bukan bola kristal.
/bot join Sari #ekonomi
/bot rss add Sari https://www.cnbcindonesia.com/market/rss #ekonomi
/bot rss add Sari https://katadata.co.id/rss #ekonomi
/bot rss add Sari https://www.antaranews.com/rss/ekonomi.xml #ekonomi
/bot rss add Sari https://rss.tempo.co/bisnis #ekonomi
/bot rss add Sari https://www.cnnindonesia.com/ekonomi/rss #ekonomi

# ── Wayan — #hiburan ─────────────────────────────────────
/bot create Wayan Penjaga meja hiburan
/bot set Wayan prefix !
/bot set Wayan cooldown 1000
/bot set Wayan rss_interval 45
/bot set Wayan greeting \c13\b[Wayan]\o Masuk, {nickname}. \c05Antara, CNN Indonesia dan Tempo Seleb\o di saluran. !sumber untuk daftarnya.
/bot set Wayan greeting_delivery private_notice
/bot set Wayan greeter_repeat_window 43200
/bot set Wayan public_greeting \c13\b[Wayan]\o \b{nickname}\o bergabung. Selamat datang.
/bot set Wayan onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Wayan onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Wayan farewell none
/bot set Wayan mention_response \c13\b[Wayan]\o Film, musik dan kabar selebritas. \c05!sumber\o menyebut salurannya.
/bot addcmd Wayan sumber \c13\b[Wayan]\o Antara Hiburan, CNN Indonesia Hiburan dan Tempo Seleb, diperiksa \c05tiap 45 menit\o.
/bot join Wayan #hiburan
/bot rss add Wayan https://www.antaranews.com/rss/hiburan.xml #hiburan
/bot rss add Wayan https://www.cnnindonesia.com/hiburan/rss #hiburan
/bot rss add Wayan https://rss.tempo.co/seleb #hiburan

# ── Intan — #gayahidup ───────────────────────────────────
/bot create Intan Penjaga rubrik gaya hidup
/bot set Intan prefix !
/bot set Intan cooldown 1000
/bot set Intan rss_interval 60
/bot set Intan greeting \c06\b[Intan]\o Halo {nickname}. \c11CNN Indonesia Gaya Hidup dan Tempo Gaya\o datang tiap jam. !sumber untuk daftarnya.
/bot set Intan greeting_delivery private_notice
/bot set Intan greeter_repeat_window 43200
/bot set Intan public_greeting \c06\b[Intan]\o \b{nickname}\o sudah di sini.
/bot set Intan onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Intan onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Intan farewell none
/bot set Intan mention_response \c06\b[Intan]\o Makan, jalan, kesehatan. \c11!sumber\o menyebut salurannya.
/bot addcmd Intan sumber \c06\b[Intan]\o CNN Indonesia Gaya Hidup dan Tempo Gaya, diperiksa \c11tiap jam\o.
/bot join Intan #gayahidup
/bot rss add Intan https://www.cnnindonesia.com/gaya-hidup/rss #gayahidup
/bot rss add Intan https://rss.tempo.co/gaya #gayahidup

# ── Rizky — #gim ─────────────────────────────────────────
/bot create Rizky Penjaga ruang gim
/bot set Rizky prefix !
/bot set Rizky cooldown 1000
/bot set Rizky rss_interval 60
/bot set Rizky greeting \c12\b[Rizky]\o Masuk, {nickname}! \c10Gamebrott\o di saluran, dan menu Games membuka 18 klasik di peramban. !sumber, !main.
/bot set Rizky greeting_delivery private_notice
/bot set Rizky greeter_repeat_window 43200
/bot set Rizky public_greeting \c12\b[Rizky]\o \b{nickname}\o masuk ke permainan.
/bot set Rizky onboarding_1 \c14\b[{botname}]\o \c10/join #indonesia\o masuk ruangan · \c10/msg nick\o bicara pribadi · \c10/nick nama\o ganti namamu.
/bot set Rizky onboarding_2 \c14\b[{botname}]\o \c10/part\o keluar dari ruangan · \c10/help\o menampilkan semua perintah.
/bot set Rizky farewell none
/bot set Rizky mention_response \c12\b[Rizky]\o Kabar gim saya yang bawa. \c10!main\o menjelaskan cara mainnya di sini.
/bot addcmd Rizky sumber \c12\b[Rizky]\o Gamebrott, diperiksa \c10tiap jam\o.
/bot addcmd Rizky main \c12\b[Rizky]\o Buka menu \c10Games\o di bilah atas, {nickname}: DOOM, Quake, Wolfenstein dan enam petualangan ScummVM, semua di peramban.
/bot join Rizky #gim
/bot rss add Rizky https://www.gamebrott.com/feed #gim
```

---

## Verification

```
/bot list
/bot info Satpam
/bot info Sari
/admin channel list
```

`!Sari rss list` is the one worth checking: it is the only bot at the five-feed
ceiling, so a sixth address silently refused would show up there first.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#indonesia` | **Ayu**, Bagus | Antara, Detik |
| `#berita` | **Rina** | Tempo, CNN Indonesia, Republika |
| `#politik` | **Joko** | Antara Politik, Sindonews, Okezone |
| `#dunia` | **Dewi** | BBC Indonesia, CNN Indonesia Internasional |
| `#teknologi` | **Adi** | detikInet, Antara Tekno, CNN Indonesia Teknologi, Hybrid |
| `#olahraga` | **Yusuf** | detikSport, Antara, CNN Indonesia, Tempo Bola |
| `#ekonomi` | **Sari** | CNBC Indonesia, Katadata, Antara, Tempo Bisnis, CNN Indonesia |
| `#hiburan` | **Wayan** | Antara, CNN Indonesia, Tempo Seleb |
| `#gayahidup` | **Intan** | CNN Indonesia, Tempo Gaya |
| `#gim` | **Rizky** | Gamebrott |

**Satpam** stands in all ten and greets in none of them. All channels are `+tn`.
