This is the configuration for my personal computers. See also my
[dotfiles](https://github.com/dseomn/dotfiles) for user-specific configuration.
Most of the files here are probably not that useful to anybody other than me
(except maybe to look at for ideas or something), but a few might be more
generally useful.

Simple monitoring scripts that can be used with cron to send an email when an
administrator might want to take action:

* [`salt/file/disk_usage/disk_usage_at_least.py`](salt/file/disk_usage/disk_usage_at_least.py):
  Alerts when disk usage is higher than the specified percent.
* [`salt/file/lost_found/monitor.sh`](salt/file/lost_found/monitor.sh): Alerts
  when
  [`lost+found`](https://unix.stackexchange.com/questions/18154/what-is-the-purpose-of-the-lostfound-folder-in-linux-and-unix)
  has anything in it.
* [`salt/file/uptime/uptime_warning.py`](salt/file/uptime/uptime_warning.py):
  Alerts when the system's uptime is too high (and the system should be
  rebooted).

[`salt/file/crypto/x509/boilerplate_certificate.py`](salt/file/crypto/x509/boilerplate_certificate.py)
provides a relatively easy way to create X.509/PKIX boilerplate around a public
key, for use with out-of-band certificate provisioning. It serves the same
purpose as self-signed certificates, but uses a separate CA and EE certificate
to avoid some issues with self-signed certificates.

This is not an officially supported Google product.
