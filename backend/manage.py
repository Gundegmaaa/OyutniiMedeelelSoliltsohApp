#!/usr/bin/env python
"""Django management entry point."""
import os
import sys

if __name__ == "__main__":
    # Windows redirected output may default to cp1252, which cannot print the
    # Mongolian verification emails used by the development console backend.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)
