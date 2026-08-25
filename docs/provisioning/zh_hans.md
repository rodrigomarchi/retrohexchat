# RetroHexChat — Simplified Chinese Rooms — `zh_hans`

Ten channels, twelve bots, twenty verified feeds. Documentation in English for
the operator; everything a user reads is in Simplified Chinese.

Room names use a `cn-` prefix rather than pinyin, for the same reason the
Japanese script uses `jp-`: pinyin without tones is not a writing system anyone
reads, and the client only linkifies ASCII channel names. `#zhongwen` is the
exception — it names the language, not a topic.

What survived the feed check is lopsided towards technology and away from
newsrooms, so the rooms follow the sources rather than a translated copy of the
English list: `#cn-blog` for the independent writers who have outlasted every
platform, `#cn-apps` for the software-recommendation press that has no Western
equivalent.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — 安装 zh_hans
#  10 个频道 · 12 个机器人 · 订阅源逐条验证
# ══════════════════════════════════════════════════════════

# ── 1. 频道 ──────────────────────────────────────────────

/join #zhongwen
/cs register
/topic 中文频道 — 进来坐，聊聊天。咖啡算店里的。
/mode +tn

/join #cn-tech
/cs register
/topic 科技 — cnBeta、IT之家、Solidot，直接来自订阅源。!Lifeng sources 显示清单。
/mode +tn

/join #cn-digital
/cs register
/topic 数码 — 爱范儿和极客公园。产品、评测，以及围绕它们的生意。
/mode +tn

/join #cn-apps
/cs register
/topic 软件 — 少数派和小众软件。工具、玩法、值得装的东西。
/mode +tn

/join #cn-blog
/cs register
/topic 博客 — 月光博客、阮一峰、酷壳。比任何平台都活得久的独立写作。
/mode +tn

/join #cn-dev
/cs register
/topic 开发 — InfoQ 中文站在线上。项目的支持在项目那边；这里是闲聊。
/mode +tn

/join #cn-open
/cs register
/topic 开源 — 开源中国。发布、内核、发行版。
/mode +tn

/join #cn-ai
/cs register
/topic 人工智能 — 雷锋网和量子位。模型、论文、落地和吹牛。
/mode +tn

/join #cn-games
/cs register
/topic 游戏 — 机核和游研社。真要玩的话，打开 Games 菜单：18 款经典直接在浏览器里跑。
/mode +tn

/join #cn-money
/cs register
/topic 商业 — 钛媒体在线上。标题不是投资建议。
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Weishi — 值守，所有频道
# ══════════════════════════════════════════════════════════
# 每种语言配自己的值守：看不懂的警告不算警告。进出时不出声 —— 它站在十个
# 频道里，打两次招呼看起来像故障，不像性格。
/bot create Weishi Anjing yu limao de fuzeren
/bot set Weishi prefix !
/bot set Weishi cooldown 1000
/bot set Weishi mod_action warn
/bot set Weishi mod_spam 5
/bot set Weishi mod_flood 8
/bot set Weishi mod_warn \c04\b[Weishi]\o 慢一点，{nickname}。\c05客气一些\o大家都舒服，我不着急。
/bot set Weishi greeting none
/bot set Weishi farewell none
/bot set Weishi mention_response \c04\b[Weishi]\o 我在看着。\c05一直看着\o。守规矩，就什么都不会发生。

/bot addcmd Weishi rules \c04\b[Weishi]\o 短版：\c05别当讨厌鬼\o。长版没有。
/bot addcmd Weishi report \c04\b[Weishi]\o 看到奇怪的事？\c05告诉管理员\o。自动的归我，剩下的归人。

/bot join Weishi #zhongwen
/bot join Weishi #cn-tech
/bot join Weishi #cn-digital
/bot join Weishi #cn-apps
/bot join Weishi #cn-blog
/bot join Weishi #cn-dev
/bot join Weishi #cn-open
/bot join Weishi #cn-ai
/bot join Weishi #cn-games
/bot join Weishi #cn-money

