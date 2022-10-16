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

from collections.abc import Mapping, Sequence
import dataclasses
import email.parser
import email.policy
import json
import subprocess
import textwrap
from typing import Optional, Type
from unittest import mock

from absl.testing import absltest
from absl.testing import parameterized
import freezegun

import todo


@dataclasses.dataclass(frozen=True)
class _MessagePart:
    filename: Optional[str]
    content: str


@dataclasses.dataclass(frozen=True)
class _Message:
    headers: Mapping[str, Sequence[str]]
    parts: Sequence[_MessagePart]


class TodoTest(parameterized.TestCase):

    def setUp(self):
        super().setUp()
        self._subprocess_run = mock.create_autospec(subprocess.run,
                                                    spec_set=True)
        self._email_parser = email.parser.BytesParser(
            policy=email.policy.default)

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

    def _assert_messages_sent(self, *expected_messages: _Message):
        self.assertLen(self._subprocess_run.mock_calls, len(expected_messages))
        for run_call, expected_message in zip(self._subprocess_run.mock_calls,
                                              expected_messages):
            self.assertEqual(
                mock.call(('/usr/sbin/sendmail', '-i', '-t'),
                          check=True,
                          input=mock.ANY),
                run_call,
            )
            actual_message = self._email_parser.parsebytes(
                run_call.kwargs['input'])
            self.assertEqual(
                {
                    header: tuple(values)
                    for header, values in expected_message.headers.items()
                },
                {
                    header: tuple(actual_message.get_all(header, ()))
                    for header in expected_message.headers
                },
            )
            if expected_message.parts:
                self.assertEqual('multipart/mixed',
                                 actual_message.get_content_type())
                actual_parts = tuple(actual_message.iter_parts())
                self.assertLen(actual_parts, len(expected_message.parts))
                for actual_part, expected_part in zip(actual_parts,
                                                      expected_message.parts):
                    self.assertEqual('text/plain',
                                     actual_part.get_content_type())
                    self.assertEqual('inline',
                                     actual_part.get_content_disposition())
                    self.assertEqual(expected_part.filename,
                                     actual_part.get_filename())
                    self.assertEqual(expected_part.content,
                                     actual_part.get_content())
            else:
                self.assertEmpty(actual_message.get_content())

    @parameterized.named_parameters(
        dict(
            testcase_name='config_missing',
            config=None,
            error_class=FileNotFoundError,
        ),
        dict(
            testcase_name='config_unexpected_group_key',
            config=dict(some_group=dict(todos={}, kumquat={})),
            error_class=ValueError,
            error_regex='Unexpected group config keys:.*kumquat',
        ),
        dict(
            testcase_name='config_missing_required_fields',
            config=dict(some_group=dict(todos=dict(some_todo={}))),
            error_class=TypeError,
            error_regex='summary',
        ),
        dict(
            testcase_name='config_unexpected_key',
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='bar@example.com',
                summary='foo',
                kumquat='',
            )))),
            error_class=TypeError,
            error_regex='kumquat',
        ),
        dict(
            testcase_name='state_unexpected_key',
            config={},
            state=dict(some_todo=dict(kumquat='')),
            error_class=TypeError,
            error_regex='kumquat',
        ),
        dict(
            testcase_name='time_has_gone_backwards',
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='foo',
                start='20000101T000000Z',
            )))),
            state={'some_group.some_todo': dict(last_sent='20010101T000000Z')},
            error_class=RuntimeError,
            error_regex='in the future',
        ),
    )
    @freezegun.freeze_time('2000-01-01')
    def test_error(
        self,
        *,
        config: ...,
        state: ... = None,
        error_class: Type[Exception],
        error_regex: str = '',
    ):
        with self.assertRaisesRegex(error_class, error_regex):
            self._main(config=config, state=state)

    @parameterized.named_parameters(
        dict(
            testcase_name='uses_default',
            group_extra=dict(defaults=dict(email_to='alice@example.com')),
            todo_extra={},
        ),
        dict(
            testcase_name='overrides_default',
            group_extra=dict(defaults=dict(email_to='bob@example.com')),
            todo_extra=dict(email_to='alice@example.com'),
        ),
    )
    @freezegun.freeze_time('2000-01-01')
    def test_config_defaults(self, group_extra: ..., todo_extra: ...):
        self._main(config=dict(some_group=dict(
            **group_extra,
            todos=dict(some_todo=dict(
                **todo_extra,
                summary='apple',
                start='20000101T000000Z',
            )),
        )))

        self._assert_messages_sent(
            _Message(headers={'To': ('alice@example.com',)}, parts=()))

    @parameterized.named_parameters(
        dict(
            testcase_name='empty_config_no_state',
            initial_state=None,
            config={},
        ),
        dict(
            testcase_name='irrelevant_state',
            initial_state={'unknown-todo': dict(last_sent='20010203T010203Z')},
            config={},
        ),
        dict(
            testcase_name='start_in_future',
            initial_state={'some_group.some_todo': dict(last_sent=None)},
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='foo',
                start='20010101T000000Z',
            )))),
        ),
        dict(
            testcase_name='start_in_future_but_previously_sent',
            initial_state={
                'some_group.some_todo': dict(last_sent='19990101T000000Z'),
            },
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='foo',
                start='20010101T000000Z',
            )))),
        ),
        dict(
            testcase_name='one_time_todo_already_sent',
            initial_state={
                'some_group.some_todo': dict(last_sent='19990101T000000Z'),
            },
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='foo',
                start='19990101T000000Z',
            )))),
        ),
        dict(
            testcase_name='between_occurrences',
            initial_state={
                'some_group.some_todo': dict(last_sent='19991231T120000Z'),
            },
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='apple',
                start='19990101T120000Z',
                recurrence_rule='FREQ=DAILY',
            )))),
        ))
    @freezegun.freeze_time('2000-01-01')
    def test_nothing_to_send(
        self,
        initial_state: ...,
        config: ...,
    ):
        new_state = self._main(config=config, state=initial_state)

        self._subprocess_run.assert_not_called()
        self.assertEqual({} if initial_state is None else initial_state,
                         new_state)

    @parameterized.product(
        (
            dict(description=None, expected_parts=()),
            dict(
                description='orange',
                expected_parts=(_MessagePart(filename=None,
                                             content='orange\n'),),
            ),
        ),
        (
            dict(timezone='UTC', start='20000101T000000Z'),
            dict(timezone='America/New_York', start='19991231T000000'),
        ),
        last_sent=(None, '19990101T000000Z'),
    )
    @freezegun.freeze_time('2000-01-01')
    def test_sends_one_time_todo(
        self,
        last_sent: Optional[str],
        timezone: str,
        start: str,
        description: Optional[str],
        expected_parts: Sequence[_MessagePart],
    ):
        new_state = self._main(
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='apple',
                description=description,
                timezone=timezone,
                start=start,
            )))),
            state={'some_group.some_todo': dict(last_sent=last_sent)},
        )

        self._assert_messages_sent(
            _Message(
                headers={
                    'To': ('alice@example.com',),
                    'Subject': ('apple',),
                    'Todo-Id': ('some_group.some_todo',),
                    'Todo-Summary': ('apple',),
                    'Todo-Timezone': (timezone,),
                    'Todo-Start': (start,),
                    'Todo-Recurrence-Rule': (),
                },
                parts=expected_parts,
            ))
        self.assertEqual(
            {'some_group.some_todo': dict(last_sent='20000101T000000Z')},
            new_state,
        )

    @parameterized.named_parameters(
        dict(
            testcase_name='one_at_start',
            start='20000101T000000',
            last_sent=None,
            expected_subject='apple',
            expected_extra_info=textwrap.dedent("""\
                Occurrences included in this email:
                2000-01-01 00:00:00-05:00

                Next occurrences:
                2000-01-02 00:00:00-05:00
                2000-01-03 00:00:00-05:00
                2000-01-04 00:00:00-05:00
                ...
            """),
        ),
        dict(
            testcase_name='one_after_last_sent',
            start='19990101T000000',
            last_sent='19991231T120000Z',
            expected_subject='apple',
            expected_extra_info=textwrap.dedent("""\
                Occurrences included in this email:
                2000-01-01 00:00:00-05:00

                Next occurrences:
                2000-01-02 00:00:00-05:00
                2000-01-03 00:00:00-05:00
                2000-01-04 00:00:00-05:00
                ...
            """),
        ),
        dict(
            testcase_name='more_than_max',
            start='19990101T000000',
            last_sent=None,
            expected_subject='apple (x3+)',
            expected_extra_info=textwrap.dedent("""\
                Occurrences included in this email:
                1999-01-01 00:00:00-05:00
                1999-01-02 00:00:00-05:00
                1999-01-03 00:00:00-05:00
                ...

                Next occurrences:
                2000-01-02 00:00:00-05:00
                2000-01-03 00:00:00-05:00
                2000-01-04 00:00:00-05:00
                ...
            """),
        ),
        dict(
            testcase_name='max',
            start='19991230T000000',
            last_sent=None,
            expected_subject='apple (x3)',
            expected_extra_info=textwrap.dedent("""\
                Occurrences included in this email:
                1999-12-30 00:00:00-05:00
                1999-12-31 00:00:00-05:00
                2000-01-01 00:00:00-05:00

                Next occurrences:
                2000-01-02 00:00:00-05:00
                2000-01-03 00:00:00-05:00
                2000-01-04 00:00:00-05:00
                ...
            """),
        ),
    )
    @freezegun.freeze_time('2000-01-01 12:00:00')
    def test_sends_recurring_todo(
        self,
        start: str,
        last_sent: Optional[str],
        expected_subject: str,
        expected_extra_info: str,
    ):
        new_state = self._main(
            config=dict(some_group=dict(todos=dict(some_todo=dict(
                email_to='alice@example.com',
                summary='apple',
                timezone='America/New_York',
                start=start,
                recurrence_rule='FREQ=DAILY',
            )))),
            state={'some_group.some_todo': dict(last_sent=last_sent)},
            max_occurrences=3,
        )

        self._assert_messages_sent(
            _Message(
                headers={
                    'To': ('alice@example.com',),
                    'Subject': (expected_subject,),
                    'Todo-Id': ('some_group.some_todo',),
                    'Todo-Summary': ('apple',),
                    'Todo-Timezone': ('America/New_York',),
                    'Todo-Start': (start,),
                    'Todo-Recurrence-Rule': ('FREQ=DAILY',),
                },
                parts=(_MessagePart(
                    filename='extra-information',
                    content=expected_extra_info,
                ),),
            ))
        self.assertEqual(
            {'some_group.some_todo': dict(last_sent='20000101T120000Z')},
            new_state,
        )


if __name__ == '__main__':
    absltest.main()
