"""Credentials: the .env parser and the environment's precedence over it."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from seo import transport


class ParseDotenvTest(unittest.TestCase):
    def test_comments_blanks_quotes_and_export(self):
        text = '# c\n\nA=1\nexport B="two words"\nC=\'x=y\'\nnot a pair\n'
        self.assertEqual(transport.parse_dotenv(text), {"A": "1", "B": "two words", "C": "x=y"})


class EnvValueTest(unittest.TestCase):
    def setUp(self):
        self.dotenv = Path(tempfile.mkdtemp()) / ".env"
        self.dotenv.write_text("KEY=from-file\nEMPTY=\n")

    def test_the_environment_wins(self):
        with mock.patch.dict(os.environ, {"KEY": "from-env"}):
            self.assertEqual(transport.env_value("KEY", self.dotenv), "from-env")

    def test_falls_back_to_the_file(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(transport.env_value("KEY", self.dotenv), "from-file")
            self.assertIsNone(transport.env_value("EMPTY", self.dotenv))
            self.assertIsNone(transport.env_value("KEY", self.dotenv.with_name("missing")))


if __name__ == "__main__":
    unittest.main()
