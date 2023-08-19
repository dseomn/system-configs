#!/usr/bin/env python3

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
"""Sends scheduled TODO emails."""

import argparse
import collections
from collections.abc import Mapping, Sequence
import dataclasses
import datetime
import email.message
import itertools
import json
import os
import pathlib
import subprocess
import sys
import tempfile
from typing import Optional

import dateutil.parser
import dateutil.rrule
import dateutil.tz
import dateutil.utils


@dataclasses.dataclass
class _TodoConfig:
    """Config for a single TODO.

    Attributes:
        email_headers: Headers to add to the email. This should include
            To/Cc/etc. header(s) which determine where the message is sent.
        summary: See
            https://datatracker.ietf.org/doc/html/rfc5545#section-3.8.1.12
        start: See https://datatracker.ietf.org/doc/html/rfc5545#section-3.8.2.4
        start_parsed: See above.
        description: See
            https://datatracker.ietf.org/doc/html/rfc5545#section-3.8.1.5
        timezone: Time zone for any datetimes that don't specify one.
        timezone_parsed: See above.
        recurrence_rule: See
            https://datatracker.ietf.org/doc/html/rfc5545#section-3.8.5.3
        recurrence_rule_parsed: See above.
    """
    email_headers: Mapping[str, str]
    summary: str
    start: str
    start_parsed: datetime.datetime = dataclasses.field(init=False)
    description: Optional[str] = None
    timezone: str = 'UTC'
    timezone_parsed: datetime.tzinfo = dataclasses.field(init=False)
    recurrence_rule: Optional[str] = None
    recurrence_rule_parsed: Optional[dateutil.rrule.rrule] = dataclasses.field(
        init=False)

    def __post_init__(self):
        timezone_parsed = dateutil.tz.gettz(self.timezone)
        if timezone_parsed is None:
            # See https://github.com/dateutil/dateutil/issues/1237 for why this
            # is an `is None` check instead of try/except.
            raise ValueError(f'Invalid timezone {self.timezone!r}')
        self.timezone_parsed = timezone_parsed
        try:
            self.start_parsed = dateutil.utils.default_tzinfo(
                dateutil.parser.isoparse(self.start), self.timezone_parsed)
        except ValueError as e:
            raise ValueError(f'Invalid start {self.start!r}') from e
        try:
            recurrence_rule_parsed = (  #
                None if self.recurrence_rule is None else
                dateutil.rrule.rrulestr(self.recurrence_rule,
                                        dtstart=self.start_parsed))
        except ValueError as e:
            raise ValueError(
                f'Invalid recurrence_rule {self.recurrence_rule!r}') from e
        if isinstance(recurrence_rule_parsed, dateutil.rrule.rruleset):
            raise ValueError(
                'recurrence_rule should be an rrule, not an rruleset: '
                f'{self.recurrence_rule!r}')
        self.recurrence_rule_parsed = recurrence_rule_parsed


@dataclasses.dataclass
class _TodoState:
    """State for a single TODO.

    Attributes:
        last_sent: When an email was last successfully sent for this TODO.
        last_sent_parsed: See above.
    """
    now: dataclasses.InitVar[datetime.datetime]
    last_sent: Optional[str] = None
    last_sent_parsed: Optional[datetime.datetime] = dataclasses.field(
        init=False)

    def __post_init__(self, now: datetime.datetime):
        try:
            self.last_sent_parsed = (None if self.last_sent is None else
                                     dateutil.parser.isoparse(self.last_sent))
        except ValueError as e:
            raise ValueError(f'Invalid last_sent {self.last_sent!r}') from e
        if self.last_sent_parsed is not None and self.last_sent_parsed > now:
            raise RuntimeError(
                f'last_sent {self.last_sent_parsed} is in the future (after '
                f'{now}).')

    def set_last_sent(self, value: datetime.datetime) -> None:
        if value.tzinfo is not datetime.timezone.utc:
            raise ValueError('last_sent must be UTC')
        self.last_sent = value.strftime('%Y%m%dT%H%M%SZ')
        self.last_sent_parsed = value


