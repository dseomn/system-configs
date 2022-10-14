This is the configuration for my personal computers. See also my
[dotfiles](https://github.com/dseomn/dotfiles) for user-specific configuration.
Most of the files here are probably not that useful to anybody other than me
(except maybe to look at for ideas or something), but a few might be more
generally useful.

Simple monitoring scripts that can be used with cron to send an email when an
administrator might want to take action:

* [`salt/file/backup/repo/borg_require_recent_archive.py`](salt/file/backup/repo/borg_require_recent_archive.py):
  Alerts when a [Borg](https://www.borgbackup.org/) repository doesn't have a
  recent enough backup archive.
* [`salt/file/disk_usage/disk_usage_at_least.py`](salt/file/disk_usage/disk_usage_at_least.py):
  Alerts when disk usage is higher than the specified percent.
* [`salt/file/lost_found/monitor.sh`](salt/file/lost_found/monitor.sh): Alerts
  when
  [`lost+found`](https://unix.stackexchange.com/questions/18154/what-is-the-purpose-of-the-lostfound-folder-in-linux-and-unix)
  has anything in it.
* [`salt/file/uptime/uptime_warning.py`](salt/file/uptime/uptime_warning.py):
  Alerts when the system's uptime is too high (and the system should be
  rebooted).

[`salt/file/accounts/generate_lemonldap_ng_ini.py`](salt/file/accounts/generate_lemonldap_ng_ini.py)
makes it possible to [rotate LemonLDAP::NG's OpenID Connect
keys](https://lemonldap-ng.org/documentation/latest/openidconnectservice.html#key-rotation-script)
with the Local configuration backend.

[`salt/file/crypto/x509/boilerplate_certificate.py`](salt/file/crypto/x509/boilerplate_certificate.py)
provides a relatively easy way to create X.509/PKIX boilerplate around a public
key, for use with out-of-band certificate provisioning. It serves the same
purpose as self-signed certificates, but uses a separate CA and EE certificate
to avoid some issues with self-signed certificates.

[`salt/file/todo/todo.py`](salt/file/todo/todo.py) sends scheduled TODO emails.
I used to use recurring calendar tasks for this purpose, but I had trouble
finding CalDAV clients that supported recurring tasks well. Thunderbird was the
best I found, but between https://bugzilla.mozilla.org/show_bug.cgi?id=1686466
and https://bugzilla.mozilla.org/show_bug.cgi?id=1786656 it wasn't reliable
enough.

[`salt/file/xmpp/ejabberd_authentication.py`](salt/file/xmpp/ejabberd_authentication.py)
is an [ejabberd external authentication
script](https://docs.ejabberd.im/admin/configuration/authentication/#external-script)
that makes it possible to have multiple passwords per user (e.g., so a user can
use a different password on each of their devices). It uses a simple
configuration file in the style of
[passwd](https://en.wikipedia.org/wiki/Passwd#Password_file) or
[shadow](https://en.wikipedia.org/wiki/Passwd#Shadow_file) files

This is not an officially supported Google product.
