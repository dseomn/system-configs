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


{% from 'mount/map.jinja' import mount %}


{% set fstab = salt['pillar.get']('mount:fstab', ()) %}


{% set pkgs = {} %}
{% for entry in fstab %}
  {% for pkg in mount.pkgs_by_fs_type.get(entry.type, ()) %}
    {% do pkgs.update({pkg: None}) %}
  {% endfor %}
{% endfor %}
mount_pkgs:
  pkg.installed:
  - pkgs: {{ pkgs | list | tojson }}


{% for entry in fstab %}
{{ entry.mountpoint }} exists:
  file.directory:
  - name: {{ entry.mountpoint }}
  - makedirs: true
  - require_in:
    - mount_fstab
{% endfor %}

# TODO(https://github.com/saltstack/salt/issues/45370): Simplify the empty case.
mount_fstab:
{% set fstab_marker_start = '# START: salt mount :#' %}
{% set fstab_marker_end = '# END: salt mount :#' %}
{% if fstab %}
  file.blockreplace:
  - name: /etc/fstab
  - marker_start: {{ fstab_marker_start | tojson }}
  - marker_end: {{ fstab_marker_end | tojson }}
  - content: |
      {%- for entry in fstab %}
      {{ ' '.join((
          entry.filesystem,
          entry.mountpoint,
          entry.type,
          entry.options,
          entry.dump | string,
          entry.pass | string,
      )) }}
      {%- endfor %}
  - append_if_not_found: true
  - require:
    - mount_pkgs
{% else %}
  file.replace:
  - name: /etc/fstab
  - pattern: {{
        ('^' + (fstab_marker_start | regex_escape) + '$.*^' +
         (fstab_marker_end | regex_escape) + '$\\n?') | tojson }}
  - repl: ''
  - flags:
    - DOTALL
    - MULTILINE
{% endif %}
  cmd.run:
  - name: mount --verbose --all
  - onchanges:
    - file: mount_fstab
