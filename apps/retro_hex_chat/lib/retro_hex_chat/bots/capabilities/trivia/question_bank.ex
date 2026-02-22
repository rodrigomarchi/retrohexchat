defmodule RetroHexChat.Bots.Capabilities.Trivia.QuestionBank do
  @moduledoc """
  Built-in question bank for the Trivia capability.
  Organized by category with questions, answers, and hints.
  """

  @type question :: %{
          question: String.t(),
          answer: String.t(),
          hints: [String.t()],
          category: String.t()
        }

  @questions %{
    "general" => [
      %{question: "What is the capital of France?", answer: "Paris", hints: ["City of Light"]},
      %{question: "How many continents are there?", answer: "7", hints: ["More than 5"]},
      %{question: "What is the largest ocean?", answer: "Pacific", hints: ["Peaceful"]},
      %{
        question: "What year did the Titanic sink?",
        answer: "1912",
        hints: ["Early 20th century"]
      },
      %{question: "How many colors in a rainbow?", answer: "7", hints: ["ROY G BIV"]},
      %{question: "What is the hardest natural substance?", answer: "diamond", hints: ["A gem"]},
      %{
        question: "What planet is known as the Red Planet?",
        answer: "Mars",
        hints: ["4th from sun"]
      },
      %{question: "How many sides does a hexagon have?", answer: "6", hints: ["Hex = six"]},
      %{
        question: "What is the chemical symbol for gold?",
        answer: "Au",
        hints: ["From Latin aurum"]
      },
      %{
        question: "What is the largest mammal?",
        answer: "blue whale",
        hints: ["Lives in the ocean"]
      },
      %{question: "What gas do plants absorb?", answer: "carbon dioxide", hints: ["CO2"]},
      %{
        question: "What is the boiling point of water in Celsius?",
        answer: "100",
        hints: ["Three digits"]
      },
      %{question: "How many bones in the adult human body?", answer: "206", hints: ["Over 200"]},
      %{
        question: "What is the speed of light (km/s)?",
        answer: "300000",
        hints: ["~3 x 10^5 km/s"]
      },
      %{
        question: "What is the smallest country by area?",
        answer: "Vatican City",
        hints: ["In Rome"]
      }
    ],
    "science" => [
      %{
        question: "What is the chemical symbol for water?",
        answer: "H2O",
        hints: ["Two elements"]
      },
      %{
        question: "What planet has the most moons?",
        answer: "Saturn",
        hints: ["Famous for rings"]
      },
      %{
        question: "What is the powerhouse of the cell?",
        answer: "mitochondria",
        hints: ["Organelle"]
      },
      %{question: "What element has atomic number 1?", answer: "hydrogen", hints: ["Lightest"]},
      %{question: "What is the closest star to Earth?", answer: "Sun", hints: ["Look up"]},
      %{question: "What is the pH of pure water?", answer: "7", hints: ["Neutral"]},
      %{
        question: "What gas makes up 78% of Earth's atmosphere?",
        answer: "nitrogen",
        hints: ["N2"]
      },
      %{
        question: "How many planets in our solar system?",
        answer: "8",
        hints: ["Pluto was demoted"]
      },
      %{
        question: "What is the chemical formula for table salt?",
        answer: "NaCl",
        hints: ["Sodium..."]
      },
      %{
        question: "What force keeps planets in orbit?",
        answer: "gravity",
        hints: ["Newton's apple"]
      },
      %{question: "What is absolute zero in Celsius?", answer: "-273", hints: ["Very cold"]},
      %{question: "What vitamin does the sun provide?", answer: "D", hints: ["A single letter"]},
      %{
        question: "What is the largest organ in the human body?",
        answer: "skin",
        hints: ["Outside"]
      },
      %{
        question: "What particle has a positive charge?",
        answer: "proton",
        hints: ["In the nucleus"]
      },
      %{question: "What is the study of fungi called?", answer: "mycology", hints: ["Myco-"]}
    ],
    "history" => [
      %{question: "In what year did World War II end?", answer: "1945", hints: ["Mid-1940s"]},
      %{
        question: "Who was the first president of the USA?",
        answer: "George Washington",
        hints: ["Dollar bill"]
      },
      %{
        question: "What ancient wonder was in Alexandria?",
        answer: "Lighthouse",
        hints: ["Pharos"]
      },
      %{question: "What year did the Berlin Wall fall?", answer: "1989", hints: ["Late 1980s"]},
      %{
        question: "Who wrote the Communist Manifesto?",
        answer: "Karl Marx",
        hints: ["German philosopher"]
      },
      %{question: "What empire built the Colosseum?", answer: "Roman", hints: ["In Italy"]},
      %{
        question: "What ship brought Pilgrims to America?",
        answer: "Mayflower",
        hints: ["A flower"]
      },
      %{question: "Who invented the printing press?", answer: "Gutenberg", hints: ["Johannes"]},
      %{
        question: "What year did Columbus reach America?",
        answer: "1492",
        hints: ["15th century"]
      },
      %{
        question: "Who was the first man on the moon?",
        answer: "Neil Armstrong",
        hints: ["Apollo 11"]
      },
      %{
        question: "What revolution started in 1789?",
        answer: "French Revolution",
        hints: ["Bastille"]
      },
      %{
        question: "Who painted the Mona Lisa?",
        answer: "Leonardo da Vinci",
        hints: ["Renaissance"]
      },
      %{
        question: "What year was the Declaration of Independence signed?",
        answer: "1776",
        hints: ["17--"]
      },
      %{question: "Who discovered penicillin?", answer: "Alexander Fleming", hints: ["Scottish"]},
      %{
        question: "What civilization built Machu Picchu?",
        answer: "Inca",
        hints: ["South America"]
      }
    ],
    "geography" => [
      %{
        question: "What is the longest river in the world?",
        answer: "Nile",
        hints: ["In Africa"]
      },
      %{question: "What is the tallest mountain?", answer: "Mount Everest", hints: ["In Nepal"]},
      %{question: "What country has the most people?", answer: "India", hints: ["South Asia"]},
      %{question: "What is the largest desert?", answer: "Sahara", hints: ["In Africa"]},
      %{question: "What is the capital of Japan?", answer: "Tokyo", hints: ["Starts with T"]},
      %{
        question: "What is the deepest ocean trench?",
        answer: "Mariana Trench",
        hints: ["Pacific"]
      },
      %{
        question: "What continent is Brazil in?",
        answer: "South America",
        hints: ["Southern hemisphere"]
      },
      %{question: "What is the capital of Australia?", answer: "Canberra", hints: ["Not Sydney"]},
      %{
        question: "What is the smallest continent?",
        answer: "Australia",
        hints: ["Also a country"]
      },
      %{
        question: "What sea is between Europe and Africa?",
        answer: "Mediterranean",
        hints: ["Middle earth"]
      },
      %{question: "What is the capital of Canada?", answer: "Ottawa", hints: ["Not Toronto"]},
      %{
        question: "What strait separates Asia and North America?",
        answer: "Bering Strait",
        hints: ["Named after Vitus"]
      },
      %{
        question: "What is the largest island?",
        answer: "Greenland",
        hints: ["Danish territory"]
      },
      %{
        question: "What country is the Sahara Desert mostly in?",
        answer: "Algeria",
        hints: ["North Africa"]
      },
      %{question: "What is the capital of Egypt?", answer: "Cairo", hints: ["On the Nile"]}
    ],
    "technology" => [
      %{
        question: "What does HTML stand for?",
        answer: "HyperText Markup Language",
        hints: ["Web pages"]
      },
      %{question: "Who created Linux?", answer: "Linus Torvalds", hints: ["Finnish"]},
      %{
        question: "What year was the first iPhone released?",
        answer: "2007",
        hints: ["Late 2000s"]
      },
      %{
        question: "What does CPU stand for?",
        answer: "Central Processing Unit",
        hints: ["Brain of computer"]
      },
      %{
        question: "What company created Java?",
        answer: "Sun Microsystems",
        hints: ["Now Oracle"]
      },
      %{
        question: "What does HTTP stand for?",
        answer: "HyperText Transfer Protocol",
        hints: ["Web"]
      },
      %{question: "Who founded Microsoft?", answer: "Bill Gates", hints: ["And Paul Allen"]},
      %{
        question: "What year was the World Wide Web invented?",
        answer: "1989",
        hints: ["Tim Berners-Lee"]
      },
      %{
        question: "What does RAM stand for?",
        answer: "Random Access Memory",
        hints: ["Volatile"]
      },
      %{
        question: "What programming language is Elixir built on?",
        answer: "Erlang",
        hints: ["BEAM VM"]
      },
      %{
        question: "What does SQL stand for?",
        answer: "Structured Query Language",
        hints: ["Databases"]
      },
      %{
        question: "Who invented the telephone?",
        answer: "Alexander Graham Bell",
        hints: ["Bell Labs"]
      },
      %{
        question: "What does USB stand for?",
        answer: "Universal Serial Bus",
        hints: ["Plug it in"]
      },
      %{question: "What year was Google founded?", answer: "1998", hints: ["Late 1990s"]},
      %{
        question: "What does API stand for?",
        answer: "Application Programming Interface",
        hints: ["Integration"]
      }
    ],
    "entertainment" => [
      %{
        question: "What movie features a character named Neo?",
        answer: "The Matrix",
        hints: ["Red pill"]
      },
      %{question: "Who played Iron Man in the MCU?", answer: "Robert Downey Jr", hints: ["RDJ"]},
      %{
        question: "What band wrote 'Bohemian Rhapsody'?",
        answer: "Queen",
        hints: ["Freddie Mercury"]
      },
      %{
        question: "What is the highest-grossing film of all time?",
        answer: "Avatar",
        hints: ["Blue aliens"]
      },
      %{question: "Who wrote Harry Potter?", answer: "J.K. Rowling", hints: ["British author"]},
      %{question: "What instrument has 88 keys?", answer: "piano", hints: ["Black and white"]},
      %{
        question: "What TV show features dragons and an iron throne?",
        answer: "Game of Thrones",
        hints: ["HBO"]
      },
      %{
        question: "Who directed Jurassic Park?",
        answer: "Steven Spielberg",
        hints: ["Hollywood legend"]
      },
      %{
        question: "What game features a plumber named Mario?",
        answer: "Super Mario Bros",
        hints: ["Nintendo"]
      },
      %{
        question: "What is the best-selling video game of all time?",
        answer: "Minecraft",
        hints: ["Blocks"]
      },
      %{
        question: "Who painted the Starry Night?",
        answer: "Vincent van Gogh",
        hints: ["Dutch painter"]
      },
      %{
        question: "What fictional detective lived at 221B Baker Street?",
        answer: "Sherlock Holmes",
        hints: ["Elementary"]
      },
      %{
        question: "What Disney movie features a genie?",
        answer: "Aladdin",
        hints: ["Three wishes"]
      },
      %{
        question: "What board game has properties like Boardwalk?",
        answer: "Monopoly",
        hints: ["Pass Go"]
      },
      %{question: "Who sang 'Thriller'?", answer: "Michael Jackson", hints: ["King of Pop"]}
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
