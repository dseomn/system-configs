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
    type_arg: str,
    folder: pathlib.Path,
    *,
    dbpath: pathlib.Path,
) -> None:
    subprocess.run(
        (
            'sa-learn',
            '--quiet',
            f'--dbpath={dbpath}',
            type_arg,
            'cur',
        ),
        cwd=folder,
        check=True,
    )


def main() -> None:
    user_dir = pathlib.Path(os.environ['USER_DIR'])
    maildir = pathlib.Path(os.environ['MAILDIR'])
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = pathlib.Path(temp_dir)
        temp_path.joinpath('spamassassin').symlink_to(user_dir)
        dbpath = temp_path.joinpath('spamassassin').joinpath('bayes')
        _sa_learn('--ham', maildir, dbpath=dbpath)
        for subdir in maildir.iterdir():
            if _is_inclusive_subfolder(subdir.name, _SPAM_FOLDERS):
                _sa_learn('--spam', subdir, dbpath=dbpath)
            elif _is_inclusive_subfolder(subdir.name, _FORGET_FOLDERS):
                _sa_learn('--forget', subdir, dbpath=dbpath)
            elif subdir.name.startswith('.'):
                _sa_learn('--ham', subdir, dbpath=dbpath)
        subprocess.run(
            (
                'sa-learn',
                '--quiet',
                f'--dbpath={dbpath}',
                '--force-expire',
            ),
            check=True,
        )


if __name__ == '__main__':
    main()
