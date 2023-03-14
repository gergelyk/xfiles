# xfiles

Add/remove files to the list. List of files is stored in a file. File can be used
to implement copy/paste and other operations. See Integration examples below.

## Development

For educational purposes project has been implemented in multiple languages:

```
Implementation  Status
--------------  ------
xfiles-coconut  Finished
xfiles-elvish   Finished
xfiles-haskell  Finished
xfiles-julia    Finished
xfiles-lua      Finished
xfiles-python   Finished, reference implementation
xfiles-rust     Finished, see known issues
xfiles-swift    Not finished
```

All implementations are tested against the same set of tests (see `tasks.py`).

## Usage

```sh
# Print items list
$ xfiles

# Define list of items
$ xfiles foo bar

# Add items to the list
$ xfiles + baz qux
$ echo 'baz\nqux' | xfiles +

# Remove items from the list
$ xfiles - baz qux
$ echo 'baz\nqux' | xfiles -

# Clear list
$ xfiles --

# Print path to the list
# $ xfiles ++
```

## Integration

Following shows how `xfiles` can be used in [elvish](https://elv.sh/).

```elvish
use epm
epm:install github.com/gergelyk/elvish-libs
use gk-utils gk

# alias for xfiles
fn xx {|@a| xfiles $@a}

# print list of files, allow selection
fn xxl {
  put * | to-lines | fzf -m | xfiles
}

# remove files that are on the list
fn xxr {
  rm -frvI (xfiles)
  xfiles --
}

# copy files that are on the list to CWD
fn xxc {|@args|
  set args = (gk:parse-args [target] [.] $args)
  var target = $args[target]
  cp -v (xfiles) $target
  xfiles --
}

# move files that are on the list to CWD
fn xxm {|@args|
  set args = (gk:parse-args [target] [.] $args)
  var target = $args[target]
  mv -v (xfiles) $target
  xfiles --
}
```

## Known issues

- xfiles-rust: what if /dev/shm/xfiles does not exist

## Testing

Obtain `invoke`:
```sh
pip install --user invoke
```

Run tests:
```sh
inv test-operation python
inv test-paths python
inv test-operation lua
inv test-paths lua
...
```