# ══════════════════════════════════════════════════════════
#  3. Xiaomei — #zhongwen 的主人
# ══════════════════════════════════════════════════════════
# 欢迎语走私密 notice：新来的人在频道里拿到指引，别人的记录不会被刷屏。
/bot create Xiaomei Zhongwen pindao de zhuren
/bot set Xiaomei prefix !
/bot set Xiaomei cooldown 1000
/bot set Xiaomei dice_default 1d20
/bot set Xiaomei greeting \c03\b[Xiaomei]\o 你好，{nickname}！我是 Xiaomei。\c02试试 !rooms\o、!zaoshanghao 或 !english。随意坐。
/bot set Xiaomei greeting_delivery private_notice
/bot set Xiaomei greeter_repeat_window 43200
/bot set Xiaomei public_greeting \c03\b[Xiaomei]\o \b{nickname}\o 刚进来。随便坐。
/bot set Xiaomei onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Xiaomei onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Xiaomei farewell none
/bot set Xiaomei mention_response \c03\b[Xiaomei]\o 叫我？在的。\c02试试 !rooms\o。

/bot addcmd Xiaomei rooms \c03\b[Xiaomei]\o #zhongwen #cn-tech #cn-digital #cn-apps #cn-blog #cn-dev #cn-open #cn-ai #cn-games #cn-money — \c02十个中文频道\o，每个里面都有东西在动。
/bot addcmd Xiaomei zaoshanghao \c03\b[Xiaomei]\o \c02早上好\o，{nickname}。咖啡冲好了，键盘擦干净了，一天开始。
/bot addcmd Xiaomei english \c03\b[Xiaomei]\o 也有英文频道，{nickname}：\c02#lobby、#tech、#news\o 等等。语言在工具栏切换。
/bot addcmd Xiaomei fanti \c03\b[Xiaomei]\o 繁体中文有自己的一套频道，{nickname}：\c02#fanti\o 那边。字不同，来源也不同，所以分开。

/bot join Xiaomei #zhongwen

# ══════════════════════════════════════════════════════════
#  4. 订阅机器人 —— 每个频道一个
# ══════════════════════════════════════════════════════════
# 下面每个地址都先用生产环境的 fetcher 抓过、用应用的解析器读过，才写进来。
# 第一次抓取会把收到的那一页发出来并记下；之后只发新的。
#
# 第一次读取分批发出，不是一次倒完：泛滥保护在每个读者自己的会话里，超了就
# 自动屏蔽。不丢东西 —— 还有积压的订阅源会在一分钟内回来取剩下的。

# ── Ahua — #zhongwen ─────────────────────────────────────
# 不打招呼：这个频道里迎客的是 Xiaomei。
/bot create Ahua Zhiban jizhe
/bot set Ahua prefix !
/bot set Ahua cooldown 1000
/bot set Ahua rss_interval 20
/bot set Ahua greeting none
/bot set Ahua farewell none
/bot set Ahua mention_response \c03\b[Ahua]\o 我读中新社、BBC 中文和纽约时报中文网。\c02!sources\o 列出订阅源。
/bot addcmd Ahua sources \c03\b[Ahua]\o 中新网、BBC 中文网和纽约时报中文网，\c02每二十分钟\o 抓一次。
/bot join Ahua #zhongwen
/bot rss add Ahua https://www.chinanews.com.cn/rss/scroll-news.xml #zhongwen
/bot rss add Ahua https://www.bbc.com/zhongwen/simp/index.xml #zhongwen
/bot rss add Ahua https://cn.nytimes.com/rss/ #zhongwen

