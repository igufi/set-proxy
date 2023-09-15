# set-proxy
Enable/disable proxy settings for common CLI tools.

Currently supported:
- Git
- Apt
- Npm
- Wget
- Pip
- Docker
- GnuPG
- Rust
- Corkscrew (SSH)
- plus any other tool that respects the http_proxy, https_proxy env variables

## Installation
Copy the script to ~/scripts, add the following to your .bashrc or equivalent:
```
alias proxyon="source ~/scripts/proxy-settings.sh on"
alias proxyoff="source ~/scripts/proxy-settings.sh off"
```

To make sure sudo works, edit the sudoers file:
```
sudo visudo
```
Find and adjust the following configuration line:
```
Defaults env_keep += "http_proxy https_proxy ftp_proxy no_proxy"
```
Save and exit.

## Troubleshooting
Some tools, e.g. curl, allow proxy overrides which will ignore the http_proxy, https_proxy environmental variables. For curl, you must make sure that .curlrc does not contain any proxy settings. This also applies for sudo - make sure root does not have any overriding configurations or the env_keep trick above will not help you.
