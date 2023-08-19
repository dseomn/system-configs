# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from collections.abc import Generator
import contextlib
import crypt
import pathlib
import subprocess
import sys
import tempfile
from typing import IO
import unittest


class EjabberdAuthenticationTest(unittest.TestCase):

    @contextlib.contextmanager
    def _main(
        self,
        *,
        config: str = '',
        max_passwords_per_user: int = 25,
    ) -> Generator[tuple[IO[bytes], IO[bytes]], None, None]:
        """Runs the main program, yielding its (stdin, stdout)."""
        with tempfile.NamedTemporaryFile(mode='w+t') as config_file:
            config_file.write(config)
            config_file.flush()
            main = subprocess.Popen(
                (
                    sys.executable,
                    str(
                        pathlib.Path(__file__).parent.joinpath(
                            'ejabberd_authentication.py')),
                    f'--config={config_file.name}',
                    f'--max-passwords-per-user={max_passwords_per_user}',
                ),
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            yield main.stdin, main.stdout
            main.wait()
        stdout = main.stdout.read()
        main.stdout.close()
        stderr = main.stderr.read()
        main.stderr.close()
        if main.returncode != 0 or stdout or stderr:
            raise RuntimeError(
                f'Main returned {main.returncode} with unread stdout '
                f'{stdout!r} and stderr:\n{stderr.decode()}')

    def _assert_failure(self, stdout: IO[bytes]) -> None:
        self.assertEqual(b'\x00\x02\x00\x00', stdout.read(4))

    def _assert_success(self, stdout: IO[bytes]) -> None:
        self.assertEqual(b'\x00\x02\x00\x01', stdout.read(4))

    def test_ignores_whitespace_and_comment_lines(self):
        with self._main(config=('\n'
                                ' \t\n'
                                '# this is a comment\n'
                                ' \t# also a comment\n'
                                'alice:example.com:!\n')) as (stdin, stdout):
            stdin.write(b'\x00\x18isuser:alice:example.com')
            stdin.close()
            self._assert_success(stdout)

    def test_too_many_passwords_error(self):
        with self.assertRaisesRegex(RuntimeError, 'has too many passwords'):
            with self._main(
                    config='alice:example.com:!\n' * 3,
                    max_passwords_per_user=2,
            ) as (stdin, _):
                stdin.close()

    def test_incomplete_length_error(self):
        with self.assertRaisesRegex(RuntimeError, 'Expected 2 bytes, got 1'):
            with self._main() as (stdin, _):
                stdin.write(b'\x00')
                stdin.close()

    def test_incomplete_value_error(self):
        with self.assertRaisesRegex(RuntimeError, 'Expected 3 bytes, got 2'):
            with self._main() as (stdin, _):
                stdin.write(b'\x00\x03fo')
                stdin.close()

    def test_auth_wrong_arg_count_error(self):
        with self.assertRaisesRegex(RuntimeError,
                                    r'values to unpack \(expected 3, got 1\)'):
            with self._main() as (stdin, _):
                stdin.write(b'\x00\x08auth:foo')
                stdin.close()

    def test_auth_not_unicode_failure(self):
        with self._main(config='alice:example.com:!\n') as (stdin, stdout):
            stdin.write(b'\x00\x18auth:alice:example.com:\xff')
            stdin.close()
            self._assert_failure(stdout)

    def test_auth_not_a_user_failure(self):
        with self._main() as (stdin, stdout):
            stdin.write(b'\x00\x1aauth:alice:example.com:foo')
            stdin.close()
            self._assert_failure(stdout)

    def test_auth_wrong_password_failure(self):
        with self._main(
                config=(f'alice:example.com:{crypt.crypt("foo")}\n'
                        f'bob:example.com:{crypt.crypt("bar")}\n'),  #
        ) as (stdin, stdout):
            stdin.write(b'\x00\x18auth:bob:example.com:foo')
            stdin.close()
            self._assert_failure(stdout)

    def test_auth_success(self):
        with self._main(
                config=(f'alice:example.com:{crypt.crypt("bar")}\n'
                        f'alice:example.com:{crypt.crypt("foo")}\n'),  #
        ) as (stdin, stdout):
            stdin.write(b'\x00\x1aauth:alice:example.com:foo')
            stdin.close()
            self._assert_success(stdout)

    def test_auth_success_colon_in_password(self):
        # https://github.com/processone/ejabberd/issues/3677
        with self._main(
                config=f'alice:example.com:{crypt.crypt("foo:bar")}\n',  #
        ) as (stdin, stdout):
            stdin.write(b'\x00\x1eauth:alice:example.com:foo:bar')
            stdin.close()
            self._assert_success(stdout)

    def test_isuser_wrong_arg_count_error(self):
        with self.assertRaisesRegex(RuntimeError,
                                    r'values to unpack \(expected 2, got 1\)'):
            with self._main() as (stdin, _):
                stdin.write(b'\x00\x0aisuser:foo')
                stdin.close()

    def test_isuser_success(self):
        with self._main(config='alice:example.com:!\n') as (stdin, stdout):
            stdin.write(b'\x00\x18isuser:alice:example.com')
            stdin.close()
            self._assert_success(stdout)

    def test_isuser_failure(self):
        with self._main() as (stdin, stdout):
            stdin.write(b'\x00\x18isuser:alice:example.com')
            stdin.close()
            self._assert_failure(stdout)

    def test_empty_value_failure(self):
        with self._main() as (stdin, stdout):
            stdin.write(b'\x00\x00')
            stdin.close()
            self._assert_failure(stdout)

    def test_unknown_operation_failure(self):
        with self._main() as (stdin, stdout):
            stdin.write(b'\x00\x03foo')
            stdin.close()
            self._assert_failure(stdout)


if __name__ == '__main__':
    unittest.main()
