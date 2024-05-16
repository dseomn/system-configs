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
"""Prints smart reports for all drives."""

import subprocess


def main():
    scan_result = subprocess.run(
        ("smartctl", "--scan"), stdout=subprocess.PIPE, check=True, text=True
    )
    for line in scan_result.stdout.splitlines():
        device, _, _ = line.partition(" ")
        print(f"{device}:")
        try:
            subprocess.run(("smartctl", "--all", device), check=True)
        except subprocess.CalledProcessError as e:
            print(f"smartctl returned {e.returncode} for {device}")
        print()
        print()


if __name__ == "__main__":
    main()