# ── Lifeng — #cn-tech ────────────────────────────────────
/bot create Lifeng Keji tiaomu de bianji
/bot set Lifeng prefix !
/bot set Lifeng cooldown 1000
/bot set Lifeng rss_interval 30
/bot set Lifeng greeting \c12\b[Lifeng]\o 欢迎，{nickname}。\c10cnBeta、IT之家、Solidot\o 会自己落进来。!sources 看清单，!support 在提问之前看。
/bot set Lifeng greeting_delivery private_notice
/bot set Lifeng greeter_repeat_window 43200
/bot set Lifeng public_greeting \c12\b[Lifeng]\o \b{nickname}\o 来了，欢迎。
/bot set Lifeng onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Lifeng onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Lifeng farewell none
/bot set Lifeng mention_response \c12\b[Lifeng]\o 三个科技源在线上。\c10!sources\o 告诉你是哪几个。
/bot addcmd Lifeng sources \c12\b[Lifeng]\o cnBeta、IT之家和 Solidot，\c10每半小时\o 抓一次。
/bot addcmd Lifeng support \c12\b[Lifeng]\o 项目的支持在项目那边，{nickname} —— 答得好的是维护它的人。\c10这里是茶馆\o。
/bot join Lifeng #cn-tech
/bot rss add Lifeng https://www.cnbeta.com.tw/backend.php #cn-tech
/bot rss add Lifeng https://www.ithome.com/rss/ #cn-tech
/bot rss add Lifeng https://www.solidot.org/index.rss #cn-tech

# ── Xiaolong — #cn-digital ───────────────────────────────
/bot create Xiaolong Shuma chanpin guanchazhe
/bot set Xiaolong prefix !
/bot set Xiaolong cooldown 1000
/bot set Xiaolong rss_interval 45
/bot set Xiaolong greeting \c13\b[Xiaolong]\o 请进，{nickname}。\c11爱范儿和极客公园\o在线上。!sources 看清单。
/bot set Xiaolong greeting_delivery private_notice
/bot set Xiaolong greeter_repeat_window 43200
/bot set Xiaolong public_greeting \c13\b[Xiaolong]\o \b{nickname}\o 到了，欢迎。
/bot set Xiaolong onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Xiaolong onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Xiaolong farewell none
/bot set Xiaolong mention_response \c13\b[Xiaolong]\o 产品、评测和它们背后的生意。\c11!sources\o 列出来源。
/bot addcmd Xiaolong sources \c13\b[Xiaolong]\o 爱范儿和极客公园，\c11每四十五分钟\o 抓一次。
/bot join Xiaolong #cn-digital
/bot rss add Xiaolong https://www.ifanr.com/feed #cn-digital
/bot rss add Xiaolong https://www.geekpark.net/rss #cn-digital

# ── Meili — #cn-apps ─────────────────────────────────────
/bot create Meili Ruanjian tuijian bianji
/bot set Meili prefix !
/bot set Meili cooldown 1000
/bot set Meili rss_interval 60
/bot set Meili greeting \c06\b[Meili]\o 你好，{nickname}。\c13少数派和小众软件\o每小时送来一次。!sources 看清单。
/bot set Meili greeting_delivery private_notice
/bot set Meili greeter_repeat_window 43200
/bot set Meili public_greeting \c06\b[Meili]\o \b{nickname}\o 进来了，欢迎。
/bot set Meili onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Meili onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Meili farewell none
/bot set Meili mention_response \c06\b[Meili]\o 工具和玩法。\c13!sources\o 列出来源。
/bot addcmd Meili sources \c06\b[Meili]\o 少数派和小众软件，\c13每小时\o 抓一次。
/bot join Meili #cn-apps
/bot rss add Meili https://sspai.com/feed #cn-apps
/bot rss add Meili https://www.appinn.com/feed/ #cn-apps

# ── Laowang — #cn-blog ───────────────────────────────────
/bot create Laowang Duli boke de dujing ren
/bot set Laowang prefix !
/bot set Laowang cooldown 1000
/bot set Laowang rss_interval 120
/bot set Laowang greeting \c11\b[Laowang]\o 欢迎，{nickname}。\c14月光博客、阮一峰、酷壳\o 在线上 —— 更新不快，所以两小时抓一次。!sources。
/bot set Laowang greeting_delivery private_notice
/bot set Laowang greeter_repeat_window 43200
/bot set Laowang public_greeting \c11\b[Laowang]\o \b{nickname}\o 来了，坐。
/bot set Laowang onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Laowang onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Laowang farewell none
/bot set Laowang mention_response \c11\b[Laowang]\o 独立博客，写了十几年的那种。\c14!sources\o 列出来源。
/bot addcmd Laowang sources \c11\b[Laowang]\o 月光博客、阮一峰的网络日志和酷壳，\c14每两小时\o 抓一次 —— 一周几篇的节奏，敲门再勤也没用。
/bot join Laowang #cn-blog
/bot rss add Laowang https://www.williamlong.info/rss.xml #cn-blog
/bot rss add Laowang https://www.ruanyifeng.com/blog/atom.xml #cn-blog
/bot rss add Laowang https://coolshell.cn/feed #cn-blog

