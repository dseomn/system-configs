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
"""External authentication helper for ejabberd.

This makes it possible to have multiple passwords per user (up to
--max-passwords-per-user), salted and hashed and stored in a read-only file
(--config).

The format of the file is one password per line. Each line has three columns
separated by colons: username, domain name, and hashed salted password. See
https://docs.python.org/3/library/crypt.html#crypt.crypt for how to generate
values for the last column. For example, if the only user were
alice@example.com and her password were "password", the file might look like:

alice:example.com:$6$wntdG0RUDD9lt304$06Lf2Lrlqn7rgdTc3VL4lFjUOz3AadknDPEmrpWyFr5Jzkv9lQyyRz7mWYJ/ILnBRHfHbori.X4sR9B5DcKB60

This script tries to avoid disclosing information via timing attacks as much as
possible, so --max-passwords-per-user is designed so that (in theory) it should
take the same amount of time to check a password regardless of how many
passwords a user has configured.
"""
# Protocol: https://docs.ejabberd.im/developer/guide/#external
#
# When working on this script, keep these things in mind:
#
# It's fine if misconfiguration causes an exception at startup (but not after
# startup) or if a protocol error causes an exception. However, untrusted input
# (e.g., usernames, server names, or passwords) must not crash the script.
#
# Exception or log messages must not leak passwords or other sensitive
# information, so they generally also shouldn't include any unknown information.
# E.g., "parse error, unexpected bytes b'foo'" could risk leaking sensitive
# information.

import argparse
import collections
from collections.abc import Collection, Iterable, Mapping
import crypt
import enum
import hmac
import pathlib
import struct
import sys

# Map from (user, server) to that user's crypted passwords.
_Config = Mapping[tuple[bytes, bytes], Collection[str]]


def _args():
    parser = argparse.ArgumentParser(
        description='External authentication helper for ejabberd.')
    parser.add_argument(
        '--config',
        type=pathlib.Path,
        required=True,
        help='Absolute path to the authentication config file.',
    )
    parser.add_argument(
        '--max-passwords-per-user',
        default=25,
        type=int,
        help='Max number of passwords per user.',
    )
    return parser.parse_args()


def _config(
    config_path: pathlib.Path,
    *,
    max_passwords_per_user: int,
) -> _Config:
    raw_config = collections.defaultdict(list)
    with config_path.open(mode='rb') as config_file:
        for line in config_file:
            if not line.strip() or line.lstrip().startswith(b'#'):
                continue
            user, server, crypted_password = line.rstrip(b'\n').split(b':')
            raw_config[(user, server)].append(crypted_password.decode('utf-8'))
    # collections.defaultdict makes it easy to accidentally add new keys, which
    # is useful above, but a potential security risk after parsing is done.
    # E.g., if some code did `config[(user, server)]` with untrusted input, that
    # would add an empty list for the untrusted (user, server). If code later
    # tests if a user exists by doing `(user, server) in config`, it would think
    # the user exists. So we convert to dict here to avoid that issue.
    config = {}
    for key, crypted_passwords in raw_config.items():
        if len(crypted_passwords) > max_passwords_per_user:
            raise ValueError(f'{key!r} has too many passwords')
        # Ensure exactly max_passwords_per_user entries by repeating the
        # entries. This makes it harder to figure out how many passwords a user
        # has by measuring how long it takes to test a password.
        config[key] = tuple(crypted_passwords[i % len(crypted_passwords)]
                            for i in range(max_passwords_per_user))
    return config


class _Response(enum.IntEnum):
    FAILURE = 0
    SUCCESS = 1


def _read_operations() -> Iterable[tuple[bytes, bytes]]:
    while True:
        length_bytes = sys.stdin.buffer.read(2)
        if not length_bytes:
            return
        elif len(length_bytes) != 2:
            raise ValueError(f'Expected 2 bytes, got {len(length_bytes)}')
        (length,) = struct.unpack('!H', length_bytes)
        value_bytes = sys.stdin.buffer.read(length)
        if len(value_bytes) != length:
            raise ValueError(f'Expected {length} bytes, got {len(value_bytes)}')
        operation, _, args = value_bytes.partition(b':')
        yield operation, args


def _respond(response: _Response) -> None:
    sys.stdout.buffer.write(struct.pack('!HH', 2, response))
    sys.stdout.buffer.flush()


def _auth(operation_args: bytes, *, config: _Config) -> _Response:
    user, server, password = operation_args.split(b':', maxsplit=2)
    try:
        password_str = password.decode('utf-8')
    except UnicodeDecodeError:
        return _Response.FAILURE
    crypted_passwords = config.get((user, server))
    # This exposes timing information about whether the user exists or not,
    # because I'm not sure if it's even possible to avoid that in the system as
    # a whole <https://github.com/processone/ejabberd/discussions/3679> and all
    # the ways I've thought of to avoid the issue in this script have
    # significant downsides
    # <https://github.com/dseomn/system-configs/pull/2#discussion_r707774632>.
    if crypted_passwords is None:
        return _Response.FAILURE
    password_checks_failure = bytes((False,) * len(crypted_passwords))
    password_checks_actual = bytes(
        hmac.compare_digest(crypt.crypt(password_str, salt=crypted), crypted)
        for crypted in crypted_passwords)
    if hmac.compare_digest(password_checks_failure, password_checks_actual):
        return _Response.FAILURE
    else:
        return _Response.SUCCESS


def _isuser(operation_args: bytes, *, config: _Config) -> _Response:
    user, server = operation_args.split(b':')
    return _Response.SUCCESS if (user, server) in config else _Response.FAILURE


def main() -> None:
    args = _args()
    config = _config(
        args.config,
        max_passwords_per_user=args.max_passwords_per_user,
    )
    for operation, operation_args in _read_operations():
        if operation == b'auth':
            _respond(_auth(operation_args, config=config))
        elif operation == b'isuser':
            _respond(_isuser(operation_args, config=config))
        else:
            _respond(_Response.FAILURE)


if __name__ == '__main__':
    main()
