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
from collections.abc import Sequence
import os
import pathlib
import subprocess
import tempfile
import uuid


def _args():
    parser = argparse.ArgumentParser(
        description='Generate dynamic parts of lemonldap-ng.ini.')
    parser.add_argument(
        '--input',
        type=pathlib.Path,
        required=True,
        help='Path to the static lemonldap-ng.ini to read.',
    )
    parser.add_argument(
        '--output',
        type=pathlib.Path,
        required=True,
        help='Path to the dynamic lemonldap-ng.ini to replace.',
    )
    return parser.parse_args()


def _portal_lines() -> Sequence[str]:
    # https://lemonldap-ng.org/documentation/latest/openidconnectservice.html#key-rotation-script
    # mentions a script to rotate keys, but it looks like it doesn't work with
    # configuration type=Local. This tries to do something similar with Local
    # config.
    #
    # TODO(https://gitlab.ow2.org/lemonldap-ng/lemonldap-ng/-/issues/810): Use
    # parameters from salt/file/crypto/map.jinja and change the signature
    # algorithms in the static part of the config file to match.
    private_key = subprocess.run(
        (
            'openssl',
            'genpkey',
            '-algorithm',
            'RSA',
            '-pkeyopt',
            'rsa_keygen_bits:3072',
        ),
        stdout=subprocess.PIPE,
        # See https://github.com/openssl/openssl/issues/13177
        stderr=subprocess.DEVNULL,
        check=True,
        text=True,
    ).stdout
    public_key = subprocess.run(
        ('openssl', 'pkey', '-pubout'),
        input=private_key,
        stdout=subprocess.PIPE,
        check=True,
        text=True,
    ).stdout
    key_id = str(uuid.uuid4())
    return (
        'oidcServicePrivateKeySig = <<EOF\n',
        private_key,
        'EOF\n',
        'oidcServicePublicKeySig = <<EOF\n',
        public_key,
        'EOF\n',
        f'oidcServiceKeyIdSig = {key_id}\n',
    )


def main() -> None:
    args = _args()
    with args.input.open('rt') as input_file:
        config = list(input_file)
    portal_index = config.index('[portal]\n')
    config[portal_index + 1:portal_index + 1] = _portal_lines()
    with tempfile.NamedTemporaryFile(
            mode='wt',
            dir=args.output.parent,
            delete=False,
    ) as output_tempfile:
        output_tempfile.writelines(config)
    input_stat = args.input.stat()
    os.chown(output_tempfile.name, uid=input_stat.st_uid, gid=input_stat.st_gid)
    os.chmod(output_tempfile.name, input_stat.st_mode)
    os.replace(output_tempfile.name, args.output)


if __name__ == '__main__':
    main()