# ── Dabing — #cn-dev ─────────────────────────────────────
/bot create Dabing Kan bieren daima de ren
/bot set Dabing prefix !
/bot set Dabing cooldown 1000
/bot set Dabing rss_interval 45
/bot set Dabing greeting \c10\b[Dabing]\o 你好，{nickname}。\c02InfoQ 中文站\o在线上。!sources 看清单。
/bot set Dabing greeting_delivery private_notice
/bot set Dabing greeter_repeat_window 43200
/bot set Dabing public_greeting \c10\b[Dabing]\o \b{nickname}\o 加入了。
/bot set Dabing onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Dabing onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Dabing farewell none
/bot set Dabing mention_response \c10\b[Dabing]\o 我读 InfoQ 中文站。\c02!sources\o 看清单。
/bot addcmd Dabing sources \c10\b[Dabing]\o InfoQ 中文站，\c02每四十五分钟\o 抓一次。
/bot join Dabing #cn-dev
/bot rss add Dabing https://www.infoq.cn/feed #cn-dev

# ── Kaiyuan — #cn-open ───────────────────────────────────
/bot create Kaiyuan Fabu riji de kanshouren
/bot set Kaiyuan prefix !
/bot set Kaiyuan cooldown 1000
/bot set Kaiyuan rss_interval 45
/bot set Kaiyuan greeting \c03\b[Kaiyuan]\o 欢迎，{nickname}。\c09开源中国\o在线上 —— 发布、内核、发行版。!sources、!weishenme。
/bot set Kaiyuan greeting_delivery private_notice
/bot set Kaiyuan greeter_repeat_window 43200
/bot set Kaiyuan public_greeting \c03\b[Kaiyuan]\o \b{nickname}\o 来了，欢迎。
/bot set Kaiyuan onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Kaiyuan onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Kaiyuan farewell none
/bot set Kaiyuan mention_response \c03\b[Kaiyuan]\o 开源的消息由我搬运。\c09!sources\o 看清单。
/bot addcmd Kaiyuan sources \c03\b[Kaiyuan]\o 开源中国，\c09每四十五分钟\o 抓一次。
/bot addcmd Kaiyuan weishenme \c03\b[Kaiyuan]\o 一个项目的答疑值多少，取决于它的维护者，{nickname}，而他们不在这儿。\c09消息\o 不一样：中文这边本来没人搬。
/bot join Kaiyuan #cn-open
/bot rss add Kaiyuan https://www.oschina.net/news/rss #cn-open

# ── Zhineng — #cn-ai ─────────────────────────────────────
/bot create Zhineng Moxing fabu genzongzhe
/bot set Zhineng prefix !
/bot set Zhineng cooldown 1000
/bot set Zhineng rss_interval 60
/bot set Zhineng greeting \c10\b[Zhineng]\o {nickname}，欢迎。\c06雷锋网和量子位\o每小时送来一次。!sources 看清单。
/bot set Zhineng greeting_delivery private_notice
/bot set Zhineng greeter_repeat_window 43200
/bot set Zhineng public_greeting \c10\b[Zhineng]\o \b{nickname}\o 到了，欢迎。
/bot set Zhineng onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Zhineng onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Zhineng farewell none
/bot set Zhineng mention_response \c10\b[Zhineng]\o 模型、论文和落地。\c06!sources\o 列出来源。
/bot addcmd Zhineng sources \c10\b[Zhineng]\o 雷锋网和量子位，\c06每小时\o 抓一次。
/bot join Zhineng #cn-ai
/bot rss add Zhineng https://www.leiphone.com/feed #cn-ai
/bot rss add Zhineng https://www.qbitai.com/feed #cn-ai

