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
"""Creates certificate boilerplate around a public key.

TLS is mostly designed to use X.509/PKIX certificates for authentication, rather
than raw public keys. However, at a small scale with easy out-of-band
provisioning, public keys are easier to work with than a full PKI.
https://datatracker.ietf.org/doc/html/rfc7250 does define TLS support for raw
public keys, but it does not appear to be well supported yet.

This script creates a new key pair and all the PKI boilerplate needed to use it
with TLS. It does not use a self-signed certificate directly, because that use
case appears to be an afterthought in the relevant specifications. (See, e.g.,
https://datatracker.ietf.org/doc/html/rfc6818#section-2.) Instead, it creates a
self-signed CA certificate with a single child EE certificate, which seems to
better match how PKIX and TLS are designed.

The CA certificate and its key are immediately discarded, leaving the EE
certificate and its key for use with TLS software that can be configured to
trust an EE certificate directly. If this script ever needs to be used with TLS
software that requires a CA to trust, it should be re-reviewed for that purpose,
and it would probably need some security improvements:

The exposure surface of the CA's private key should be minimized to avoid an
attacker surreptitiously creating new EE certs. mlockall(2) looks useful, though
difficult to use with Python. The ctypes module in the standard library might
help. Alternatively, the memory.swap.max parameter in cgroup might be able to
accomplish something similar.

The scope that the CA is trusted for should be minimized. See pathLenConstraint
in https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.9,
https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.10. However, name
constraint enforcement has not always been consistent, so it's probably
important to check the current state of enforcement for any constraints before
relying on them to limit the CA's scope.

Documentation:
https://datatracker.ietf.org/doc/html/rfc5280#section-4
https://cabforum.org/baseline-requirements-documents/ (Certificate profile)
"""

import argparse
from collections.abc import Sequence
import pathlib
import subprocess
import tempfile
import textwrap


def _args():
    parser = argparse.ArgumentParser(
        description='Create a key pair and EE certificate for TLS.')
    parser.add_argument(
        '--name',
        required=True,
        help='DNS name for the EE certificate.',
    )
    parser.add_argument(
        '--key',
        type=pathlib.Path,
        required=True,
        help='Path to write the EE certificate\'s private key to.',
    )
    parser.add_argument(
        '--cert',
        type=pathlib.Path,
        required=True,
        help='Path to write the EE certificate to.',
    )
    parser.add_argument(
        '--key-algorithm',
        required=True,
        help='See the -algorithm argument to openssl genpkey.',
    )
    parser.add_argument(
        '--key-option',
        nargs='*',
        help='See the -pkeyopt argument to openssl genpkey.',
    )
    parser.add_argument(
        '--days',
        required=True,
        help='See the -days argument to openssl req and x509.',
    )
    return parser.parse_args()


def _signature_args(args) -> Sequence[str]:
    # See https://cabforum.org/wp-content/uploads/CA-Browser-Forum-BR-1.8.0.pdf
    # section 7.1.3.2 for restrictions on the digest based on the key type.
    if args.key_algorithm == 'EC':
        if args.key_option == ['ec_paramgen_curve:P-384']:
            return ('-sha384',)
    raise NotImplementedError(f'{args.key_algorithm=}, {args.key_option=}')


def main() -> None:
    args = _args()

    genpkey_args = ['-algorithm', args.key_algorithm]
    for key_option in args.key_option:
        genpkey_args.extend(('-pkeyopt', key_option))

    signature_args = _signature_args(args)

    with tempfile.TemporaryDirectory() as tempdir_name:
        tempdir = pathlib.Path(tempdir_name)

        with tempdir.joinpath('openssl.cnf').open(mode='wt') as openssl_cnf:
            # Note that subjectKeyIdentifier comes before authorityKeyIdentifier
            # here despite the order being different in
            # https://datatracker.ietf.org/doc/html/rfc5280#section-4.2 because
            # otherwise openssl gives the error below.
            #
            # X509 V3 routines:v2i_AUTHORITY_KEYID:unable to get issuer keyid:../crypto/x509v3/v3_akey.c:143
            openssl_cnf.write(
                textwrap.dedent(f"""
                    [req]
                    string_mask = utf8only
                    prompt = no
                    utf8 = yes
                    distinguished_name = distinguished_name

                    [distinguished_name]

                    [x509_ca_extensions]
                    subjectKeyIdentifier = hash
                    authorityKeyIdentifier = keyid:always
                    keyUsage = critical, keyCertSign
                    basicConstraints = critical, CA:TRUE

                    [x509_ee_extensions]
                    subjectKeyIdentifier = hash
                    authorityKeyIdentifier = keyid:always
                    keyUsage = critical, digitalSignature
                    subjectAltName = DNS:{args.name}
                    basicConstraints = critical, CA:FALSE
                    extendedKeyUsage = serverAuth, clientAuth
                """))

        ca_private_key = subprocess.run(
            ('openssl', 'genpkey', *genpkey_args),
            stdout=subprocess.PIPE,
            check=True,
        ).stdout
        subprocess.run(
            (
                'openssl',
                'req',
                '-x509',
                '-batch',
                '-key',
                '/dev/stdin',
                '-config',
                str(tempdir.joinpath('openssl.cnf')),
                '-extensions',
                'x509_ca_extensions',
                '-subj',
                f'/CN=Boilerplate CA for {args.name}',
                '-days',
                args.days,
                *signature_args,
                '-out',
                str(tempdir.joinpath('ca-cert.pem')),
            ),
            input=ca_private_key,
            check=True,
        )

        subprocess.run(
            ('openssl', 'genpkey', *genpkey_args, '-out', str(args.key)),
            check=True,
        )
        subprocess.run(
            (
                'openssl',
                'req',
                '-new',
                '-batch',
                '-key',
                str(args.key),
                '-config',
                str(tempdir.joinpath('openssl.cnf')),
                '-subj',
                f'/CN={args.name}',
                *signature_args,
                '-out',
                str(tempdir.joinpath('ee-req.pem')),
            ),
            check=True,
        )
        subprocess.run(
            (
                'openssl',
                'x509',
                '-req',
                '-in',
                str(tempdir.joinpath('ee-req.pem')),
                '-CA',
                str(tempdir.joinpath('ca-cert.pem')),
                '-CAkey',
                '/dev/stdin',
                '-CAcreateserial',
                '-extfile',
                str(tempdir.joinpath('openssl.cnf')),
                '-extensions',
                'x509_ee_extensions',
                '-days',
                args.days,
                *signature_args,
                '-out',
                str(args.cert),
            ),
            input=ca_private_key,
            check=True,
        )


if __name__ == '__main__':
    main()
