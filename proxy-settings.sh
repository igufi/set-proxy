#!/bin/bash

#set -e  # Stop the script on the first error

# Validate input
if [[ ! "$1" =~ ^(on|off)$ ]]; then
    echo "Usage: $0 {on|off}"
    exit 1
fi

HTTP_PROXY='http://<proxy>:<port>'
HTTPS_PROXY='http://<proxy>:<port>' # adjust protocol as needed (http/httpS)
PROXY_PORT='<port>'
# Assuming the HTTP_PROXY format is 'http://host:port'
HTTP_PROXY_HOST="$(echo $HTTP_PROXY | cut -d'/' -f3 | cut -d':' -f1)"
HTTP_PROXY_PORT="$(echo $HTTP_PROXY | cut -d':' -f3)"
HTTPS_PROXY_HOST="$(echo $HTTPS_PROXY | cut -d'/' -f3 | cut -d':' -f1)"
HTTPS_PROXY_PORT="$(echo $HTTPS_PROXY | cut -d':' -f3)"


WGETRC="$HOME/.wgetrc"
CONTAINERS_CONF="/etc/containers/containers.conf"
CONTAINERS_CONF_USER="$HOME/.config/containers/containers.conf"


# Check for dependencies
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to set proxy
set_proxy() {
    # Environment Variables
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTPS_PROXY"
    echo "Proxy enabled: env"

    # For git
    if command_exists git; then
        git config --global http.proxy "$http_proxy"
        git config --global https.proxy "$https_proxy"
        echo "Proxy enabled: git"
    else
        echo "git is not installed. Skipping git configuration."
    fi

    # For apt
    if [[ ! -e /etc/apt/apt.conf.d/30proxy.bak ]]; then
        sudo cp /etc/apt/apt.conf.d/30proxy /etc/apt/apt.conf.d/30proxy.bak 2>/dev/null || true
    fi
    echo "Acquire::http::Proxy \"$http_proxy\";" | sudo tee /etc/apt/apt.conf.d/30proxy >/dev/null
    echo "Acquire::https::Proxy \"$https_proxy\";" | sudo tee -a /etc/apt/apt.conf.d/30proxy >/dev/null
    echo "Proxy enabled: apt"

    # For npm
    if command_exists npm; then
        /usr/bin/npm config set proxy "$http_proxy"
        /usr/bin/npm config set https-proxy "$https_proxy"
        echo "Proxy enabled: npm"
    else
        echo "npm is not installed. Skipping npm configuration."
    fi

    # For wget
    if command_exists wget; then
        echo "http_proxy=$http_proxy" > "$WGETRC"
        echo "https_proxy=$https_proxy" >> "$WGETRC"
        echo "Proxy enabled: wget"
    else
        echo "wget is not installed. Skipping wget configuration."
    fi

    # For pip
    if command_exists pip; then
        pip config set global.proxy "$http_proxy" >/dev/null
        echo "Proxy enabled: pip"
    else
        echo "pip is not installed. Skipping pip configuration."
    fi

    # For Docker
    if command_exists docker; then
        if [[ ! -e /etc/systemd/system/docker.service.d/http-proxy.conf.bak ]]; then
            sudo cp /etc/systemd/system/docker.service.d/http-proxy.conf /etc/systemd/system/docker.service.d/http-proxy.conf.bak 2>/dev/null || true
        fi
        echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
        echo "Environment=\"HTTP_PROXY=$http_proxy\" \"HTTPS_PROXY=$https_proxy\"" | sudo tee -a /etc/systemd/system/docker.service.d/http-proxy.conf
        sudo systemctl daemon-reload
        sudo systemctl restart docker
        echo "Proxy enabled: docker"
    else
        echo "Docker is not installed. Skipping Docker configuration."
    fi

    # For GnuPG
    if command_exists gpg; then
        echo "use-http-proxy" >> ~/.gnupg/gpg.conf
        echo "http-proxy $http_proxy" >> ~/.gnupg/gpg.conf
        echo "Proxy enabled: gpg"
    else
        echo "GnuPG is not installed. Skipping GnuPG configuration."
    fi

     # For Rust (Cargo)
    CARGO_CONFIG="$HOME/.cargo/config"

    if [ -d "$HOME/.cargo" ]; then
      # Check if the proxy setting is already there
      if ! grep -q "proxy = \"$http_proxy\"" "$CARGO_CONFIG"; then
        # Check if there's an [http] section already
        if grep -q "^\[http\]" "$CARGO_CONFIG"; then
            # If [http] section exists, append only the proxy line
            echo "proxy = \"$http_proxy\"" >> "$CARGO_CONFIG"
        else
            # Otherwise, append both the section header and the proxy line
            echo -e "[http]\nproxy = \"$http_proxy\"" >> "$CARGO_CONFIG"
        fi
      fi
      echo "Proxy enabled: cargo/rust"
   else
     echo "Rust Cargo directory not found. Skipping Rust configuration."
   fi


    # For SSH (assuming corkscrew is installed and SSH needs the proxy)
    if command_exists ssh && command_exists corkscrew; then
        echo "Host *" >> ~/.ssh/config
        echo "    ProxyCommand corkscrew $HTTP_PROXY %h %p" >> ~/.ssh/config
        echo "Proxy enabled: corkscrew/ssh"
    else
        echo "SSH or corkscrew is not available. Skipping SSH configuration."
    fi

    # Check if Podman is installed
if command_exists podman; then
    # Check if containers.conf exists for the user first
    if [[ -f "$CONTAINERS_CONF_USER" ]]; then
        # Backup the original file first (only if a backup doesn't already exist)
        [[ ! -f "$CONTAINERS_CONF_USER.bak" ]] && cp "$CONTAINERS_CONF_USER" "$CONTAINERS_CONF_USER.bak"

        # Add proxy settings if they don't exist
        if ! grep -q "^http_proxy=" "$CONTAINERS_CONF_USER"; then
            echo "http_proxy=\"$http_proxy\"" >> "$CONTAINERS_CONF_USER"
        fi
        if ! grep -q "^https_proxy=" "$CONTAINERS_CONF_USER"; then
            echo "https_proxy=\"$https_proxy\"" >> "$CONTAINERS_CONF_USER"
        fi
    elif [[ -f "$CONTAINERS_CONF" ]]; then  # Check the system-wide configuration if user-specific doesn't exist
        # Same procedure: backup, then append if the proxies don't exist
        sudo [[ ! -f "$CONTAINERS_CONF.bak" ]] && sudo cp "$CONTAINERS_CONF" "$CONTAINERS_CONF.bak"
        if ! grep -q "^http_proxy=" "$CONTAINERS_CONF"; then
            echo "http_proxy=\"$http_proxy\"" | sudo tee -a "$CONTAINERS_CONF"
        fi
        if ! grep -q "^https_proxy=" "$CONTAINERS_CONF"; then
            echo "https_proxy=\"$https_proxy\"" | sudo tee -a "$CONTAINERS_CONF"
        fi
    echo "Proxy enabled: podman"
    else
        echo "No containers.conf found. Skipping Podman configuration."
    fi
else
    echo "Podman is not installed. Skipping Podman configuration."
fi

# For Maven
MAVEN_SETTINGS="$HOME/.m2/settings.xml"

if command_exists mvn; then
    if [[ ! -f "$MAVEN_SETTINGS" ]]; then
        # Create settings.xml if it doesn't exist
        mkdir -p "$HOME/.m2"
        echo "<settings xmlns=\"http://maven.apache.org/SETTINGS/1.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd\"></settings>" > "$MAVEN_SETTINGS"
    fi

    # Add proxy settings if they don't exist
    if ! grep -q "<proxies>" "$MAVEN_SETTINGS"; then
        sed -i "s|</settings>|<proxies>\n<proxy>\n<id>example-proxy</id>\n<active>true</active>\n<protocol>http</protocol>\n<host>$HTTP_PROXY_HOST</host>\n<port>$PROXY_PORT</port>\n</proxy>\n</proxies>\n</settings>|" "$MAVEN_SETTINGS"
    fi
    echo "Proxy enabled: maven"
else
    echo "Maven is not installed. Skipping Maven configuration."
fi

# For Gradle
GRADLE_PROPERTIES="$HOME/.gradle/gradle.properties"

if command_exists gradle; then
    echo "systemProp.http.proxyHost=$HTTP_PROXY_HOST" >> "$GRADLE_PROPERTIES"
    echo "systemProp.http.proxyPort=$PROXY_PORT" >> "$GRADLE_PROPERTIES"
    echo "systemProp.https.proxyHost=$HTTPS_PROXY_HOST" >> "$GRADLE_PROPERTIES"
    echo "systemProp.https.proxyPort=$PROXY_PORT" >> "$GRADLE_PROPERTIES"
    echo "Proxy enabled: gradle"
else
    echo "Gradle is not installed. Skipping Gradle configuration."
fi

# For Yarn
if command_exists yarn; then
    yarn config set proxy "$HTTP_PROXY"
    yarn config set https-proxy "$HTTPS_PROXY"
    echo "Proxy enabled: yarnn"
else
    echo "Yarn is not installed. Skipping Yarn configuration."
fi



}

