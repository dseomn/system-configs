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

import argparse
import datetime
import json
import pprint
import subprocess
import sys


def _args():
    parser = argparse.ArgumentParser(
        description='Print a message if the latest archive is too old.')
    parser.add_argument(
        '--repository',
        type=str,
        required=True,
        help='Repository to check.',
    )
    parser.add_argument(
        '--max-age',
        default=datetime.timedelta(days=2, hours=12),
        type=lambda arg: datetime.timedelta(seconds=float(arg)),
        help='How old to warn about, in seconds.',
    )
    parser.add_argument(
        'borg_option',
        nargs='*',
        default=[],
        type=str,
        help='Borg common options.',
    )
    return parser.parse_args()


def main() -> None:
    args = _args()
    # TODO(borg >= 1.2): Once `borg list` supports --consider-checkpoints, make
    # sure checkpoints aren't listed, get rid of logic to ignore checkpoints,
    # and use --last instead of manually limiting the number of archives shown.
    repository_list_raw = subprocess.run(
        (
            'borg',
            *args.borg_option,
            'list',
            '--json',
            args.repository,
        ),
        stdout=subprocess.PIPE,
        check=True,
    ).stdout
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    repository_list = json.loads(repository_list_raw)
    archives = tuple(archive for archive in repository_list['archives']
                     if not archive['archive'].endswith('.checkpoint'))
    if not archives:
        print('No archives.')
        return
    last_archive_time = datetime.datetime.fromisoformat(
        archives[-1]['start']).astimezone(datetime.timezone.utc)
    if last_archive_time < now - args.max_age:
        print(f'Latest archive is older than {args.max_age}. Recent archives:')
        pprint.pprint(archives[-5:])
        return


if __name__ == '__main__':
    main()
