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
import os
import pathlib
import secrets
import shutil
import tempfile
import textwrap


def _args():
    parser = argparse.ArgumentParser(
        description='Generate dynamic parts of Roundcube config.')
    parser.add_argument(
        '--key-bits',
        type=int,
        required=True,
        help="Number of random bits in $config['des_key']",
    )
    parser.add_argument(
        '--cipher-method',
        type=str,
        required=True,
        help="Value for $config['cipher_method']",
    )
    parser.add_argument(
        '--group',
        type=str,
        required=True,
        help='Group that should be able to read the dynamic config file.',
    )
    parser.add_argument(
        '--output',
        type=pathlib.Path,
        required=True,
        help='Path to the dynamic config file to write.',
    )
    return parser.parse_args()


def main() -> None:
    args = _args()
    key = secrets.token_bytes(nbytes=args.key_bits // 8)
    key_php_escaped = ''.join(f'\\x{byte:02x}' for byte in key)
    with tempfile.NamedTemporaryFile(
            mode='wt',
            dir=args.output.parent,
            delete=False,
    ) as output_tempfile:
        output_tempfile.write(
            textwrap.dedent(f"""\
                <?php
                $config['des_key'] = "{key_php_escaped}";
                $config['cipher_method'] = '{args.cipher_method}';
            """))
    shutil.chown(output_tempfile.name, group=args.group)
    os.chmod(output_tempfile.name, 0o640)
    os.replace(output_tempfile.name, args.output)


if __name__ == '__main__':
    main()