# Function to unset proxy
unset_proxy() {
    # Environment Variables
    unset http_proxy
    unset https_proxy

    # For git
    if command_exists git; then
        git config --global --unset http.proxy
        git config --global --unset https.proxy
    fi

    # For apt
    sudo rm -f /etc/apt/apt.conf.d/30proxy

    # For npm
    if command_exists npm; then
        /usr/bin/npm config rm proxy
        /usr/bin/npm config rm https-proxy
    fi

    # For wget
    if command_exists wget; then
        rm -f "$WGETRC"
    fi

    # For pip
    if command_exists pip; then
        pip config unset global.proxy
    fi

    # For Docker
    if command_exists docker; then
        sudo rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
        sudo systemctl daemon-reload
        sudo systemctl restart docker
    fi

    # For GnuPG
    if command_exists gpg; then
        sed -i '/use-http-proxy/d' ~/.gnupg/gpg.conf
        sed -i "/http-proxy $http_proxy/d" ~/.gnupg/gpg.conf
    fi

   # For Rust (Cargo)
  if [ -d "$HOME/.cargo" ]; then
    if grep -q "proxy = \"$http_proxy\"" "$CARGO_CONFIG"; then
       sed -i "\|proxy = \"$http_proxy\"|d" "$CARGO_CONFIG"

       # If there's no other configuration under [http], remove [http] section as well
      if ! grep -q -A1 "^\[http\]" "$CARGO_CONFIG" | grep -v "^\[http\]"; then
         sed -i '/^\[http\]$/d' "$CARGO_CONFIG"
      fi
    fi
  fi

    # For SSH
    if command_exists ssh; then
        sed -i '/Host \*/d' ~/.ssh/config
        sed -i "\|ProxyCommand corkscrew $HTTP_PROXY %h %p|d" ~/.ssh/config
    fi

    if command_exists podman; then
    # User-specific config
    if [[ -f "$CONTAINERS_CONF_USER" ]]; then
        sed -i '/^http_proxy=/d' "$CONTAINERS_CONF_USER"
        sed -i '/^https_proxy=/d' "$CONTAINERS_CONF_USER"
    # System-wide config
    elif [[ -f "$CONTAINERS_CONF" ]]; then
        sudo sed -i '/^http_proxy=/d' "$CONTAINERS_CONF"
        sudo sed -i '/^https_proxy=/d' "$CONTAINERS_CONF"
    fi
fi

# For Maven
if command_exists mvn && [[ -f "$MAVEN_SETTINGS" ]]; then
    sed -i "/<proxies>/,/<\/proxies>/d" "$MAVEN_SETTINGS"
fi

# For Gradle
if command_exists gradle && [[ -f "$GRADLE_PROPERTIES" ]]; then
    sed -i "/systemProp.http.proxyHost=$HTTP_PROXY/d" "$GRADLE_PROPERTIES"
    sed -i "/systemProp.http.proxyPort=$PROXY_PORT/d" "$GRADLE_PROPERTIES"
    sed -i "/systemProp.https.proxyHost=$HTTP_PROXY/d" "$GRADLE_PROPERTIES"
    sed -i "/systemProp.https.proxyPort=$PROXY_PORT/d" "$GRADLE_PROPERTIES"
fi

# For Yarn
if command_exists yarn; then
    yarn config delete proxy
    yarn config delete https-proxy
fi


}

# Main script execution
case "$1" in
    on)
        set_proxy
        ;;
    off)
        unset_proxy
        ;;
esac
