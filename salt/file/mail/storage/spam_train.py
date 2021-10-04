#!/usr/bin/env python3

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
"""Runs sa-learn for all of a specific user's folders.

This tries to avoid putting potentially sensitive information (e.g., email
addresses and folder names) in command lines, since other users on the system
can read those.
"""

from collections.abc import Collection
import os
import pathlib
import subprocess
import tempfile

_SPAM_FOLDERS = ('.Junk',)
_FORGET_FOLDERS = (
    '.Archive',
    '.Drafts',
    '.Sent',
    '.Trash',
)


def _is_inclusive_subfolder(name: str, tests: Collection[str]) -> bool:
    return name in tests or name.startswith(tuple(f'{test}.' for test in tests))


def _sa_learn(
    temp_path: pathlib.Path,
    type_arg: str,
    folder: pathlib.Path,
    *,
    sync: bool = False,
) -> None:
    folder_safe = temp_path.joinpath('mail')
    folder_safe.symlink_to(folder)
    subprocess.run(
        (
            'sa-learn',
            '--quiet',
            f'--dbpath={temp_path}/spamassassin/bayes',
            *(() if sync else ('--no-sync',)),
            type_arg,
            f'{folder_safe}/cur',
        ),
        check=True,
    )
    folder_safe.unlink()


def main() -> None:
    user_dir = pathlib.Path(os.environ['USER_DIR'])
    maildir = pathlib.Path(os.environ['MAILDIR'])
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = pathlib.Path(temp_dir)
        temp_path.joinpath('spamassassin').symlink_to(user_dir)
        _sa_learn(temp_path, '--ham', maildir)
        for subdir in maildir.iterdir():
            if _is_inclusive_subfolder(subdir.name, _SPAM_FOLDERS):
                _sa_learn(temp_path, '--spam', subdir)
            elif _is_inclusive_subfolder(subdir.name, _FORGET_FOLDERS):
                _sa_learn(temp_path, '--forget', subdir, sync=True)
            elif subdir.name.startswith('.'):
                _sa_learn(temp_path, '--ham', subdir)
        subprocess.run(
            (
                'sa-learn',
                '--quiet',
                f'--dbpath={temp_path}/spamassassin/bayes',
                '--sync',
            ),
            check=True,
        )


if __name__ == '__main__':
    main()
