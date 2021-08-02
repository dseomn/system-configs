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

import datetime

_WARN_AFTER = datetime.timedelta(days=21)


def main():
    # https://en.wikipedia.org/wiki/Uptime#Using_/proc/uptime
    with open('/proc/uptime') as uptime_file:
        uptime_seconds, _ = uptime_file.read().split()
    uptime = datetime.timedelta(seconds=float(uptime_seconds))
    if uptime > _WARN_AFTER:
        print(f'Uptime: {uptime}')


if __name__ == '__main__':
    main()
