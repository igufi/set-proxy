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
