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
import subprocess


def main():
    arg_parser = argparse.ArgumentParser(
        description='Conditionally print disk usage.')
    arg_parser.add_argument(
        'min_percent',
        type=float,
        help='Only print disk usage at or above this percent.',
    )
    args = arg_parser.parse_args()

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
        if float(line.split()[4].rstrip('%')) >= args.min_percent
    ]
    if not df_lines_to_print:
        return

    print(df_header)
    for line in df_lines_to_print:
        print(line)


if __name__ == '__main__':
    main()
