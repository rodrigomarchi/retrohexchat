defmodule RetroHexChat.Bots.Capabilities.Trivia.QuestionBank do
  @moduledoc """
  Built-in question bank for the Trivia capability.
  Organized by category with questions, answers, and hints.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @type question :: %{
          question: String.t(),
          answer: String.t(),
          hints: [String.t()],
          category: String.t()
        }

  @questions %{
    "general" => [
      %{
        question: dgettext("bots", "What is the capital of France?"),
        answer: dgettext("bots", "Paris"),
        hints: [dgettext("bots", "City of Light")]
      },
      %{
        question: dgettext("bots", "How many continents are there?"),
        answer: "7",
        hints: [dgettext("bots", "More than 5")]
      },
      %{
        question: dgettext("bots", "What is the largest ocean?"),
        answer: dgettext("bots", "Pacific"),
        hints: [dgettext("bots", "Peaceful")]
      },
      %{
        question: dgettext("bots", "What year did the Titanic sink?"),
        answer: "1912",
        hints: [dgettext("bots", "Early 20th century")]
      },
      %{
        question: dgettext("bots", "How many colors in a rainbow?"),
        answer: "7",
        hints: [dgettext("bots", "ROY G BIV")]
      },
      %{
        question: dgettext("bots", "What is the hardest natural substance?"),
        answer: "diamond",
        hints: [dgettext("bots", "A gem")]
      },
      %{
        question: dgettext("bots", "What planet is known as the Red Planet?"),
        answer: dgettext("bots", "Mars"),
        hints: [dgettext("bots", "4th from sun")]
      },
      %{
        question: dgettext("bots", "How many sides does a hexagon have?"),
        answer: "6",
        hints: [dgettext("bots", "Hex = six")]
      },
      %{
        question: dgettext("bots", "What is the chemical symbol for gold?"),
        answer: dgettext("bots", "Au"),
        hints: [dgettext("bots", "From Latin aurum")]
      },
      %{
        question: dgettext("bots", "What is the largest mammal?"),
        answer: dgettext("bots", "blue whale"),
        hints: [dgettext("bots", "Lives in the ocean")]
      },
      %{
        question: dgettext("bots", "What gas do plants absorb?"),
        answer: dgettext("bots", "carbon dioxide"),
        hints: ["CO2"]
      },
      %{
        question: dgettext("bots", "What is the boiling point of water in Celsius?"),
        answer: "100",
        hints: [dgettext("bots", "Three digits")]
      },
      %{
        question: dgettext("bots", "How many bones in the adult human body?"),
        answer: "206",
        hints: [dgettext("bots", "Over 200")]
      },
      %{
        question: dgettext("bots", "What is the speed of light (km/s)?"),
        answer: "300000",
        hints: [dgettext("bots", "~3 x 10^5 km/s")]
      },
      %{
        question: dgettext("bots", "What is the smallest country by area?"),
        answer: dgettext("bots", "Vatican City"),
        hints: [dgettext("bots", "In Rome")]
      }
    ],
    "science" => [
      %{
        question: dgettext("bots", "What is the chemical symbol for water?"),
        answer: "H2O",
        hints: [dgettext("bots", "Two elements")]
      },
      %{
        question: dgettext("bots", "What planet has the most moons?"),
        answer: dgettext("bots", "Saturn"),
        hints: [dgettext("bots", "Famous for rings")]
      },
      %{
        question: dgettext("bots", "What is the powerhouse of the cell?"),
        answer: "mitochondria",
        hints: [dgettext("bots", "Organelle")]
      },
      %{
        question: dgettext("bots", "What element has atomic number 1?"),
        answer: "hydrogen",
        hints: [dgettext("bots", "Lightest")]
      },
      %{
        question: dgettext("bots", "What is the closest star to Earth?"),
        answer: dgettext("bots", "Sun"),
        hints: [dgettext("bots", "Look up")]
      },
      %{
        question: dgettext("bots", "What is the pH of pure water?"),
        answer: "7",
        hints: [dgettext("bots", "Neutral")]
      },
      %{
        question: dgettext("bots", "What gas makes up 78% of Earth's atmosphere?"),
        answer: "nitrogen",
        hints: ["N2"]
      },
      %{
        question: dgettext("bots", "How many planets in our solar system?"),
        answer: "8",
        hints: [dgettext("bots", "Pluto was demoted")]
      },
      %{
        question: dgettext("bots", "What is the chemical formula for table salt?"),
        answer: dgettext("bots", "NaCl"),
        hints: [dgettext("bots", "Sodium...")]
      },
      %{
        question: dgettext("bots", "What force keeps planets in orbit?"),
        answer: "gravity",
        hints: [dgettext("bots", "Newton's apple")]
      },
      %{
        question: dgettext("bots", "What is absolute zero in Celsius?"),
        answer: "-273",
        hints: [dgettext("bots", "Very cold")]
      },
      %{
        question: dgettext("bots", "What vitamin does the sun provide?"),
        answer: "D",
        hints: [dgettext("bots", "A single letter")]
      },
      %{
        question: dgettext("bots", "What is the largest organ in the human body?"),
        answer: "skin",
        hints: [dgettext("bots", "Outside")]
      },
      %{
        question: dgettext("bots", "What particle has a positive charge?"),
        answer: "proton",
        hints: [dgettext("bots", "In the nucleus")]
      },
      %{
        question: dgettext("bots", "What is the study of fungi called?"),
        answer: "mycology",
        hints: [dgettext("bots", "Myco-")]
      }
    ],
    "history" => [
      %{
        question: dgettext("bots", "In what year did World War II end?"),
        answer: "1945",
        hints: ["Mid-1940s"]
      },
      %{
        question: dgettext("bots", "Who was the first president of the USA?"),
        answer: dgettext("bots", "George Washington"),
        hints: [dgettext("bots", "Dollar bill")]
      },
      %{
        question: dgettext("bots", "What ancient wonder was in Alexandria?"),
        answer: dgettext("bots", "Lighthouse"),
        hints: [dgettext("bots", "Pharos")]
      },
      %{
        question: dgettext("bots", "What year did the Berlin Wall fall?"),
        answer: "1989",
        hints: [dgettext("bots", "Late 1980s")]
      },
      %{
        question: dgettext("bots", "Who wrote the Communist Manifesto?"),
        answer: dgettext("bots", "Karl Marx"),
        hints: [dgettext("bots", "German philosopher")]
      },
      %{
        question: dgettext("bots", "What empire built the Colosseum?"),
        answer: dgettext("bots", "Roman"),
        hints: [dgettext("bots", "In Italy")]
      },
      %{
        question: dgettext("bots", "What ship brought Pilgrims to America?"),
        answer: dgettext("bots", "Mayflower"),
        hints: [dgettext("bots", "A flower")]
      },
      %{
        question: dgettext("bots", "Who invented the printing press?"),
        answer: dgettext("bots", "Gutenberg"),
        hints: [dgettext("bots", "Johannes")]
      },
      %{
        question: dgettext("bots", "What year did Columbus reach America?"),
        answer: "1492",
        hints: [dgettext("bots", "15th century")]
      },
      %{
        question: dgettext("bots", "Who was the first man on the moon?"),
        answer: dgettext("bots", "Neil Armstrong"),
        hints: [dgettext("bots", "Apollo 11")]
      },
      %{
        question: dgettext("bots", "What revolution started in 1789?"),
        answer: dgettext("bots", "French Revolution"),
        hints: [dgettext("bots", "Bastille")]
      },
      %{
        question: dgettext("bots", "Who painted the Mona Lisa?"),
        answer: dgettext("bots", "Leonardo da Vinci"),
        hints: [dgettext("bots", "Renaissance")]
      },
      %{
        question: dgettext("bots", "What year was the Declaration of Independence signed?"),
        answer: "1776",
        hints: ["17--"]
      },
      %{
        question: dgettext("bots", "Who discovered penicillin?"),
        answer: dgettext("bots", "Alexander Fleming"),
        hints: [dgettext("bots", "Scottish")]
      },
      %{
        question: dgettext("bots", "What civilization built Machu Picchu?"),
        answer: dgettext("bots", "Inca"),
        hints: [dgettext("bots", "South America")]
      }
    ],
    "geography" => [
      %{
        question: dgettext("bots", "What is the longest river in the world?"),
        answer: dgettext("bots", "Nile"),
        hints: [dgettext("bots", "In Africa")]
      },
      %{
        question: dgettext("bots", "What is the tallest mountain?"),
        answer: dgettext("bots", "Mount Everest"),
        hints: [dgettext("bots", "In Nepal")]
      },
      %{
        question: dgettext("bots", "What country has the most people?"),
        answer: dgettext("bots", "India"),
        hints: [dgettext("bots", "South Asia")]
      },
      %{
        question: dgettext("bots", "What is the largest desert?"),
        answer: dgettext("bots", "Sahara"),
        hints: [dgettext("bots", "In Africa")]
      },
      %{
        question: dgettext("bots", "What is the capital of Japan?"),
        answer: dgettext("bots", "Tokyo"),
        hints: [dgettext("bots", "Starts with T")]
      },
      %{
        question: dgettext("bots", "What is the deepest ocean trench?"),
        answer: dgettext("bots", "Mariana Trench"),
        hints: [dgettext("bots", "Pacific")]
      },
      %{
        question: dgettext("bots", "What continent is Brazil in?"),
        answer: dgettext("bots", "South America"),
        hints: [dgettext("bots", "Southern hemisphere")]
      },
      %{
        question: dgettext("bots", "What is the capital of Australia?"),
        answer: dgettext("bots", "Canberra"),
        hints: [dgettext("bots", "Not Sydney")]
      },
      %{
        question: dgettext("bots", "What is the smallest continent?"),
        answer: dgettext("bots", "Australia"),
        hints: [dgettext("bots", "Also a country")]
      },
      %{
        question: dgettext("bots", "What sea is between Europe and Africa?"),
        answer: dgettext("bots", "Mediterranean"),
        hints: [dgettext("bots", "Middle earth")]
      },
      %{
        question: dgettext("bots", "What is the capital of Canada?"),
        answer: dgettext("bots", "Ottawa"),
        hints: [dgettext("bots", "Not Toronto")]
      },
      %{
        question: dgettext("bots", "What strait separates Asia and North America?"),
        answer: dgettext("bots", "Bering Strait"),
        hints: [dgettext("bots", "Named after Vitus")]
      },
      %{
        question: dgettext("bots", "What is the largest island?"),
        answer: dgettext("bots", "Greenland"),
        hints: [dgettext("bots", "Danish territory")]
      },
      %{
        question: dgettext("bots", "What country is the Sahara Desert mostly in?"),
        answer: dgettext("bots", "Algeria"),
        hints: [dgettext("bots", "North Africa")]
      },
      %{
        question: dgettext("bots", "What is the capital of Egypt?"),
        answer: dgettext("bots", "Cairo"),
        hints: [dgettext("bots", "On the Nile")]
      }
    ],
    "technology" => [
      %{
        question: dgettext("bots", "What does HTML stand for?"),
        answer: dgettext("bots", "HyperText Markup Language"),
        hints: [dgettext("bots", "Web pages")]
      },
      %{
        question: dgettext("bots", "Who created Linux?"),
        answer: dgettext("bots", "Linus Torvalds"),
        hints: [dgettext("bots", "Finnish")]
      },
      %{
        question: dgettext("bots", "What year was the first iPhone released?"),
        answer: "2007",
        hints: [dgettext("bots", "Late 2000s")]
      },
      %{
        question: dgettext("bots", "What does CPU stand for?"),
        answer: dgettext("bots", "Central Processing Unit"),
        hints: [dgettext("bots", "Brain of computer")]
      },
      %{
        question: dgettext("bots", "What company created Java?"),
        answer: dgettext("bots", "Sun Microsystems"),
        hints: [dgettext("bots", "Now Oracle")]
      },
      %{
        question: dgettext("bots", "What does HTTP stand for?"),
        answer: dgettext("bots", "HyperText Transfer Protocol"),
        hints: [dgettext("bots", "Web")]
      },
      %{
        question: dgettext("bots", "Who founded Microsoft?"),
        answer: dgettext("bots", "Bill Gates"),
        hints: [dgettext("bots", "And Paul Allen")]
      },
      %{
        question: dgettext("bots", "What year was the World Wide Web invented?"),
        answer: "1989",
        hints: [dgettext("bots", "Tim Berners-Lee")]
      },
      %{
        question: dgettext("bots", "What does RAM stand for?"),
        answer: dgettext("bots", "Random Access Memory"),
        hints: [dgettext("bots", "Volatile")]
      },
      %{
        question: dgettext("bots", "What programming language is Elixir built on?"),
        answer: dgettext("bots", "Erlang"),
        hints: [dgettext("bots", "BEAM VM")]
      },
      %{
        question: dgettext("bots", "What does SQL stand for?"),
        answer: dgettext("bots", "Structured Query Language"),
        hints: [dgettext("bots", "Databases")]
      },
      %{
        question: dgettext("bots", "Who invented the telephone?"),
        answer: dgettext("bots", "Alexander Graham Bell"),
        hints: [dgettext("bots", "Bell Labs")]
      },
      %{
        question: dgettext("bots", "What does USB stand for?"),
        answer: dgettext("bots", "Universal Serial Bus"),
        hints: [dgettext("bots", "Plug it in")]
      },
      %{
        question: dgettext("bots", "What year was Google founded?"),
        answer: "1998",
        hints: [dgettext("bots", "Late 1990s")]
      },
      %{
        question: dgettext("bots", "What does API stand for?"),
        answer: dgettext("bots", "Application Programming Interface"),
        hints: [dgettext("bots", "Integration")]
      }
    ],
    "entertainment" => [
      %{
        question: dgettext("bots", "What movie features a character named Neo?"),
        answer: dgettext("bots", "The Matrix"),
        hints: [dgettext("bots", "Red pill")]
      },
      %{
        question: dgettext("bots", "Who played Iron Man in the MCU?"),
        answer: dgettext("bots", "Robert Downey Jr"),
        hints: [dgettext("bots", "RDJ")]
      },
      %{
        question: dgettext("bots", "What band wrote 'Bohemian Rhapsody'?"),
        answer: dgettext("bots", "Queen"),
        hints: [dgettext("bots", "Freddie Mercury")]
      },
      %{
        question: dgettext("bots", "What is the highest-grossing film of all time?"),
        answer: dgettext("bots", "Avatar"),
        hints: [dgettext("bots", "Blue aliens")]
      },
      %{
        question: dgettext("bots", "Who wrote Harry Potter?"),
        answer: dgettext("bots", "J.K. Rowling"),
        hints: [dgettext("bots", "British author")]
      },
      %{
        question: dgettext("bots", "What instrument has 88 keys?"),
        answer: "piano",
        hints: [dgettext("bots", "Black and white")]
      },
      %{
        question: dgettext("bots", "What TV show features dragons and an iron throne?"),
        answer: dgettext("bots", "Game of Thrones"),
        hints: [dgettext("bots", "HBO")]
      },
      %{
        question: dgettext("bots", "Who directed Jurassic Park?"),
        answer: dgettext("bots", "Steven Spielberg"),
        hints: [dgettext("bots", "Hollywood legend")]
      },
      %{
        question: dgettext("bots", "What game features a plumber named Mario?"),
        answer: dgettext("bots", "Super Mario Bros"),
        hints: [dgettext("bots", "Nintendo")]
      },
      %{
        question: dgettext("bots", "What is the best-selling video game of all time?"),
        answer: dgettext("bots", "Minecraft"),
        hints: [dgettext("bots", "Blocks")]
      },
      %{
        question: dgettext("bots", "Who painted the Starry Night?"),
        answer: dgettext("bots", "Vincent van Gogh"),
        hints: [dgettext("bots", "Dutch painter")]
      },
      %{
        question: dgettext("bots", "What fictional detective lived at 221B Baker Street?"),
        answer: dgettext("bots", "Sherlock Holmes"),
        hints: [dgettext("bots", "Elementary")]
      },
      %{
        question: dgettext("bots", "What Disney movie features a genie?"),
        answer: dgettext("bots", "Aladdin"),
        hints: [dgettext("bots", "Three wishes")]
      },
      %{
        question: dgettext("bots", "What board game has properties like Boardwalk?"),
        answer: dgettext("bots", "Monopoly"),
        hints: [dgettext("bots", "Pass Go")]
      },
      %{
        question: dgettext("bots", "Who sang 'Thriller'?"),
        answer: dgettext("bots", "Michael Jackson"),
        hints: [dgettext("bots", "King of Pop")]
      }
    ]
  }

  @spec categories() :: [String.t()]
  def categories, do: Map.keys(@questions)

  @spec random_questions(String.t(), pos_integer()) :: [question()]
  def random_questions(category, count) do
    pool = Map.get(@questions, category, Map.get(@questions, "general", []))
    pool |> Enum.shuffle() |> Enum.take(count)
  end

  @spec question_count(String.t()) :: non_neg_integer()
  def question_count(category) do
    pool = Map.get(@questions, category, [])
    length(pool)
  end
end
