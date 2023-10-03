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

media_center:

  # Required. Desktop background image.
  background:
    url: https://example.com/foo.jpg
    extension: jpg
    hash: cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e

  # Bookmarks in Firefox's policies.json format. See
  # https://mozilla.github.io/policy-templates/#bookmarks for details.
  firefox_bookmarks:
  - Title: YouTube
    URL: https://www.youtube.com/

  # Symlinks to make in the media center user's home directory.
  home_symlinks:
    Videos: /path/to/Videos