# ── Youxi — #cn-games ────────────────────────────────────
/bot create Youxi Youxiting de kanchang
/bot set Youxi prefix !
/bot set Youxi cooldown 1000
/bot set Youxi rss_interval 60
/bot set Youxi greeting \c12\b[Youxi]\o 进来吧，{nickname}！\c10机核和游研社\o在线上，Games 菜单里有 18 款经典可以直接玩。!sources、!play。
/bot set Youxi greeting_delivery private_notice
/bot set Youxi greeter_repeat_window 43200
/bot set Youxi public_greeting \c12\b[Youxi]\o \b{nickname}\o 进入游戏。
/bot set Youxi onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Youxi onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Youxi farewell none
/bot set Youxi mention_response \c12\b[Youxi]\o 游戏的消息我来搬。\c10!play\o 说明怎么在这里直接玩。
/bot addcmd Youxi sources \c12\b[Youxi]\o 机核和游研社，\c10每小时\o 抓一次。
/bot addcmd Youxi play \c12\b[Youxi]\o 打开上面的 \c10Games\o 菜单，{nickname}：DOOM、Quake、Wolfenstein 和六个 ScummVM 冒险，全在浏览器里。
/bot join Youxi #cn-games
/bot rss add Youxi https://www.gcores.com/rss #cn-games
/bot rss add Youxi https://www.yystv.cn/rss/feed #cn-games

# ── Qianbao — #cn-money ──────────────────────────────────
/bot create Qianbao Shangye guanchazhe
/bot set Qianbao prefix !
/bot set Qianbao cooldown 1000
/bot set Qianbao rss_interval 45
/bot set Qianbao greeting \c07\b[Qianbao]\o 你好，{nickname}。\c14钛媒体\o在线上 —— !sources 看清单，!tixing 在相信之前看。
/bot set Qianbao greeting_delivery private_notice
/bot set Qianbao greeter_repeat_window 43200
/bot set Qianbao public_greeting \c07\b[Qianbao]\o \b{nickname}\o 进场了。
/bot set Qianbao onboarding_1 \c14\b[{botname}]\o \c10/join #zhongwen\o 进入房间 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改昵称。
/bot set Qianbao onboarding_2 \c14\b[{botname}]\o 每个房间是上方的一个标签页。\c10/part\o 离开，\c10/help\o 列出命令，\c10F1\o 打开手册。
/bot set Qianbao farewell none
/bot set Qianbao mention_response \c07\b[Qianbao]\o 我读钛媒体。\c14!sources\o 看清单。
/bot addcmd Qianbao sources \c07\b[Qianbao]\o 钛媒体，\c14每四十五分钟\o 抓一次。
/bot addcmd Qianbao tixing \c07\b[Qianbao]\o 标题不是建议，{nickname}。\c14我读的是订阅源\o，不是水晶球。
/bot join Qianbao #cn-money
/bot rss add Qianbao https://www.tmtpost.com/rss #cn-money
```

---

## Verification

```
/bot list
/bot info Weishi
/admin channel list
```

`!Ahua rss list` in `#zhongwen` shows what a bot actually stored — the check that
matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#zhongwen` | **Xiaomei**, Ahua | 中新网, BBC 中文网, 纽约时报中文网 |
| `#cn-tech` | **Lifeng** | cnBeta, IT之家, Solidot |
| `#cn-digital` | **Xiaolong** | 爱范儿, 极客公园 |
| `#cn-apps` | **Meili** | 少数派, 小众软件 |
| `#cn-blog` | **Laowang** | 月光博客, 阮一峰, 酷壳 |
| `#cn-dev` | **Dabing** | InfoQ 中文站 |
| `#cn-open` | **Kaiyuan** | 开源中国 |
| `#cn-ai` | **Zhineng** | 雷锋网, 量子位 |
| `#cn-games` | **Youxi** | 机核, 游研社 |
| `#cn-money` | **Qianbao** | 钛媒体 |

**Weishi** stands in all ten and greets in none of them. All channels are `+tn`.

`#cn-blog` polls every two hours on purpose: those writers publish a few posts a
week, and knocking every half hour costs both sides bandwidth for nothing.
