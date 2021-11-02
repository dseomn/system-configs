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
"""Dump data from ejabberd.

Much of the complexity here comes from working around PrivateTmp=true in
ejabberd.service.
"""

import contextlib
import os
import shutil
import subprocess
from typing import ContextManager, Sequence


def _wait_and_check(popen: subprocess.Popen) -> None:
    if popen.wait() != 0:
        raise subprocess.CalledProcessError(returncode=popen.returncode,
                                            cmd=popen.args)


def _service_property(name: str) -> str:
    return subprocess.run(
        (
            'systemctl',
            'show',
            f'--property={name}',
            '--value',
            'ejabberd.service',
        ),
        stdout=subprocess.PIPE,
        check=True,
        text=True,
    ).stdout.rstrip()


def _nsenter() -> Sequence[str]:
    pid = _service_property('MainPID')
    uid = _service_property('UID')
    gid = _service_property('GID')
    if pid == '0' or uid == '[not set]' or gid == '[not set]':
        raise RuntimeError('ejabberd is not running')
    return (
        'nsenter',
        f'--target={pid}',
        '--mount',
        f'--setuid={uid}',
        f'--setgid={gid}',
        '--',
    )


@contextlib.contextmanager
def _ejabberd_tempfile(
    *,
    nsenter: Sequence[str],
    copy_to: str,
) -> ContextManager[str]:
    with contextlib.ExitStack() as exit_stack:
        tempfile_ = subprocess.run(
            (*nsenter, 'mktemp'),
            stdout=subprocess.PIPE,
            check=True,
            text=True,
        ).stdout.rstrip()
        exit_stack.callback(
            subprocess.run,
            (*nsenter, 'rm', tempfile_),
            check=True,
        )
        yield tempfile_
        cat = subprocess.Popen(
            (*nsenter, 'cat', tempfile_),
            stdout=subprocess.PIPE,
        )
        with open(copy_to, mode='xb') as copy_to_file:
            shutil.copyfileobj(cat.stdout, copy_to_file)
        _wait_and_check(cat)


@contextlib.contextmanager
def _ejabberd_tempdir(
    *,
    nsenter: Sequence[str],
    copy_to: str,
) -> ContextManager[str]:
    with contextlib.ExitStack() as exit_stack:
        tempdir = subprocess.run(
            (*nsenter, 'mktemp', '-d'),
            stdout=subprocess.PIPE,
            check=True,
            text=True,
        ).stdout.rstrip()
        exit_stack.callback(
            subprocess.run,
            (*nsenter, 'rm', '-rf', tempdir),
            check=True,
        )
        yield tempdir
        tar_create = subprocess.Popen(
            (
                *nsenter,
                'tar',
                '--create',
                '--file=-',
                f'--directory={tempdir}',
                '.',
            ),
            stdout=subprocess.PIPE,
        )
        # TODO(https://bugs.python.org/issue21109): Use tarfile.
        os.mkdir(copy_to)
        tar_extract = subprocess.Popen(
            (
                'tar',
                '--extract',
                '--file=-',
                f'--directory={copy_to}',
            ),
            stdin=subprocess.PIPE,
        )
        shutil.copyfileobj(tar_create.stdout, tar_extract.stdin)
        _wait_and_check(tar_create)
        _wait_and_check(tar_extract)


def main() -> None:
    nsenter = _nsenter()
    with _ejabberd_tempfile(nsenter=nsenter,
                            copy_to='ejabberd.dump') as dump_filename:
        subprocess.run(('ejabberdctl', 'dump', dump_filename), check=True)
    # NOTE: This doesn't actually generate useful data, see
    # https://github.com/processone/ejabberd/issues/3705
    with _ejabberd_tempdir(nsenter=nsenter,
                           copy_to='ejabberd.piefxis') as dump_dirname:
        subprocess.run(('ejabberdctl', 'export_piefxis', dump_dirname),
                       check=True)


if __name__ == '__main__':
    main()
