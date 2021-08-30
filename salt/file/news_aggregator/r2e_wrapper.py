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
"""Wrapper around r2e.

`r2e run` attempts to overwrite its config file; this prevents that. It also
sets the config and data flags.
"""

import os
import shutil
import subprocess
import sys
import tempfile

_CONFIG = '/etc/rss2email.cfg'
_DATA = '/srv/rss2email/data/rss2email.json'


def main():
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_config = os.path.join(temp_dir, 'rss2email.cfg')
        shutil.copyfile(_CONFIG, temp_config)
        return subprocess.run((
            'r2e',
            f'--config={temp_config}',
            f'--data={_DATA}',
            *sys.argv[1:],
        )).returncode


if __name__ == '__main__':
    sys.exit(main())
