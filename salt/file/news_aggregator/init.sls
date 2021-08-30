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


{% from 'common/map.jinja' import common %}
{% from 'news_aggregator/map.jinja' import news_aggregator %}


{% if not salt.grains.has_value('role:virtual-machine:guest') %}
  {{ error_this_state_can_only_be_run_from_a_vm }}
{% endif %}


include:
- virtual_machine.guest


news_aggregator_pkgs:
  pkg.installed:
  - pkgs: {{ news_aggregator.pkgs | json }}


rss2email_user:
  group.present:
  - name: rss2email
  - system: true
  user.present:
  - name: rss2email
  - gid: rss2email
  - home: {{ common.nonexistent_path }}
  - createhome: false
  - shell: {{ common.nologin_shell }}
  - system: true
  - require:
    - group: rss2email_user

/etc/rss2email.cfg:
  file.managed:
  - group: rss2email
  - mode: 0640
  - require:
    - rss2email_user
  - contents: |
      [DEFAULT]
      force-from = True
      name-format = {feed-title}
      trust-guid = True
      email-protocol = sendmail
      {% for email, feeds in pillar.news_aggregator.feeds.items() %}
      {% for feed_id, feed_url in feeds.items() %}
      [feed.{{ email | regex_replace('[^\\w\\d]', '-') }}.{{ feed_id }}]
      url = {{ feed_url }}
      to = {{ email }}
      {% endfor %}
      {% endfor %}

/srv/rss2email/data:
  file.directory:
  - user: rss2email
  - group: rss2email
  - mode: 0700
  - require:
    - /srv/rss2email
    - virtual_machine_guest_volumes
    - rss2email_user

{{ common.local_bin }}/r2e-wrapper:
  file.managed:
  - source: salt://news_aggregator/r2e_wrapper.py
  - mode: 0755
  - require:
    - news_aggregator_pkgs
    - /etc/rss2email.cfg
    - /srv/rss2email/data

{{ common.local_bin }}/r2e-wrapper run:
  cron.present:
  - identifier: f907cedc-fb0b-4300-8f9e-70701fca6c7d
  - user: rss2email
  - minute: random
  - require:
    - {{ common.local_bin }}/r2e-wrapper
    - rss2email_user
