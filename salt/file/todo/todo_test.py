# Copyright 2022 Google LLC
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

import json
import subprocess
from unittest import mock

from absl.testing import absltest
from absl.testing import parameterized

import todo


class TodoTest(parameterized.TestCase):

    def setUp(self):
        super().setUp()
        self._subprocess_run = mock.create_autospec(subprocess.run,
                                                    spec_set=True)

    def _main(
        self,
        *,
        config: ...,
        state: ... = None,
        max_occurrences: int = 10,
    ) ->...:
        tempdir = self.create_tempdir()
        if config is not None:
            tempdir.create_file('config', json.dumps(config))
        if state is not None:
            tempdir.create_file('state', json.dumps(state))
        todo.main(
            (
                f'--config={tempdir.full_path}/config',
                f'--state={tempdir.full_path}/state',
                f'--max-occurrences={max_occurrences}',
            ),
            subprocess_run=self._subprocess_run,
        )
        with open(f'{tempdir.full_path}/state', mode='rb') as state_file:
            return json.load(state_file)

    def test_config_missing(self):
        with self.assertRaises(FileNotFoundError):
            self._main(config=None)

    def test_config_unexpected_group_key(self):
        with self.assertRaisesRegex(ValueError,
                                    'Unexpected group config keys:.*kumquat'):
            self._main(config=dict(some_group=dict(todos={}, kumquat={})))

    def test_config_missing_required_fields(self):
        with self.assertRaisesRegex(TypeError, 'summary'):
            self._main(config=dict(some_group=dict(todos=dict(some_todo={}))))

    def test_config_unexpected_key(self):
        with self.assertRaisesRegex(TypeError, 'kumquat'):
            self._main(config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='bar@example.com',
                summary='foo',
                kumquat='',
            )))))

    def test_state_unexpected_key(self):
        with self.assertRaisesRegex(TypeError, 'kumquat'):
            self._main(config={}, state=dict(some_todo=dict(kumquat='')))


if __name__ == '__main__':
    absltest.main()
