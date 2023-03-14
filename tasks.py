import getpass
from pathlib import Path
from invoke import task
from unittest import TestCase

class StdOut:
    _tc = TestCase()

    def __init__(self, text):
        self._text = text

    def __eq__(self, other):
        self._tc.assertEqual(self._text.splitlines(), other)

    def __str__(self):
        return self._text

class ShellCmd:

    def __init__(self, ctx, target):
        self._ctx = ctx
        self._target = target

    def __call__(self, args=''):
        cmd = self._target + ' ' + args
        print('>', cmd)
        result = self._ctx.run(cmd, pty=True)
        return StdOut(result.stdout)

class Comment:

    def __or__(self, text):
        print('# ' + text)

def reset(xfiles, comment):
    comment | 'reset'
    xfiles('--') == []
    xfiles() == []

def get_target(variant):
    return str(Path(__file__).parent / f'xfiles-{variant}/run.sh')

@task
def test_operation(ctx, variant):
    """variant - python/lua/rust/..."""

    target = get_target(variant)
    xfiles = ShellCmd(ctx, target)
    comment = Comment()

    with ctx.cd('/tmp'):

        reset(xfiles, comment)

        comment | 'add first item'
        xfiles('+ first') == ['/tmp/first']

        comment | 'read back'
        xfiles() == ['/tmp/first']

        comment | 'add second item'
        xfiles('+ second') == ['/tmp/first', '/tmp/second']

        comment | 'add duplicate'
        xfiles('+ first') == ['/tmp/first', '/tmp/second']

        comment | 'add two at once'
        xfiles('+ third fourth') == ['/tmp/first', '/tmp/second', '/tmp/third', '/tmp/fourth']

        comment | 'remove second'
        xfiles('- second') == ['/tmp/first', '/tmp/third', '/tmp/fourth']

        comment | 'remove first and fourth'
        xfiles('- first fourth') == ['/tmp/third']

        comment | 'remove non-existing'
        xfiles('- nonexisting') == ['/tmp/third']

        comment | 'define entire content'
        xfiles('alpha beta gamma') == ['/tmp/alpha', '/tmp/beta', '/tmp/gamma']
        xfiles() == ['/tmp/alpha', '/tmp/beta', '/tmp/gamma']

        comment | 'remove all'
        xfiles('--') == []

        comment | 'add from stdin'
        ctx.run('echo "first\nsecond" |' + target + ' +')
        xfiles() == ['/tmp/first', '/tmp/second']

        comment | 'remove from stdin'
        ctx.run('echo "first" |' + target + ' -')
        xfiles() == ['/tmp/second']

        comment | 'define entire content from stdin, with spaces'
        ctx.run('echo "first\nsec ond" |' + target)
        xfiles() == ['/tmp/first', '/tmp/sec ond']

        comment | 'remove storage'
        storage = str(xfiles('++')).strip()
        ctx.run('rm ' + storage)

        comment | 'recreate storage'
        xfiles('--') == []
        ctx.run('file ' + storage)

        reset(xfiles, comment)


@task
def test_paths(ctx, variant):
    """variant - python/lua/rust/..."""

    target = get_target(variant)
    username = getpass.getuser()
    xfiles = ShellCmd(ctx, target)
    comment = Comment()

    with ctx.cd('/tmp'):

        reset(xfiles, comment)

        comment | 'absolute path'
        xfiles('/foo/bar/baz') == ['/foo/bar/baz']

        comment | 'relative path'
        xfiles('foo/bar/baz') == ['/tmp/foo/bar/baz']

        comment | 'period in the middle'
        xfiles('/foo/./bar/baz') == ['/foo/bar/baz']

        comment | 'dot-file'
        xfiles('/foo/.bar/baz') == ['/foo/.bar/baz']

        comment | 'trailing slash'
        xfiles('/foo/bar/baz/') == ['/foo/bar/baz']

        comment | 'duplicated slash'
        xfiles('/foo//bar///baz') == ['/foo/bar/baz']

        comment | 'parent'
        xfiles('/foo/bar/../baz') == ['/foo/baz']

        comment | 'parent twice'
        xfiles('/foo/bar/../../baz') == ['/baz']

        comment | 'parent in two places'
        xfiles('/foo/../bar/../baz') == ['/baz']

        comment | 'non-existing parent'
        xfiles('/foo/../bar/../../baz') == ['/baz']

        comment | 'non-existing parent as root'
        xfiles('/foo/../bar/../../baz/..') == ['/']

        comment | 'parent with empty part'
        xfiles('/foo/bar//..') == ['/foo']

        comment | 'parent to cwd'
        xfiles('../bar/baz') == ['/bar/baz']

        comment | 'current user (assumes typical system setup)'
        xfiles("'~'") == ['/home/' + username]

        comment | 'current user twice'
        xfiles("'~/~'") == ['/home/' + username + '/~']

        comment | 'given user (assumes typical system setup)'
        xfiles("'~" + username + "'") == ['/home/' + username]

        comment | 'home of the root'
        xfiles("'~root'") == ['/root']

        comment | 'tilde in the middle of path'
        xfiles('/foo/bar/~/baz') == ['/foo/bar/~/baz']

        comment | 'tilde at the end of filename'
        xfiles('/foo/bar/baz~') == ['/foo/bar/baz~']

        comment | 'space'
        xfiles("'/foo/bar baz'") == ['/foo/bar baz']

        comment | 'root'
        xfiles('/') == ['/']

        comment | 'mix of the tricks above'
        xfiles(f'~{username}/foo/.././//../bar/~/baz//../.') == ['/home/bar/~']

        comment | 'odd characters, including glob, pipe, period, backslash'
        comment | 'use single quotes on the left to prevent shell from interpreting it'
        xfiles("'/-+=\"/$#@!/*&^|/\\<,>'") == ["/-+=\"/$#@!/*&^|/\\<,>"]

        reset(xfiles, comment)
