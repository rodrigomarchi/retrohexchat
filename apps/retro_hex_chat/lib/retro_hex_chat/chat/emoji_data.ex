defmodule RetroHexChat.Chat.EmojiData do
  @moduledoc """
  Static emoji data organized by category with search support.

  Provides ~300 curated Unicode emojis across 8 categories for the
  emoji picker component.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @type emoji :: %{char: String.t(), name: String.t(), keywords: [String.t()]}

  @categories [
    gettext_noop("Smileys & Emotion"),
    gettext_noop("People & Body"),
    gettext_noop("Animals & Nature"),
    gettext_noop("Food & Drink"),
    gettext_noop("Travel & Places"),
    gettext_noop("Activities"),
    gettext_noop("Objects"),
    gettext_noop("Symbols")
  ]

  @emojis %{
    gettext_noop("Smileys & Emotion") => [
      %{
        char: "\u{1F600}",
        name: gettext_noop("grinning face"),
        keywords: [gettext_noop("smile"), gettext_noop("happy"), gettext_noop("grin")]
      },
      %{
        char: "\u{1F601}",
        name: gettext_noop("beaming face with smiling eyes"),
        keywords: [gettext_noop("smile"), gettext_noop("happy"), gettext_noop("grin")]
      },
      %{
        char: "\u{1F602}",
        name: gettext_noop("face with tears of joy"),
        keywords: [gettext_noop("laugh"), gettext_noop("cry"), gettext_noop("lol")]
      },
      %{
        char: "\u{1F603}",
        name: gettext_noop("grinning face with big eyes"),
        keywords: [gettext_noop("smile"), gettext_noop("happy")]
      },
      %{
        char: "\u{1F604}",
        name: gettext_noop("grinning face with smiling eyes"),
        keywords: [gettext_noop("smile"), gettext_noop("happy")]
      },
      %{
        char: "\u{1F605}",
        name: gettext_noop("grinning face with sweat"),
        keywords: [gettext_noop("smile"), gettext_noop("nervous")]
      },
      %{
        char: "\u{1F606}",
        name: gettext_noop("grinning squinting face"),
        keywords: [gettext_noop("laugh"), gettext_noop("happy")]
      },
      %{
        char: "\u{1F609}",
        name: gettext_noop("winking face"),
        keywords: [gettext_noop("wink"), gettext_noop("flirt")]
      },
      %{
        char: "\u{1F60A}",
        name: gettext_noop("smiling face with smiling eyes"),
        keywords: [gettext_noop("blush"), gettext_noop("happy")]
      },
      %{
        char: "\u{1F60B}",
        name: gettext_noop("face savoring food"),
        keywords: [gettext_noop("yummy"), gettext_noop("delicious")]
      },
      %{
        char: "\u{1F60C}",
        name: gettext_noop("relieved face"),
        keywords: [gettext_noop("relieved"), gettext_noop("relaxed")]
      },
      %{
        char: "\u{1F60D}",
        name: gettext_noop("smiling face with heart-eyes"),
        keywords: [gettext_noop("love"), gettext_noop("heart")]
      },
      %{
        char: "\u{1F60E}",
        name: gettext_noop("smiling face with sunglasses"),
        keywords: [gettext_noop("cool"), gettext_noop("sunglasses")]
      },
      %{
        char: "\u{1F60F}",
        name: gettext_noop("smirking face"),
        keywords: [gettext_noop("smirk"), gettext_noop("sly")]
      },
      %{
        char: "\u{1F610}",
        name: gettext_noop("neutral face"),
        keywords: [gettext_noop("neutral"), gettext_noop("blank")]
      },
      %{
        char: "\u{1F612}",
        name: gettext_noop("unamused face"),
        keywords: [gettext_noop("unamused"), gettext_noop("annoyed")]
      },
      %{
        char: "\u{1F613}",
        name: gettext_noop("downcast face with sweat"),
        keywords: [gettext_noop("cold"), gettext_noop("sweat")]
      },
      %{
        char: "\u{1F614}",
        name: gettext_noop("pensive face"),
        keywords: [gettext_noop("sad"), gettext_noop("pensive")]
      },
      %{
        char: "\u{1F616}",
        name: gettext_noop("confounded face"),
        keywords: [gettext_noop("confused"), gettext_noop("frustrated")]
      },
      %{
        char: "\u{1F618}",
        name: gettext_noop("face blowing a kiss"),
        keywords: [gettext_noop("kiss"), gettext_noop("love")]
      },
      %{
        char: "\u{1F61A}",
        name: gettext_noop("kissing face with closed eyes"),
        keywords: [gettext_noop("kiss"), gettext_noop("love")]
      },
      %{
        char: "\u{1F61C}",
        name: gettext_noop("winking face with tongue"),
        keywords: [gettext_noop("tongue"), gettext_noop("silly")]
      },
      %{
        char: "\u{1F61D}",
        name: gettext_noop("squinting face with tongue"),
        keywords: [gettext_noop("tongue"), gettext_noop("silly")]
      },
      %{
        char: "\u{1F61E}",
        name: gettext_noop("disappointed face"),
        keywords: [gettext_noop("sad"), gettext_noop("disappointed")]
      },
      %{
        char: "\u{1F620}",
        name: gettext_noop("angry face"),
        keywords: [gettext_noop("angry"), gettext_noop("mad")]
      },
      %{
        char: "\u{1F621}",
        name: gettext_noop("pouting face"),
        keywords: [gettext_noop("angry"), gettext_noop("rage")]
      },
      %{
        char: "\u{1F622}",
        name: gettext_noop("crying face"),
        keywords: [gettext_noop("cry"), gettext_noop("sad"), gettext_noop("tear")]
      },
      %{
        char: "\u{1F623}",
        name: gettext_noop("persevering face"),
        keywords: [gettext_noop("struggle"), gettext_noop("frustrated")]
      },
      %{
        char: "\u{1F624}",
        name: gettext_noop("face with steam from nose"),
        keywords: [gettext_noop("triumph"), gettext_noop("proud")]
      },
      %{
        char: "\u{1F625}",
        name: gettext_noop("sad but relieved face"),
        keywords: [gettext_noop("sad"), gettext_noop("relieved")]
      },
      %{
        char: "\u{1F628}",
        name: gettext_noop("fearful face"),
        keywords: [gettext_noop("fear"), gettext_noop("scared")]
      },
      %{
        char: "\u{1F629}",
        name: gettext_noop("weary face"),
        keywords: [gettext_noop("weary"), gettext_noop("tired")]
      },
      %{
        char: "\u{1F62B}",
        name: gettext_noop("tired face"),
        keywords: [gettext_noop("tired"), gettext_noop("exhausted")]
      },
      %{
        char: "\u{1F62D}",
        name: gettext_noop("loudly crying face"),
        keywords: [gettext_noop("cry"), gettext_noop("sob"), gettext_noop("sad")]
      },
      %{
        char: "\u{1F631}",
        name: gettext_noop("face screaming in fear"),
        keywords: [gettext_noop("scream"), gettext_noop("horror")]
      },
      %{
        char: "\u{1F633}",
        name: gettext_noop("flushed face"),
        keywords: [gettext_noop("blush"), gettext_noop("embarrassed")]
      },
      %{
        char: "\u{1F634}",
        name: gettext_noop("sleeping face"),
        keywords: [gettext_noop("sleep"), gettext_noop("zzz")]
      },
      %{
        char: "\u{1F635}",
        name: gettext_noop("face with crossed-out eyes"),
        keywords: [gettext_noop("dizzy"), gettext_noop("dead")]
      },
      %{
        char: "\u{1F637}",
        name: gettext_noop("face with medical mask"),
        keywords: [gettext_noop("sick"), gettext_noop("mask")]
      },
      %{
        char: "\u{1F642}",
        name: gettext_noop("slightly smiling face"),
        keywords: [gettext_noop("smile"), gettext_noop("happy")]
      },
      %{
        char: "\u{1F643}",
        name: gettext_noop("upside-down face"),
        keywords: [gettext_noop("silly"), gettext_noop("sarcasm")]
      },
      %{
        char: "\u{1F644}",
        name: gettext_noop("face with rolling eyes"),
        keywords: [gettext_noop("eyeroll"), gettext_noop("annoyed")]
      },
      %{
        char: "\u{1F910}",
        name: gettext_noop("zipper-mouth face"),
        keywords: [gettext_noop("quiet"), gettext_noop("secret")]
      },
      %{
        char: "\u{1F911}",
        name: gettext_noop("money-mouth face"),
        keywords: [gettext_noop("money"), gettext_noop("rich")]
      },
      %{
        char: "\u{1F913}",
        name: gettext_noop("nerd face"),
        keywords: [gettext_noop("nerd"), gettext_noop("geek")]
      },
      %{
        char: "\u{1F914}",
        name: gettext_noop("thinking face"),
        keywords: [gettext_noop("think"), gettext_noop("hmm")]
      },
      %{
        char: "\u{1F917}",
        name: gettext_noop("hugging face"),
        keywords: [gettext_noop("hug"), gettext_noop("love")]
      },
      %{
        char: "\u{1F923}",
        name: gettext_noop("rolling on the floor laughing"),
        keywords: [gettext_noop("laugh"), gettext_noop("rofl")]
      },
      %{
        char: "\u{1F92A}",
        name: gettext_noop("zany face"),
        keywords: [gettext_noop("crazy"), gettext_noop("wild")]
      },
      %{
        char: "\u{1F92B}",
        name: gettext_noop("shushing face"),
        keywords: [gettext_noop("quiet"), gettext_noop("shh")]
      },
      %{
        char: "\u{1F92D}",
        name: gettext_noop("face with hand over mouth"),
        keywords: [gettext_noop("oops"), gettext_noop("giggle")]
      },
      %{
        char: "\u{1F92E}",
        name: gettext_noop("face vomiting"),
        keywords: [gettext_noop("sick"), gettext_noop("puke")]
      },
      %{
        char: "\u{1F970}",
        name: gettext_noop("smiling face with hearts"),
        keywords: [gettext_noop("love"), gettext_noop("adore")]
      },
      %{
        char: "\u{1F973}",
        name: gettext_noop("partying face"),
        keywords: [gettext_noop("party"), gettext_noop("celebrate")]
      },
      %{
        char: "\u{1F974}",
        name: gettext_noop("woozy face"),
        keywords: [gettext_noop("drunk"), gettext_noop("dizzy")]
      },
      %{
        char: "\u{1F975}",
        name: gettext_noop("hot face"),
        keywords: [gettext_noop("hot"), gettext_noop("heat")]
      },
      %{
        char: "\u{1F976}",
        name: gettext_noop("cold face"),
        keywords: [gettext_noop("cold"), gettext_noop("freezing")]
      },
      %{
        char: "\u{2764}\u{FE0F}",
        name: gettext_noop("red heart"),
        keywords: [gettext_noop("love"), gettext_noop("heart")]
      },
      %{
        char: "\u{1F494}",
        name: gettext_noop("broken heart"),
        keywords: [gettext_noop("heartbreak"), gettext_noop("sad")]
      },
      %{
        char: "\u{1F495}",
        name: gettext_noop("two hearts"),
        keywords: [gettext_noop("love"), gettext_noop("hearts")]
      },
      %{
        char: "\u{1F496}",
        name: gettext_noop("sparkling heart"),
        keywords: [gettext_noop("love"), gettext_noop("sparkle")]
      },
      %{
        char: "\u{1F497}",
        name: gettext_noop("growing heart"),
        keywords: [gettext_noop("love"), gettext_noop("growing")]
      },
      %{
        char: "\u{1F498}",
        name: gettext_noop("heart with arrow"),
        keywords: [gettext_noop("love"), gettext_noop("cupid")]
      },
      %{
        char: "\u{1F499}",
        name: gettext_noop("blue heart"),
        keywords: [gettext_noop("love"), gettext_noop("blue")]
      },
      %{
        char: "\u{1F49A}",
        name: gettext_noop("green heart"),
        keywords: [gettext_noop("love"), gettext_noop("green")]
      },
      %{
        char: "\u{1F49B}",
        name: gettext_noop("yellow heart"),
        keywords: [gettext_noop("love"), gettext_noop("yellow")]
      },
      %{
        char: "\u{1F49C}",
        name: gettext_noop("purple heart"),
        keywords: [gettext_noop("love"), gettext_noop("purple")]
      },
      %{
        char: "\u{1F4AF}",
        name: gettext_noop("hundred points"),
        keywords: [gettext_noop("100"), gettext_noop("perfect"), gettext_noop("score")]
      }
    ],
    gettext_noop("People & Body") => [
      %{
        char: "\u{1F44D}",
        name: gettext_noop("thumbs up"),
        keywords: [gettext_noop("yes"), gettext_noop("good"), gettext_noop("like")]
      },
      %{
        char: "\u{1F44E}",
        name: gettext_noop("thumbs down"),
        keywords: [gettext_noop("no"), gettext_noop("bad"), gettext_noop("dislike")]
      },
      %{
        char: "\u{1F44B}",
        name: gettext_noop("waving hand"),
        keywords: [gettext_noop("wave"), gettext_noop("hello"), gettext_noop("bye")]
      },
      %{
        char: "\u{1F44F}",
        name: gettext_noop("clapping hands"),
        keywords: [gettext_noop("clap"), gettext_noop("applause")]
      },
      %{
        char: "\u{1F450}",
        name: gettext_noop("open hands"),
        keywords: [gettext_noop("hands"), gettext_noop("open")]
      },
      %{
        char: "\u{1F64C}",
        name: gettext_noop("raising hands"),
        keywords: [gettext_noop("celebrate"), gettext_noop("hooray")]
      },
      %{
        char: "\u{1F64F}",
        name: gettext_noop("folded hands"),
        keywords: [gettext_noop("pray"), gettext_noop("please"), gettext_noop("thanks")]
      },
      %{
        char: "\u{1F91D}",
        name: gettext_noop("handshake"),
        keywords: [gettext_noop("agreement"), gettext_noop("deal")]
      },
      %{
        char: "\u{270C}\u{FE0F}",
        name: gettext_noop("victory hand"),
        keywords: [gettext_noop("peace"), gettext_noop("victory")]
      },
      %{
        char: "\u{1F918}",
        name: gettext_noop("sign of the horns"),
        keywords: [gettext_noop("rock"), gettext_noop("metal")]
      },
      %{
        char: "\u{1F919}",
        name: gettext_noop("call me hand"),
        keywords: [gettext_noop("call"), gettext_noop("shaka")]
      },
      %{
        char: "\u{1F91E}",
        name: gettext_noop("crossed fingers"),
        keywords: [gettext_noop("luck"), gettext_noop("hope")]
      },
      %{
        char: "\u{1F91F}",
        name: gettext_noop("love-you gesture"),
        keywords: [gettext_noop("love"), gettext_noop("ily")]
      },
      %{
        char: "\u{1F448}",
        name: gettext_noop("backhand index pointing left"),
        keywords: [gettext_noop("left"), gettext_noop("point")]
      },
      %{
        char: "\u{1F449}",
        name: gettext_noop("backhand index pointing right"),
        keywords: [gettext_noop("right"), gettext_noop("point")]
      },
      %{
        char: "\u{1F446}",
        name: gettext_noop("backhand index pointing up"),
        keywords: [gettext_noop("up"), gettext_noop("point")]
      },
      %{
        char: "\u{1F447}",
        name: gettext_noop("backhand index pointing down"),
        keywords: [gettext_noop("down"), gettext_noop("point")]
      },
      %{
        char: "\u{261D}\u{FE0F}",
        name: gettext_noop("index pointing up"),
        keywords: [gettext_noop("point"), gettext_noop("one")]
      },
      %{
        char: "\u{270B}",
        name: gettext_noop("raised hand"),
        keywords: [gettext_noop("stop"), gettext_noop("high five")]
      },
      %{
        char: "\u{1F44A}",
        name: gettext_noop("oncoming fist"),
        keywords: [gettext_noop("punch"), gettext_noop("fist bump")]
      },
      %{
        char: "\u{1F4AA}",
        name: gettext_noop("flexed biceps"),
        keywords: [gettext_noop("strong"), gettext_noop("muscle")]
      },
      %{
        char: "\u{1F596}",
        name: gettext_noop("vulcan salute"),
        keywords: [gettext_noop("spock"), gettext_noop("trek")]
      },
      %{
        char: "\u{1F590}\u{FE0F}",
        name: gettext_noop("hand with fingers splayed"),
        keywords: [gettext_noop("hand"), gettext_noop("five")]
      },
      %{
        char: "\u{1F937}",
        name: gettext_noop("person shrugging"),
        keywords: [gettext_noop("shrug"), gettext_noop("dunno")]
      },
      %{
        char: "\u{1F926}",
        name: gettext_noop("person facepalming"),
        keywords: [gettext_noop("facepalm"), gettext_noop("smh")]
      },
      %{
        char: "\u{1F645}",
        name: gettext_noop("person gesturing NO"),
        keywords: [gettext_noop("no"), gettext_noop("stop")]
      },
      %{
        char: "\u{1F646}",
        name: gettext_noop("person gesturing OK"),
        keywords: [gettext_noop("ok"), gettext_noop("yes")]
      },
      %{
        char: "\u{1F647}",
        name: gettext_noop("person bowing"),
        keywords: [gettext_noop("bow"), gettext_noop("respect")]
      },
      %{
        char: "\u{1F471}",
        name: gettext_noop("person: blond hair"),
        keywords: [gettext_noop("blonde"), gettext_noop("person")]
      },
      %{
        char: "\u{1F474}",
        name: gettext_noop("old man"),
        keywords: [gettext_noop("elder"), gettext_noop("grandpa")]
      },
      %{
        char: "\u{1F475}",
        name: gettext_noop("old woman"),
        keywords: [gettext_noop("elder"), gettext_noop("grandma")]
      },
      %{
        char: "\u{1F476}",
        name: gettext_noop("baby"),
        keywords: [gettext_noop("baby"), gettext_noop("infant")]
      },
      %{
        char: "\u{1F466}",
        name: gettext_noop("boy"),
        keywords: [gettext_noop("boy"), gettext_noop("child")]
      },
      %{
        char: "\u{1F467}",
        name: gettext_noop("girl"),
        keywords: [gettext_noop("girl"), gettext_noop("child")]
      },
      %{
        char: "\u{1F468}",
        name: gettext_noop("man"),
        keywords: [gettext_noop("man"), gettext_noop("adult")]
      },
      %{
        char: "\u{1F469}",
        name: gettext_noop("woman"),
        keywords: [gettext_noop("woman"), gettext_noop("adult")]
      }
    ],
    gettext_noop("Animals & Nature") => [
      %{
        char: "\u{1F436}",
        name: gettext_noop("dog face"),
        keywords: [gettext_noop("dog"), gettext_noop("pet"), gettext_noop("puppy")]
      },
      %{
        char: "\u{1F431}",
        name: gettext_noop("cat face"),
        keywords: [gettext_noop("cat"), gettext_noop("pet"), gettext_noop("kitty")]
      },
      %{
        char: "\u{1F42D}",
        name: gettext_noop("mouse face"),
        keywords: [gettext_noop("mouse"), gettext_noop("rodent")]
      },
      %{
        char: "\u{1F439}",
        name: gettext_noop("hamster"),
        keywords: [gettext_noop("hamster"), gettext_noop("pet")]
      },
      %{
        char: "\u{1F430}",
        name: gettext_noop("rabbit face"),
        keywords: [gettext_noop("rabbit"), gettext_noop("bunny")]
      },
      %{
        char: "\u{1F43B}",
        name: gettext_noop("bear"),
        keywords: [gettext_noop("bear"), gettext_noop("animal")]
      },
      %{
        char: "\u{1F43C}",
        name: gettext_noop("panda"),
        keywords: [gettext_noop("panda"), gettext_noop("bear")]
      },
      %{
        char: "\u{1F428}",
        name: gettext_noop("koala"),
        keywords: [gettext_noop("koala"), gettext_noop("animal")]
      },
      %{
        char: "\u{1F42F}",
        name: gettext_noop("tiger face"),
        keywords: [gettext_noop("tiger"), gettext_noop("cat")]
      },
      %{
        char: "\u{1F981}",
        name: gettext_noop("lion"),
        keywords: [gettext_noop("lion"), gettext_noop("king")]
      },
      %{
        char: "\u{1F42E}",
        name: gettext_noop("cow face"),
        keywords: [gettext_noop("cow"), gettext_noop("moo")]
      },
      %{
        char: "\u{1F437}",
        name: gettext_noop("pig face"),
        keywords: [gettext_noop("pig"), gettext_noop("oink")]
      },
      %{
        char: "\u{1F438}",
        name: gettext_noop("frog"),
        keywords: [gettext_noop("frog"), gettext_noop("toad")]
      },
      %{
        char: "\u{1F435}",
        name: gettext_noop("monkey face"),
        keywords: [gettext_noop("monkey"), gettext_noop("ape")]
      },
      %{
        char: "\u{1F412}",
        name: gettext_noop("monkey"),
        keywords: [gettext_noop("monkey"), gettext_noop("primate")]
      },
      %{
        char: "\u{1F414}",
        name: gettext_noop("chicken"),
        keywords: [gettext_noop("chicken"), gettext_noop("hen")]
      },
      %{
        char: "\u{1F427}",
        name: gettext_noop("penguin"),
        keywords: [gettext_noop("penguin"), gettext_noop("cold")]
      },
      %{
        char: "\u{1F426}",
        name: gettext_noop("bird"),
        keywords: [gettext_noop("bird"), gettext_noop("fly")]
      },
      %{
        char: "\u{1F40D}",
        name: gettext_noop("snake"),
        keywords: [gettext_noop("snake"), gettext_noop("reptile")]
      },
      %{
        char: "\u{1F422}",
        name: gettext_noop("turtle"),
        keywords: [gettext_noop("turtle"), gettext_noop("slow")]
      },
      %{
        char: "\u{1F41D}",
        name: gettext_noop("honeybee"),
        keywords: [gettext_noop("bee"), gettext_noop("honey")]
      },
      %{
        char: "\u{1F41B}",
        name: gettext_noop("bug"),
        keywords: [gettext_noop("bug"), gettext_noop("insect")]
      },
      %{
        char: "\u{1F40C}",
        name: gettext_noop("snail"),
        keywords: [gettext_noop("snail"), gettext_noop("slow")]
      },
      %{
        char: "\u{1F419}",
        name: gettext_noop("octopus"),
        keywords: [gettext_noop("octopus"), gettext_noop("sea")]
      },
      %{
        char: "\u{1F420}",
        name: gettext_noop("tropical fish"),
        keywords: [gettext_noop("fish"), gettext_noop("tropical")]
      },
      %{
        char: "\u{1F421}",
        name: gettext_noop("blowfish"),
        keywords: [gettext_noop("fish"), gettext_noop("puffer")]
      },
      %{
        char: "\u{1F42C}",
        name: gettext_noop("dolphin"),
        keywords: [gettext_noop("dolphin"), gettext_noop("sea")]
      },
      %{
        char: "\u{1F433}",
        name: gettext_noop("whale"),
        keywords: [gettext_noop("whale"), gettext_noop("sea")]
      },
      %{
        char: "\u{1F332}",
        name: gettext_noop("evergreen tree"),
        keywords: [gettext_noop("tree"), gettext_noop("nature")]
      },
      %{
        char: "\u{1F333}",
        name: gettext_noop("deciduous tree"),
        keywords: [gettext_noop("tree"), gettext_noop("nature")]
      },
      %{
        char: "\u{1F334}",
        name: gettext_noop("palm tree"),
        keywords: [gettext_noop("palm"), gettext_noop("tropical")]
      },
      %{
        char: "\u{1F335}",
        name: gettext_noop("cactus"),
        keywords: [gettext_noop("cactus"), gettext_noop("desert")]
      },
      %{
        char: "\u{1F337}",
        name: gettext_noop("tulip"),
        keywords: [gettext_noop("flower"), gettext_noop("spring")]
      },
      %{
        char: "\u{1F339}",
        name: gettext_noop("rose"),
        keywords: [gettext_noop("flower"), gettext_noop("love")]
      },
      %{
        char: "\u{1F33B}",
        name: gettext_noop("sunflower"),
        keywords: [gettext_noop("flower"), gettext_noop("sun")]
      },
      %{
        char: "\u{1F33C}",
        name: gettext_noop("blossom"),
        keywords: [gettext_noop("flower"), gettext_noop("bloom")]
      },
      %{
        char: "\u{1F33F}",
        name: gettext_noop("herb"),
        keywords: [gettext_noop("herb"), gettext_noop("plant")]
      },
      %{
        char: "\u{2B50}",
        name: gettext_noop("star"),
        keywords: [gettext_noop("star"), gettext_noop("gold")]
      },
      %{
        char: "\u{2600}\u{FE0F}",
        name: gettext_noop("sun"),
        keywords: [gettext_noop("sun"), gettext_noop("bright")]
      },
      %{
        char: "\u{1F319}",
        name: gettext_noop("crescent moon"),
        keywords: [gettext_noop("moon"), gettext_noop("night")]
      },
      %{
        char: "\u{26A1}",
        name: gettext_noop("high voltage"),
        keywords: [gettext_noop("lightning"), gettext_noop("zap")]
      },
      %{
        char: "\u{1F525}",
        name: gettext_noop("fire"),
        keywords: [gettext_noop("fire"), gettext_noop("hot"), gettext_noop("lit")]
      },
      %{
        char: "\u{1F4A7}",
        name: gettext_noop("droplet"),
        keywords: [gettext_noop("water"), gettext_noop("drop")]
      },
      %{
        char: "\u{2744}\u{FE0F}",
        name: gettext_noop("snowflake"),
        keywords: [gettext_noop("snow"), gettext_noop("cold"), gettext_noop("winter")]
      },
      %{
        char: "\u{1F308}",
        name: gettext_noop("rainbow"),
        keywords: [gettext_noop("rainbow"), gettext_noop("colorful")]
      }
    ],
    gettext_noop("Food & Drink") => [
      %{
        char: "\u{1F34E}",
        name: gettext_noop("red apple"),
        keywords: [gettext_noop("apple"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F34F}",
        name: gettext_noop("green apple"),
        keywords: [gettext_noop("apple"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F34A}",
        name: gettext_noop("tangerine"),
        keywords: [gettext_noop("orange"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F34B}",
        name: gettext_noop("lemon"),
        keywords: [gettext_noop("lemon"), gettext_noop("citrus")]
      },
      %{
        char: "\u{1F34C}",
        name: gettext_noop("banana"),
        keywords: [gettext_noop("banana"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F34D}",
        name: gettext_noop("pineapple"),
        keywords: [gettext_noop("pineapple"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F347}",
        name: gettext_noop("grapes"),
        keywords: [gettext_noop("grape"), gettext_noop("wine")]
      },
      %{
        char: "\u{1F348}",
        name: gettext_noop("melon"),
        keywords: [gettext_noop("melon"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F349}",
        name: gettext_noop("watermelon"),
        keywords: [gettext_noop("watermelon"), gettext_noop("summer")]
      },
      %{
        char: "\u{1F353}",
        name: gettext_noop("strawberry"),
        keywords: [gettext_noop("strawberry"), gettext_noop("berry")]
      },
      %{
        char: "\u{1F352}",
        name: gettext_noop("cherries"),
        keywords: [gettext_noop("cherry"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F351}",
        name: gettext_noop("peach"),
        keywords: [gettext_noop("peach"), gettext_noop("fruit")]
      },
      %{
        char: "\u{1F354}",
        name: gettext_noop("hamburger"),
        keywords: [gettext_noop("burger"), gettext_noop("food")]
      },
      %{
        char: "\u{1F355}",
        name: gettext_noop("pizza"),
        keywords: [gettext_noop("pizza"), gettext_noop("food")]
      },
      %{
        char: "\u{1F35F}",
        name: gettext_noop("french fries"),
        keywords: [gettext_noop("fries"), gettext_noop("food")]
      },
      %{
        char: "\u{1F32D}",
        name: gettext_noop("hot dog"),
        keywords: [gettext_noop("hotdog"), gettext_noop("food")]
      },
      %{
        char: "\u{1F32E}",
        name: gettext_noop("taco"),
        keywords: [gettext_noop("taco"), gettext_noop("food")]
      },
      %{
        char: "\u{1F32F}",
        name: gettext_noop("burrito"),
        keywords: [gettext_noop("burrito"), gettext_noop("food")]
      },
      %{
        char: "\u{1F363}",
        name: gettext_noop("sushi"),
        keywords: [gettext_noop("sushi"), gettext_noop("japanese")]
      },
      %{
        char: "\u{1F359}",
        name: gettext_noop("rice ball"),
        keywords: [gettext_noop("rice"), gettext_noop("japanese")]
      },
      %{
        char: "\u{1F35C}",
        name: gettext_noop("steaming bowl"),
        keywords: [gettext_noop("noodles"), gettext_noop("ramen")]
      },
      %{
        char: "\u{1F370}",
        name: gettext_noop("shortcake"),
        keywords: [gettext_noop("cake"), gettext_noop("dessert")]
      },
      %{
        char: "\u{1F36A}",
        name: gettext_noop("cookie"),
        keywords: [gettext_noop("cookie"), gettext_noop("sweet")]
      },
      %{
        char: "\u{1F36B}",
        name: gettext_noop("chocolate bar"),
        keywords: [gettext_noop("chocolate"), gettext_noop("sweet")]
      },
      %{
        char: "\u{1F36C}",
        name: gettext_noop("candy"),
        keywords: [gettext_noop("candy"), gettext_noop("sweet")]
      },
      %{
        char: "\u{1F36D}",
        name: gettext_noop("lollipop"),
        keywords: [gettext_noop("lollipop"), gettext_noop("sweet")]
      },
      %{
        char: "\u{1F36E}",
        name: gettext_noop("custard"),
        keywords: [gettext_noop("pudding"), gettext_noop("dessert")]
      },
      %{
        char: "\u{1F36F}",
        name: gettext_noop("honey pot"),
        keywords: [gettext_noop("honey"), gettext_noop("sweet")]
      },
      %{
        char: "\u{2615}",
        name: gettext_noop("hot beverage"),
        keywords: [gettext_noop("coffee"), gettext_noop("tea")]
      },
      %{
        char: "\u{1F37A}",
        name: gettext_noop("beer mug"),
        keywords: [gettext_noop("beer"), gettext_noop("drink")]
      },
      %{
        char: "\u{1F37B}",
        name: gettext_noop("clinking beer mugs"),
        keywords: [gettext_noop("beer"), gettext_noop("cheers")]
      },
      %{
        char: "\u{1F377}",
        name: gettext_noop("wine glass"),
        keywords: [gettext_noop("wine"), gettext_noop("drink")]
      },
      %{
        char: "\u{1F378}",
        name: gettext_noop("cocktail glass"),
        keywords: [gettext_noop("cocktail"), gettext_noop("drink")]
      },
      %{
        char: "\u{1F379}",
        name: gettext_noop("tropical drink"),
        keywords: [gettext_noop("drink"), gettext_noop("tropical")]
      },
      %{
        char: "\u{1F37D}\u{FE0F}",
        name: gettext_noop("fork and knife with plate"),
        keywords: [gettext_noop("food"), gettext_noop("dining")]
      }
    ],
    gettext_noop("Travel & Places") => [
      %{
        char: "\u{1F697}",
        name: gettext_noop("automobile"),
        keywords: [gettext_noop("car"), gettext_noop("drive")]
      },
      %{
        char: "\u{1F695}",
        name: gettext_noop("taxi"),
        keywords: [gettext_noop("taxi"), gettext_noop("cab")]
      },
      %{
        char: "\u{1F68C}",
        name: gettext_noop("bus"),
        keywords: [gettext_noop("bus"), gettext_noop("transit")]
      },
      %{
        char: "\u{1F693}",
        name: gettext_noop("police car"),
        keywords: [gettext_noop("police"), gettext_noop("cop")]
      },
      %{
        char: "\u{1F691}",
        name: gettext_noop("ambulance"),
        keywords: [gettext_noop("ambulance"), gettext_noop("emergency")]
      },
      %{
        char: "\u{1F692}",
        name: gettext_noop("fire engine"),
        keywords: [gettext_noop("fire"), gettext_noop("truck")]
      },
      %{
        char: "\u{1F6B2}",
        name: gettext_noop("bicycle"),
        keywords: [gettext_noop("bike"), gettext_noop("cycling")]
      },
      %{
        char: "\u{2708}\u{FE0F}",
        name: gettext_noop("airplane"),
        keywords: [gettext_noop("plane"), gettext_noop("fly"), gettext_noop("travel")]
      },
      %{
        char: "\u{1F680}",
        name: gettext_noop("rocket"),
        keywords: [gettext_noop("rocket"), gettext_noop("space")]
      },
      %{
        char: "\u{1F6F8}",
        name: gettext_noop("flying saucer"),
        keywords: [gettext_noop("ufo"), gettext_noop("alien")]
      },
      %{
        char: "\u{1F6A2}",
        name: gettext_noop("ship"),
        keywords: [gettext_noop("ship"), gettext_noop("boat")]
      },
      %{
        char: "\u{26F5}",
        name: gettext_noop("sailboat"),
        keywords: [gettext_noop("sail"), gettext_noop("boat")]
      },
      %{
        char: "\u{1F3E0}",
        name: gettext_noop("house"),
        keywords: [gettext_noop("home"), gettext_noop("house")]
      },
      %{
        char: "\u{1F3E2}",
        name: gettext_noop("office building"),
        keywords: [gettext_noop("office"), gettext_noop("work")]
      },
      %{
        char: "\u{1F3E5}",
        name: gettext_noop("hospital"),
        keywords: [gettext_noop("hospital"), gettext_noop("medical")]
      },
      %{
        char: "\u{1F3EB}",
        name: gettext_noop("school"),
        keywords: [gettext_noop("school"), gettext_noop("education")]
      },
      %{
        char: "\u{1F3ED}",
        name: gettext_noop("factory"),
        keywords: [gettext_noop("factory"), gettext_noop("industry")]
      },
      %{
        char: "\u{1F3F0}",
        name: gettext_noop("castle"),
        keywords: [gettext_noop("castle"), gettext_noop("kingdom")]
      },
      %{
        char: "\u{26EA}",
        name: gettext_noop("church"),
        keywords: [gettext_noop("church"), gettext_noop("religion")]
      },
      %{
        char: "\u{1F5FC}",
        name: gettext_noop("Tokyo Tower"),
        keywords: [gettext_noop("tower"), gettext_noop("japan")]
      },
      %{
        char: "\u{1F5FD}",
        name: gettext_noop("Statue of Liberty"),
        keywords: [gettext_noop("liberty"), gettext_noop("usa")]
      },
      %{
        char: "\u{1F30D}",
        name: gettext_noop("globe showing Europe-Africa"),
        keywords: [gettext_noop("earth"), gettext_noop("world")]
      },
      %{
        char: "\u{1F30E}",
        name: gettext_noop("globe showing Americas"),
        keywords: [gettext_noop("earth"), gettext_noop("world")]
      },
      %{
        char: "\u{1F30F}",
        name: gettext_noop("globe showing Asia-Australia"),
        keywords: [gettext_noop("earth"), gettext_noop("world")]
      },
      %{
        char: "\u{1F3D4}\u{FE0F}",
        name: gettext_noop("snow-capped mountain"),
        keywords: [gettext_noop("mountain"), gettext_noop("snow")]
      },
      %{
        char: "\u{1F3D6}\u{FE0F}",
        name: gettext_noop("beach with umbrella"),
        keywords: [gettext_noop("beach"), gettext_noop("vacation")]
      },
      %{
        char: "\u{1F3DD}\u{FE0F}",
        name: gettext_noop("desert island"),
        keywords: [gettext_noop("island"), gettext_noop("tropical")]
      }
    ],
    gettext_noop("Activities") => [
      %{
        char: "\u{26BD}",
        name: gettext_noop("soccer ball"),
        keywords: [gettext_noop("soccer"), gettext_noop("football")]
      },
      %{
        char: "\u{1F3C0}",
        name: gettext_noop("basketball"),
        keywords: [gettext_noop("basketball"), gettext_noop("sport")]
      },
      %{
        char: "\u{1F3C8}",
        name: gettext_noop("american football"),
        keywords: [gettext_noop("football"), gettext_noop("nfl")]
      },
      %{
        char: "\u{26BE}",
        name: gettext_noop("baseball"),
        keywords: [gettext_noop("baseball"), gettext_noop("sport")]
      },
      %{
        char: "\u{1F3BE}",
        name: gettext_noop("tennis"),
        keywords: [gettext_noop("tennis"), gettext_noop("sport")]
      },
      %{
        char: "\u{1F3D0}",
        name: gettext_noop("volleyball"),
        keywords: [gettext_noop("volleyball"), gettext_noop("sport")]
      },
      %{
        char: "\u{1F3B1}",
        name: gettext_noop("pool 8 ball"),
        keywords: [gettext_noop("billiards"), gettext_noop("pool")]
      },
      %{
        char: "\u{1F3D3}",
        name: gettext_noop("ping pong"),
        keywords: [gettext_noop("table tennis"), gettext_noop("sport")]
      },
      %{
        char: "\u{1F3C6}",
        name: gettext_noop("trophy"),
        keywords: [gettext_noop("trophy"), gettext_noop("winner"), gettext_noop("award")]
      },
      %{
        char: "\u{1F3C5}",
        name: gettext_noop("sports medal"),
        keywords: [gettext_noop("medal"), gettext_noop("award")]
      },
      %{
        char: "\u{1F947}",
        name: gettext_noop("1st place medal"),
        keywords: [gettext_noop("gold"), gettext_noop("first")]
      },
      %{
        char: "\u{1F948}",
        name: gettext_noop("2nd place medal"),
        keywords: [gettext_noop("silver"), gettext_noop("second")]
      },
      %{
        char: "\u{1F949}",
        name: gettext_noop("3rd place medal"),
        keywords: [gettext_noop("bronze"), gettext_noop("third")]
      },
      %{
        char: "\u{1F3AE}",
        name: gettext_noop("video game"),
        keywords: [gettext_noop("game"), gettext_noop("controller")]
      },
      %{
        char: "\u{1F3AF}",
        name: gettext_noop("bullseye"),
        keywords: [gettext_noop("target"), gettext_noop("dart")]
      },
      %{
        char: "\u{1F3B0}",
        name: gettext_noop("slot machine"),
        keywords: [gettext_noop("casino"), gettext_noop("gamble")]
      },
      %{
        char: "\u{1F3B2}",
        name: gettext_noop("game die"),
        keywords: [gettext_noop("dice"), gettext_noop("game")]
      },
      %{
        char: "\u{265F}\u{FE0F}",
        name: gettext_noop("chess pawn"),
        keywords: [gettext_noop("chess"), gettext_noop("strategy")]
      },
      %{
        char: "\u{1F3B5}",
        name: gettext_noop("musical note"),
        keywords: [gettext_noop("music"), gettext_noop("note")]
      },
      %{
        char: "\u{1F3B6}",
        name: gettext_noop("musical notes"),
        keywords: [gettext_noop("music"), gettext_noop("notes")]
      },
      %{
        char: "\u{1F3B8}",
        name: gettext_noop("guitar"),
        keywords: [gettext_noop("guitar"), gettext_noop("music")]
      },
      %{
        char: "\u{1F3B9}",
        name: gettext_noop("musical keyboard"),
        keywords: [gettext_noop("piano"), gettext_noop("keyboard")]
      },
      %{
        char: "\u{1F3BA}",
        name: gettext_noop("trumpet"),
        keywords: [gettext_noop("trumpet"), gettext_noop("music")]
      },
      %{
        char: "\u{1F3BB}",
        name: gettext_noop("violin"),
        keywords: [gettext_noop("violin"), gettext_noop("music")]
      },
      %{
        char: "\u{1F3AC}",
        name: gettext_noop("clapper board"),
        keywords: [gettext_noop("movie"), gettext_noop("film")]
      },
      %{
        char: "\u{1F3A8}",
        name: gettext_noop("artist palette"),
        keywords: [gettext_noop("art"), gettext_noop("paint")]
      },
      %{
        char: "\u{1F3AD}",
        name: gettext_noop("performing arts"),
        keywords: [gettext_noop("theater"), gettext_noop("drama")]
      }
    ],
    gettext_noop("Objects") => [
      %{
        char: "\u{1F4F1}",
        name: gettext_noop("mobile phone"),
        keywords: [gettext_noop("phone"), gettext_noop("cell")]
      },
      %{
        char: "\u{1F4BB}",
        name: gettext_noop("laptop"),
        keywords: [gettext_noop("computer"), gettext_noop("laptop")]
      },
      %{
        char: "\u{1F5A5}\u{FE0F}",
        name: gettext_noop("desktop computer"),
        keywords: [gettext_noop("computer"), gettext_noop("desktop")]
      },
      %{
        char: "\u{2328}\u{FE0F}",
        name: gettext_noop("keyboard"),
        keywords: [gettext_noop("keyboard"), gettext_noop("type")]
      },
      %{
        char: "\u{1F4BE}",
        name: gettext_noop("floppy disk"),
        keywords: [gettext_noop("floppy"), gettext_noop("save")]
      },
      %{
        char: "\u{1F4BF}",
        name: gettext_noop("optical disk"),
        keywords: [gettext_noop("cd"), gettext_noop("disc")]
      },
      %{
        char: "\u{1F4C0}",
        name: gettext_noop("dvd"),
        keywords: [gettext_noop("dvd"), gettext_noop("disc")]
      },
      %{
        char: "\u{1F4BD}",
        name: gettext_noop("minidisc"),
        keywords: [gettext_noop("disc"), gettext_noop("data")]
      },
      %{
        char: "\u{1F4F7}",
        name: gettext_noop("camera"),
        keywords: [gettext_noop("camera"), gettext_noop("photo")]
      },
      %{
        char: "\u{1F4FA}",
        name: gettext_noop("television"),
        keywords: [gettext_noop("tv"), gettext_noop("screen")]
      },
      %{
        char: "\u{1F4FB}",
        name: gettext_noop("radio"),
        keywords: [gettext_noop("radio"), gettext_noop("broadcast")]
      },
      %{
        char: "\u{1F50B}",
        name: gettext_noop("battery"),
        keywords: [gettext_noop("battery"), gettext_noop("power")]
      },
      %{
        char: "\u{1F50C}",
        name: gettext_noop("electric plug"),
        keywords: [gettext_noop("plug"), gettext_noop("power")]
      },
      %{
        char: "\u{1F4A1}",
        name: gettext_noop("light bulb"),
        keywords: [gettext_noop("idea"), gettext_noop("light")]
      },
      %{
        char: "\u{1F50D}",
        name: gettext_noop("magnifying glass left"),
        keywords: [gettext_noop("search"), gettext_noop("find")]
      },
      %{
        char: "\u{1F50E}",
        name: gettext_noop("magnifying glass right"),
        keywords: [gettext_noop("search"), gettext_noop("find")]
      },
      %{
        char: "\u{1F512}",
        name: gettext_noop("locked"),
        keywords: [gettext_noop("lock"), gettext_noop("security")]
      },
      %{
        char: "\u{1F513}",
        name: gettext_noop("unlocked"),
        keywords: [gettext_noop("unlock"), gettext_noop("open")]
      },
      %{
        char: "\u{1F511}",
        name: gettext_noop("key"),
        keywords: [gettext_noop("key"), gettext_noop("lock")]
      },
      %{
        char: "\u{1F528}",
        name: gettext_noop("hammer"),
        keywords: [gettext_noop("hammer"), gettext_noop("tool")]
      },
      %{
        char: "\u{1F527}",
        name: gettext_noop("wrench"),
        keywords: [gettext_noop("wrench"), gettext_noop("tool")]
      },
      %{
        char: "\u{1F529}",
        name: gettext_noop("nut and bolt"),
        keywords: [gettext_noop("nut"), gettext_noop("bolt")]
      },
      %{
        char: "\u{2699}\u{FE0F}",
        name: gettext_noop("gear"),
        keywords: [gettext_noop("gear"), gettext_noop("settings")]
      },
      %{
        char: "\u{1F4E7}",
        name: gettext_noop("email"),
        keywords: [gettext_noop("email"), gettext_noop("mail")]
      },
      %{
        char: "\u{1F4E8}",
        name: gettext_noop("incoming envelope"),
        keywords: [gettext_noop("email"), gettext_noop("inbox")]
      },
      %{
        char: "\u{1F4DD}",
        name: gettext_noop("memo"),
        keywords: [gettext_noop("note"), gettext_noop("write")]
      },
      %{
        char: "\u{1F4D6}",
        name: gettext_noop("open book"),
        keywords: [gettext_noop("book"), gettext_noop("read")]
      },
      %{
        char: "\u{1F4DA}",
        name: gettext_noop("books"),
        keywords: [gettext_noop("books"), gettext_noop("library")]
      },
      %{
        char: "\u{1F4CB}",
        name: gettext_noop("clipboard"),
        keywords: [gettext_noop("clipboard"), gettext_noop("list")]
      },
      %{
        char: "\u{1F4CC}",
        name: gettext_noop("pushpin"),
        keywords: [gettext_noop("pin"), gettext_noop("mark")]
      },
      %{
        char: "\u{1F4CE}",
        name: gettext_noop("paperclip"),
        keywords: [gettext_noop("paperclip"), gettext_noop("attach")]
      },
      %{
        char: "\u{2702}\u{FE0F}",
        name: gettext_noop("scissors"),
        keywords: [gettext_noop("scissors"), gettext_noop("cut")]
      },
      %{
        char: "\u{1F4B0}",
        name: gettext_noop("money bag"),
        keywords: [gettext_noop("money"), gettext_noop("rich")]
      },
      %{
        char: "\u{1F4B3}",
        name: gettext_noop("credit card"),
        keywords: [gettext_noop("card"), gettext_noop("payment")]
      },
      %{
        char: "\u{1F48E}",
        name: gettext_noop("gem stone"),
        keywords: [gettext_noop("gem"), gettext_noop("diamond")]
      }
    ],
    gettext_noop("Symbols") => [
      %{
        char: "\u{2705}",
        name: gettext_noop("check mark button"),
        keywords: [gettext_noop("check"), gettext_noop("yes"), gettext_noop("done")]
      },
      %{
        char: "\u{274C}",
        name: gettext_noop("cross mark"),
        keywords: [gettext_noop("no"), gettext_noop("wrong"), gettext_noop("delete")]
      },
      %{
        char: "\u{274E}",
        name: gettext_noop("cross mark button"),
        keywords: [gettext_noop("no"), gettext_noop("wrong")]
      },
      %{
        char: "\u{2B55}",
        name: gettext_noop("hollow red circle"),
        keywords: [gettext_noop("circle"), gettext_noop("zero")]
      },
      %{
        char: "\u{2757}",
        name: gettext_noop("red exclamation mark"),
        keywords: [gettext_noop("exclamation"), gettext_noop("warning")]
      },
      %{
        char: "\u{2753}",
        name: gettext_noop("red question mark"),
        keywords: [gettext_noop("question"), gettext_noop("help")]
      },
      %{
        char: "\u{2049}\u{FE0F}",
        name: gettext_noop("exclamation question mark"),
        keywords: [gettext_noop("surprise"), gettext_noop("what")]
      },
      %{
        char: "\u{203C}\u{FE0F}",
        name: gettext_noop("double exclamation mark"),
        keywords: [gettext_noop("exclamation"), gettext_noop("urgent")]
      },
      %{
        char: "\u{1F4F2}",
        name: gettext_noop("mobile phone with arrow"),
        keywords: [gettext_noop("call"), gettext_noop("phone")]
      },
      %{
        char: "\u{1F6AB}",
        name: gettext_noop("prohibited"),
        keywords: [gettext_noop("no"), gettext_noop("forbidden")]
      },
      %{
        char: "\u{1F4A4}",
        name: gettext_noop("zzz"),
        keywords: [gettext_noop("sleep"), gettext_noop("tired")]
      },
      %{
        char: "\u{1F4A2}",
        name: gettext_noop("anger symbol"),
        keywords: [gettext_noop("angry"), gettext_noop("rage")]
      },
      %{
        char: "\u{1F4A3}",
        name: gettext_noop("bomb"),
        keywords: [gettext_noop("bomb"), gettext_noop("explode")]
      },
      %{
        char: "\u{1F4A5}",
        name: gettext_noop("collision"),
        keywords: [gettext_noop("boom"), gettext_noop("crash")]
      },
      %{
        char: "\u{1F4A8}",
        name: gettext_noop("dashing away"),
        keywords: [gettext_noop("wind"), gettext_noop("fast")]
      },
      %{
        char: "\u{1F4AC}",
        name: gettext_noop("speech balloon"),
        keywords: [gettext_noop("chat"), gettext_noop("talk")]
      },
      %{
        char: "\u{1F4AD}",
        name: gettext_noop("thought balloon"),
        keywords: [gettext_noop("think"), gettext_noop("thought")]
      },
      %{
        char: "\u{1F440}",
        name: gettext_noop("eyes"),
        keywords: [gettext_noop("eyes"), gettext_noop("look")]
      },
      %{
        char: "\u{1F648}",
        name: gettext_noop("see-no-evil monkey"),
        keywords: [gettext_noop("monkey"), gettext_noop("blind")]
      },
      %{
        char: "\u{1F649}",
        name: gettext_noop("hear-no-evil monkey"),
        keywords: [gettext_noop("monkey"), gettext_noop("deaf")]
      },
      %{
        char: "\u{1F64A}",
        name: gettext_noop("speak-no-evil monkey"),
        keywords: [gettext_noop("monkey"), gettext_noop("mute")]
      },
      %{
        char: "\u{2B06}\u{FE0F}",
        name: gettext_noop("up arrow"),
        keywords: [gettext_noop("up"), gettext_noop("arrow")]
      },
      %{
        char: "\u{2B07}\u{FE0F}",
        name: gettext_noop("down arrow"),
        keywords: [gettext_noop("down"), gettext_noop("arrow")]
      },
      %{
        char: "\u{27A1}\u{FE0F}",
        name: gettext_noop("right arrow"),
        keywords: [gettext_noop("right"), gettext_noop("arrow")]
      },
      %{
        char: "\u{2B05}\u{FE0F}",
        name: gettext_noop("left arrow"),
        keywords: [gettext_noop("left"), gettext_noop("arrow")]
      },
      %{
        char: "\u{1F504}",
        name: gettext_noop("counterclockwise arrows"),
        keywords: [gettext_noop("refresh"), gettext_noop("reload")]
      },
      %{
        char: "\u{2139}\u{FE0F}",
        name: gettext_noop("information"),
        keywords: [gettext_noop("info"), gettext_noop("help")]
      },
      %{
        char: "\u{1F195}",
        name: gettext_noop("NEW button"),
        keywords: [gettext_noop("new"), gettext_noop("badge")]
      },
      %{
        char: "\u{1F197}",
        name: gettext_noop("OK button"),
        keywords: [gettext_noop("ok"), gettext_noop("accept")]
      },
      %{
        char: "\u{1F199}",
        name: gettext_noop("UP! button"),
        keywords: [gettext_noop("up"), gettext_noop("update")]
      }
    ]
  }

  @all_emojis @emojis
              |> Map.values()
              |> List.flatten()

  @doc "Returns all emojis grouped by category."
  @spec all() :: %{String.t() => [emoji()]}
  def all do
    Map.new(@emojis, fn {category, emojis} ->
      {t(category), translate_emojis(emojis)}
    end)
  end

  @doc "Returns the list of category names in display order."
  @spec categories() :: [String.t()]
  def categories, do: Enum.map(@categories, &t/1)

  @doc "Returns emojis for a given category."
  @spec by_category(String.t()) :: [emoji()]
  def by_category(category) do
    category
    |> canonical_category()
    |> then(&Map.get(@emojis, &1, []))
    |> translate_emojis()
  end

  @doc """
  Searches emojis by name and keywords.

  Returns empty list for queries shorter than 2 characters.
  Case-insensitive matching on name and keywords.
  """
  @spec search(String.t()) :: [emoji()]
  def search(query) when byte_size(query) < 2, do: []

  def search(query) do
    downcased = String.downcase(query)

    @all_emojis
    |> Enum.filter(&emoji_matches?(&1, downcased))
    |> translate_emojis()
  end

  defp canonical_category(category) do
    Enum.find(@categories, fn canonical ->
      category in [canonical, t(canonical)]
    end) || category
  end

  defp emoji_matches?(emoji, downcased) do
    searchable =
      [emoji.name, t(emoji.name)] ++
        emoji.keywords ++ Enum.map(emoji.keywords, &t/1)

    Enum.any?(searchable, fn text ->
      String.contains?(String.downcase(text), downcased)
    end)
  end

  defp translate_emojis(emojis), do: Enum.map(emojis, &translate_emoji/1)

  defp translate_emoji(emoji) do
    %{emoji | name: t(emoji.name), keywords: Enum.map(emoji.keywords, &t/1)}
  end

  defp t(msgid), do: Gettext.gettext(RetroHexChat.Gettext, msgid)
end
