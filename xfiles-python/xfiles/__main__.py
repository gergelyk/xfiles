#!/usr/bin/env python3

# Print items list
# $ xfiles
#
# Define list of items
# $ xfiles foo bar
#
# Add items to the list
# $ xfiles + baz qux
# $ echo 'baz\nqux' | xfiles +
#
# Remove items from the list
# $ xfiles - baz qux
# $ echo 'baz\nqux' | xfiles -
#
# Clear list
# $ xfiles --
#
# Print path to the list
# $ xfiles ++

import os
import pwd
import sys
from pathlib import Path

def home(name):
    if not name:
        name = os.getlogin()
    return pwd.getpwnam(name).pw_dir

def normalize_path(path):
    """Expand `~`, `.`, `..`, convert to absolute, do not resolve symlinks.
    Work also with non-existing paths.
    """

    # This function has been implemented fore educational purposes only.
    # Otherwise this implementation would be sufficient:
    #     os.path.abspath(os.path.expanduser(Path(path).as_posix()))
    # Note that it is not the same as:
    #     Path().expanduser().absolute().as_posix()

    sep = '/'
    parts = path.split(sep)

    if parts[0].startswith('~'):
        parts = home(parts[0][1:]).split(sep) + parts[1:]
    elif parts[0] != '':
        parts = os.getcwd().split(sep) + parts

    parts = [part for part in parts if part != '' and part != '.']

    i = 0
    while i < len(parts):
        if parts[i] == '..':
            del parts[i]
            if i > 0:
                i -= 1
                del parts[i]
        else:
            i += 1

    return sep + sep.join(parts)

def get_stdin_args():
    if sys.stdin.isatty():
        stdin_args = []
    else:
        stdin_args = [line for line in sys.stdin.read().splitlines() if line]
    return stdin_args

class Selection():
    def __init__(self):
        storage = Path('/dev/shm')
        if not storage.is_dir():
            storage = Path('/tmp')
        self._path = storage / 'xfiles'

    def _read_items(self):
        try:
            text = self._path.read_text()
        except FileNotFoundError:
            text = ''
            self.clear()
        return text.splitlines()

    def _write_items(self, items):
        text = '\n'.join(items)
        self._path.write_text(text)

    def show(self):
        text = '\n'.join(self._read_items())
        if text:
            print(text)

    def show_path(self):
        self._read_items()
        print(self._path)

    def add(self, items):
        old_items = self._read_items()
        all_items = [normalize_path(item) for item in (*old_items, *items) if item]
        unique_items = list({key: None for key in all_items}.keys()) # remove duplicates
        self._write_items(unique_items)

    def remove(self, items):
        old_items = self._read_items()
        abs_items = [normalize_path(item) for item in items if item]
        all_items = list({key: None for key in old_items if key not in abs_items}.keys())
        self._write_items(all_items)

    def clear(self):
        self._path.touch()
        self._path.write_text('')

def main():
    selection = Selection()
    args = sys.argv[1:]
    stdin_args = get_stdin_args()

    if args:
        cmd = args[0]
        cmd_args = args[1:] or stdin_args

        if cmd == '+':
            selection.add(cmd_args)
            selection.show()
        elif cmd == '-':
            selection.remove(cmd_args)
            selection.show()
        elif cmd == '++':
            selection.show_path()
        elif cmd == '--':
            selection.clear()
        else:
            selection.clear()
            selection.add(args)
            selection.show()
    else:
        if stdin_args:
            selection.clear()
            selection.add(stdin_args)
        selection.show()

if __name__ == '__main__':
    main()
