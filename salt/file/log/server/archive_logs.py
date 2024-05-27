#!/usr/bin/env python3

# Copyright 2024 Google LLC
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
"""Compresses and moves logs from current/ to archive/."""

import datetime
import logging
import pathlib
import re
import shutil
import stat
import subprocess
import sys

_CURRENT = pathlib.Path("/srv/logs/current")
_ARCHIVE = pathlib.Path("/srv/logs/archive")

_ARCHIVE_MODE = 0o440
_ARCHIVE_USER = "root"
_ARCHIVE_GROUP = "adm"

# How long to wait before archiving logs, in case syslog-ng is still catching
# up, or the clock moves backwards.
_GRACE_PERIOD = datetime.timedelta(hours=4)


def _process_file(
    log_path: pathlib.Path,
    *,
    archive_before_date: datetime.date,
):
    if log_path.suffix != ".log":
        raise ValueError(f"Unexpected non-.log file: {str(log_path)!r}")
    match = re.search(
        r"^(?P<year>[0-9]{4})-(?P<month>[0-9]{2})-(?P<day>[0-9]{2})\.",
        log_path.name,
    )
    if match is None:
        raise ValueError(f"Unknown filename format: {str(log_path)!r}")
    log_date = datetime.date(*map(int, match.group("year", "month", "day")))
    if log_date >= archive_before_date:
        return
    subprocess.run(("xz", "--", str(log_path)), check=True)
    archive_path = _ARCHIVE / (log_path.name + ".xz")
    # TODO(https://github.com/python/cpython/issues/56950): Do this in
    # python.
    subprocess.run(
        (
            "mv",
            "--no-clobber",
            "--no-target-directory",
            "--",
            f"{log_path}.xz",
            str(archive_path),
        ),
        check=True,
    )
    archive_path.chmod(_ARCHIVE_MODE)
    shutil.chown(archive_path, user=_ARCHIVE_USER, group=_ARCHIVE_GROUP)


def main():
    exitcode = 0
    archive_before_date = (
        datetime.datetime.now(tz=datetime.timezone.utc) - _GRACE_PERIOD
    ).date()
    for log_path in tuple(_CURRENT.iterdir()):
        try:
            _process_file(log_path, archive_before_date=archive_before_date)
        except Exception:
            exitcode = 1
            logging.exception("Couldn't process %r", str(log_path))
    for log_path in _ARCHIVE.iterdir():
        mode = log_path.stat().st_mode
        user = log_path.owner()
        group = log_path.group()
        if (
            mode != _ARCHIVE_MODE | stat.S_IFREG
            or user != _ARCHIVE_USER
            or group != _ARCHIVE_GROUP
        ):
            exitcode = 1
            logging.warning("File has wrong mode/owners: %r", str(log_path))
    return exitcode


if __name__ == "__main__":
    sys.exit(main())
