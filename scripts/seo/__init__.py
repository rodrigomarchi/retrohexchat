"""Search-engine console readers that all produce one report shape.

Each source module (``bing``) turns its own API into the dict described in
``report``; ``report`` derives the problems and renders the Markdown, so the
output reads the same whichever engine it came from.
"""
