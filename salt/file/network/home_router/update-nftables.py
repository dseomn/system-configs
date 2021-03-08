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

{% from 'network/home_router/map.jinja' import home_router %}
{% from 'network/firewall/map.jinja' import nftables %}

import ipaddress
import json
import subprocess

_HOST = json.loads('{{ pillar.network.hosts[grains.id] | json }}')

_HOME_ROUTER_INTERFACES = {
    interface_name: interface
    for interface_name, interface in _HOST['interfaces'].items()
    if 'home_router' in interface
}
_MASQUERADE_IPV4_INTERFACES = (
    _HOST.get('firewall', {}).get('masquerade_ipv4', ()))


def _ip(*args):
    """Runs an `ip` command and returns the JSON result."""
    result = subprocess.run(
        ('ip', '--json', *args),
        stdout=subprocess.PIPE,
        check=True,
    )
    return json.loads(result.stdout)


def _global_networks(
        ip_interface,
        *,
        family,
):
    """Yields global networks the interface is on."""
    for addr in ip_interface['addr_info']:
        if addr['family'] != family or addr['scope'] != 'global':
            continue
        yield ipaddress.ip_network(
            f'{addr["local"]}/{addr["prefixlen"]}',
            strict=False,
        )


def _other_host_services(
        other_host,
        *,
        interface_name,
        ip_networks,
):
    """Yields @services_* elements for a specific host."""
    for service in other_host.get('services', ()):
        for l4proto in ('tcp', 'udp'):
            if l4proto not in service:
                continue
            for ip_network in ip_networks:
                other_host_addr = str(
                    ip_network.network_address +
                    other_host['interface_id'])
                yield ' . '.join((
                    interface_name,
                    other_host_addr,
                    l4proto,
                    str(service[l4proto]),
                ))


def main():
    services_ipv4 = set()
    services_ipv6 = set()
    masquerade_ipv4_addrs = set()
    for ip_interface in _ip('addr', 'show', 'up'):
        interface_name = ip_interface['ifname']
        if interface_name in _HOME_ROUTER_INTERFACES:
            ipv4_networks = set(_global_networks(ip_interface, family='inet'))
            ipv6_networks = set(_global_networks(ip_interface, family='inet6'))
            for other_host in (
                    _HOME_ROUTER_INTERFACES[interface_name]['home_router'].get(
                        'hosts', {}).values()):
                services_ipv4.update(
                    _other_host_services(
                        other_host,
                        interface_name=interface_name,
                        ip_networks=ipv4_networks,
                    ))
                services_ipv6.update(
                    _other_host_services(
                        other_host,
                        interface_name=interface_name,
                        ip_networks=ipv6_networks,
                    ))
        if interface_name in _MASQUERADE_IPV4_INTERFACES:
            masquerade_ipv4_addrs.update(
                addr['local'] for addr in ip_interface['addr_info']
                if addr['family'] == 'inet'
            )

    nft_commands = []
    for container_type, container, elements in (
            ('set', 'inet filter services_ipv4', services_ipv4),
            ('set', 'inet filter services_ipv6', services_ipv6),
            ('set', 'ip nat masquerade_ipv4_addrs', masquerade_ipv4_addrs),
    ):
        nft_commands.append(f'flush {container_type} {container}')
        if elements:
            nft_commands.append(
                'add element %s { %s }' % (
                    container,
                    ', '.join(elements),
                ))

    subprocess.run(
        ('{{ nftables.binary }}', '-f', '-'),
        input='\n'.join(nft_commands).encode(),
        check=True,
    )


if __name__ == '__main__':
    main()
