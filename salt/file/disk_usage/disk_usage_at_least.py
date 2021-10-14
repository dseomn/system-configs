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
import shutil
import subprocess
import sys


def _lvm_pool_usage(*, min_percent):
    if not shutil.which('lvs'):
        return ''
    lvs = subprocess.run(
        (
            'lvs',
            '-S',
            ('lv_layout=pool,'
             f'(data_percent>={min_percent}||metadata_percent>={min_percent})'),
        ),
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    )
    return lvs.stdout


def _filesystem_usage(*, min_percent):
    df = subprocess.run(
        ('df', '-h'),
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    )
    df_lines = df.stdout.splitlines()
    df_header = df_lines[0]
    df_lines_to_print = [
        line for line in df_lines[1:]
        if float(line.split()[4].rstrip('%')) >= min_percent
    ]
    if df_lines_to_print:
        return ''.join(line + '\n' for line in (df_header, *df_lines_to_print))
    else:
        return ''


def main():
    arg_parser = argparse.ArgumentParser(
        description='Conditionally print disk usage.')
    arg_parser.add_argument(
        '--lvm-pool-threshold',
        type=float,
        required=True,
        help='Minimum usage percent to print for LVM pools.',
    )
    arg_parser.add_argument(
        '--fs-threshold',
        type=float,
        required=True,
        help='Minimum usage percent to print for filesystems.',
    )
    args = arg_parser.parse_args()

    sections = (
        _lvm_pool_usage(min_percent=args.lvm_pool_threshold),
        _filesystem_usage(min_percent=args.fs_threshold),
    )
    sys.stdout.write('\n'.join(section for section in sections if section))


if __name__ == '__main__':
    main()