def _parse_args(args: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Send scheduled TODO emails.')
    parser.add_argument(
        '--config',
        type=pathlib.Path,
        required=True,
        help='Path to config file.',
    )
    parser.add_argument(
        '--state',
        type=pathlib.Path,
        required=True,
        help='Path to state file.',
    )
    parser.add_argument(
        '--max-occurrences',
        type=int,
        default=10,
        help='Maximum number of occurrences to show at once.',
    )
    return parser.parse_args(args)


def _parse_config(config_filename: pathlib.Path) -> Mapping[str, _TodoConfig]:
    with open(config_filename, mode='rb') as config_file:
        raw_config = json.load(config_file)
    config = {}
    for group_id, group_config in raw_config.items():
        defaults = group_config.pop('defaults', {})
        todos = group_config.pop('todos')
        if group_config:
            raise ValueError(
                f'Unexpected group config keys: {list(group_config)!r}')
        for todo_id, todo_config in todos.items():
            config[f'{group_id}.{todo_id}'] = (  #
                _TodoConfig(**(defaults | todo_config)))
    return config


def _parse_state(
    state_filename: pathlib.Path,
    *,
    now: datetime.datetime,
) -> collections.defaultdict[str, _TodoState]:
    try:
        with open(state_filename, mode='rb') as state_file:
            raw_state = json.load(state_file)
    except FileNotFoundError:
        raw_state = {}
    return collections.defaultdict(
        lambda: _TodoState(now=now),
        ((todo_id, _TodoState(**todo_state, now=now))
         for todo_id, todo_state in raw_state.items()),
    )


def _save_state(
    state_filename: pathlib.Path,
    state: Mapping[str, _TodoState],
) -> None:
    raw_state = {}
    for todo_id, todo_state in state.items():
        raw_state[todo_id] = {
            field.name: getattr(todo_state, field.name)
            for field in dataclasses.fields(todo_state)
            if field.init
        }
    with tempfile.NamedTemporaryFile(
            mode='wt',
            dir=state_filename.parent,
            delete=False,
    ) as state_file_new:
        json.dump(raw_state, state_file_new)
    os.replace(state_file_new.name, state_filename)


def _send_email(
    *,
    todo_id: str,
    config: _TodoConfig,
    comment: Optional[str],
    extra: Sequence[Sequence[str]],
    subprocess_run: ...,
) -> None:
    message = email.message.EmailMessage()
    for header, value in config.email_headers.items():
        message[header] = value
    message['Subject'] = config.summary + ('' if comment is None else
                                           f' ({comment})')
    message['Todo-Id'] = todo_id
    message['Todo-Summary'] = config.summary
    message['Todo-Timezone'] = config.timezone
    message['Todo-Start'] = config.start
    if config.recurrence_rule is not None:
        message['Todo-Recurrence-Rule'] = config.recurrence_rule
    if config.description is not None:
        message.add_attachment(config.description, disposition='inline')
    if extra:
        message.add_attachment(
            '\n\n'.join('\n'.join(section) for section in extra),
            disposition='inline',
            filename='extra-information',
        )
    subprocess_run(
        ('/usr/sbin/sendmail', '-i', '-t'),
        check=True,
        input=bytes(message),
    )


def _handle_todo(
    *,
    todo_id: str,
    config: _TodoConfig,
    state: _TodoState,
    max_occurrences: int,
    now: datetime.datetime,
    subprocess_run: ...,
) -> None:
    extra = []  # List of sections, which are lists of lines.
    if now < config.start_parsed:
        return  # Not ready to send yet.
    if config.recurrence_rule_parsed is None:
        if (state.last_sent_parsed is not None and
                state.last_sent_parsed >= config.start_parsed):
            return  # Already sent.
        comment = None
    else:
        # This does not use config.recurrence_rule_parsed.between() because of
        # https://github.com/dateutil/dateutil/issues/1190
        included_occurrences = tuple(
            itertools.takewhile(
                lambda occurrence: occurrence <= now,
                config.recurrence_rule_parsed.xafter(
                    (config.start_parsed if state.last_sent_parsed is None else
                     state.last_sent_parsed),
                    count=max_occurrences + 1,
                    inc=(state.last_sent_parsed is None),
                )))
        if not included_occurrences:
            return
        elif len(included_occurrences) == 1:
            comment = None
        elif len(included_occurrences) > max_occurrences:
            comment = f'x{max_occurrences}+'
        else:
            comment = f'x{len(included_occurrences)}'
        extra.append([
            'Occurrences included in this email:',
            *(str(occurrence) if i < max_occurrences else '...'
              for i, occurrence in enumerate(included_occurrences)),
        ])
        next_occurrences = tuple(
            config.recurrence_rule_parsed.xafter(
                now,
                count=max_occurrences + 1,
                inc=False,
            ))
        extra.append([
            'Next occurrences:',
            *(str(occurrence) if i < max_occurrences else '...'
              for i, occurrence in enumerate(next_occurrences)),
        ])
    _send_email(
        todo_id=todo_id,
        config=config,
        comment=comment,
        extra=extra,
        subprocess_run=subprocess_run,
    )
    state.set_last_sent(now)


def main(
    args: Sequence[str],
    *,
    subprocess_run: ... = subprocess.run,
) -> None:
    now = datetime.datetime.now(tz=datetime.timezone.utc)
    args_parsed = _parse_args(args)
    config = _parse_config(args_parsed.config)
    state = _parse_state(args_parsed.state, now=now)
    for todo_id, todo_config in config.items():
        _handle_todo(
            todo_id=todo_id,
            config=todo_config,
            state=state[todo_id],
            max_occurrences=args_parsed.max_occurrences,
            now=now,
            subprocess_run=subprocess_run,
        )
    _save_state(args_parsed.state, state)


if __name__ == '__main__':
    main(sys.argv[1:])
