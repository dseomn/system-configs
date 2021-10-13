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
"""Notifies dovecot users if their subscriptions mismatch their mailboxes.

See https://bugzilla.mozilla.org/show_bug.cgi?id=1734451 for why ignoring
subscriptions doesn't always work well. See
https://dovecot.org/pipermail/dovecot/2021-October/123102.html for why this
doesn't just set the subscriptions directly.
"""

from collections.abc import Set
import email.message
import subprocess


def _notify(
    *,
    user: str,
    mailboxes: Set[str],
    subscribed: Set[str],
) -> None:
    sections = []

    unsubscribed = mailboxes - subscribed
    if unsubscribed:
        sections.append(''.join((
            'Unsubscribed mailboxes:\n',
            *(f'  {mailbox}\n' for mailbox in unsubscribed),
        )))

    nonexistent_subscribed = subscribed - mailboxes
    if nonexistent_subscribed:
        sections.append(''.join((
            'Nonexistent subscriptions:\n',
            *(f'  {subscription}\n' for subscription in nonexistent_subscribed),
        )))

    notification = email.message.EmailMessage()
    notification['To'] = user
    notification['Subject'] = 'subscriptions do not match mailboxes'
    notification.set_content('\n'.join(sections))
    subprocess.run(
        (
            '/usr/sbin/sendmail',
            '-i',
            '-t',
        ),
        check=True,
        input=bytes(notification),
    )


def main() -> None:
    users = subprocess.run(
        ('doveadm', 'user', '*'),
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    ).stdout.splitlines()
    for user in users:
        # `doveadm mailbox list` appears to list non-existent parents of
        # existent child mailboxes (e.g., it lists Foo if Foo/Bar exists but Foo
        # doesn't), but `doveadm mailbox status` seems to list only existent
        # mailboxes.
        mailbox_statuses = subprocess.run(
            (
                'doveadm',
                '-f',
                'tab',
                'mailbox',
                'status',
                '-u',
                user,
                'guid',
                '*',
            ),
            check=True,
            stdout=subprocess.PIPE,
            text=True,
        ).stdout.splitlines()[1:]
        mailboxes = {status.split('\t')[0] for status in mailbox_statuses}
        subscribed = set(
            subprocess.run(
                ('doveadm', 'mailbox', 'list', '-u', user, '-s'),
                check=True,
                stdout=subprocess.PIPE,
                text=True,
            ).stdout.splitlines())
        if mailboxes != subscribed:
            _notify(user=user, mailboxes=mailboxes, subscribed=subscribed)


if __name__ == '__main__':
    main()
