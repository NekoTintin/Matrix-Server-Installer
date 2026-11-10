#!/bin/bash

# GENERAL SETTINGS
INSTALL_DIR="/opt/matrix" # Directory where the script will install the server | will be created if it doesn't exist
#SERVER_TYPE="synapse" # synapse, conduit
HOMESERVER_URL="https://domain.com" # Will be change in the script
OPTIONAL_CLIENT="none" # element, fluffyChat, cinny, commet or none

# SYNAPSE
HOMESERVER_NAME="server" # Temp Name
INSTALL_KETESA="no" # yes or no | Ketesa is the new name of Synapse Admin, an open-source web-based admin panel for Synapse.
ACTIVATE_FEDERATION="yes" # yes or no | Federation is the ability for your server to communicate with other servers on the Matrix network. If you want to create a private server, you can disable this option.
# Default port for synapse is 8008, will not be changed in the script, but you can change it if you want to use a different port.
LOCAL_MEDIA_RETENTION="none" # Number of days to keep local media files | Default: none
REMOTE_MEDIA_RETENTION="30d" # Number of days to keep remote media files | Default: 30d
REGISTRATION_SHARED_SECRET="" # Shared secret for registration, will be generated if empty | Default: empty
MACAROON_SECRET_KEY="" # Secret key for macaroons, will be generated if empty | Default: empty
FORM_SECRET="" # Secret key for the from field, will be generated if empty | Default: empty
SIGNING_KEY_PATH="" # Path to the signing key, will be generated if empty | Default


# POSTGRESQL
POSTGRESQL_USER="synapse" # Username for the PostgreSQL database user | Default: synapse
POSTGRESQL_PASSWORD="password" # Password for the PostgreSQL database user | Default: password
POSTGRESQL_DB_NAME="synapse" # Name of the PostgreSQL database | Default: synapse
# Default port for postgresql is 5432, will not be changed in the script, but you can change it if you want to use a different port.

# LIVEKIT (Calls with MatrixRTC)
LIVEKIT_INSTALL="yes" # yes or no | LiveKit is an open-source WebRTC platform that allows you to add real-time audio and video communication to your applications. It the new standard for MatrixRTC, replacing Jitsi.
LIVEKIT_WSS="wss://yourdomain.com" # Domain for the LiveKit server | Will be used to generate the SSL certificate
LIVEKIT_KEY="yourkey" # Key for the LiveKit server | Will be used to generate the SSL certificate
LIVEKIT_SECRET="yoursecret" # Secret for the LiveKit server | Will be used to generate the SSL certificate
LIVEKIT_PORT="7880" # Port for the LiveKit server | Default: 7880
LIVEKIT_TCP_PORT="7881" # Port for the LiveKit TCP connection | Default: 7881
LIVEKIT_UDP_RANGE="7900-8000" # Range of ports for the LiveKit server, set 100 ports, large enough for a small server | Default: 7900-8000

# BEFORE START
## If Docker installed ?
if ! command -v docker &> /dev/null
then
	echo "Docker is not installed. Please install Docker before running this script."
	exit 1
fi
if ! command -v docker compose &> /dev/null
then
	echo "Docker Compose is not installed. Please install Docker Compose before running this script."
	exit 1
fi

## If Apache is installed ?
if command -v apache2 &> /dev/null || command -v httpd &> /dev/null
then
	echo "Apache is installed. Please uninstall Apache before running this script."
	exit 1
fi

# Message to display all requierements
printf "Welcome to the Matrix Server Installer script.
Before starting the installation, please make sure you have the following requirements:
- A domain name pointing to this server.
- A valid SSL certificate for your domain name (Let's Encrypt is free, if needed).
- Please make sure all the ports that will be used are not used by other services (if your reverse proxy use 443, it okay).
	- 8008 for Synapse, not exposed to the internet.
- Open the following ports in your firewall: 443 (HTTPS/TCP), 
	- If you want to use LiveKit, open the following ports: 7880 (TCP), 7881 (TCP), 7900-8000 (WARNING: UDP) (can be changed if needed).
	- If you want to enable federation, open the following ports: 8448 (TCP) (cannot be changed, Federation need this specific port).\n\n"

printf "Explanation of services:
- Synapse: The main Matrix server software that handles user accounts, messages, and federation with other Matrix servers.
- LiveKit: The Software that allows you to make audio and video calls, calls will not work if not configured properly.
- lk-jwt-service: The Software that allows you to generate JWT tokens for LiveKit, without this service, calls will not work.
- PostgreSQL: The database that Synapse uses to store its data. It is more efficient and reliable than the default SQLite database.

- Optional Client: A web-based Matrix client that allows you to access your Matrix server from a web browser. You can choose to install one of the following clients:
	- Element: The official Matrix client, it is the most popular and feature-rich client. (also available on Windows, macOS, Linux, Android, iOS)
	- FluffyChat: A simple and lightweight Matrix client, similar to WhatsApp, Telegram or Signal. (also available on Windows, macOS, Linux, Android, iOS)
	- Cinny: A modern and fast Matrix web client, similar to Discord (only available on web browsers).
	- Commet: A simple and fast Matrix client, build to have a similar experience to Discord (currently available on web, Windows and Android).

- Ketesa (preveiously known as Synapse Admin): A web-based admin panel for Synapse, it allows you to manage your Matrix server from a web browser. It is not required, but it is recommended for easier management of your server.\n\n"

echo "Are the requirements met? (y/n)"
read REQUIREMENTS_MET
if [ "$REQUIREMENTS_MET" != "y" ]; then
	echo "Please make sure all the requirements are met before running this script."
	exit 1
fi

# Ask for all the variables
echo "Where do you want to install the server? (default: /opt/) (matrix folder will be created in this directory, if it doesn't exist)"
read INSTALL_DIR_INPUT
# Check if folder can be read and write, if not, ask for another folder
while [ ! -w "$INSTALL_DIR_INPUT" ] && [ ! -d "$INSTALL_DIR_INPUT" ]; do
	echo "The folder $INSTALL_DIR_INPUT is not readable or writable. Please choose another folder."
	echo "New Path:"
	read INSTALL_DIR_INPUT
done
# Valid Path, exit the loop and set the variable
if [ -n "$INSTALL_DIR_INPUT" ]; then
	INSTALL_DIR="$INSTALL_DIR_INPUT"
fi

echo "What is your homeserver URL? (default: https://domain.com), this is placeholder, you have to enter your real domain name."
read HOMESERVER_URL_INPUT
if [ -n "$HOMESERVER_URL_INPUT" ]; then
	HOMESERVER_URL="$HOMESERVER_URL_INPUT"
fi

echo "Name your homeserver (default: server)"
read HOMESERVER_NAME_INPUT
if [ -n "$HOMESERVER_NAME_INPUT" ]; then
	HOMESERVER_NAME="$HOMESERVER_NAME_INPUT"
fi

echo "Enable federation? (yes/no) (default: yes)"
read ACTIVATE_FEDERATION_INPUT
if [ -n "$ACTIVATE_FEDERATION_INPUT" ]; then
	ACTIVATE_FEDERATION="$ACTIVATE_FEDERATION_INPUT"
fi

echo "Enable Calls with LiveKit? (yes/no) (default: yes)"
read LIVEKIT_INSTALL_INPUT
if [ -n "$LIVEKIT_INSTALL_INPUT" ]; then
	LIVEKIT_INSTALL="$LIVEKIT_INSTALL_INPUT"
fi

echo "Enter PostgreSQL username, password and database name (default: synapse, will generate a random secure password, synapse)"
echo "Username:"
read POSTGRESQL_USER_INPUT
if [ -n "$POSTGRESQL_USER_INPUT" ]; then
	POSTGRESQL_USER="$POSTGRESQL_USER_INPUT"
fi
echo "Password:"
read POSTGRESQL_PASSWORD_INPUT
if [ -n "$POSTGRESQL_PASSWORD_INPUT" ]; then
	POSTGRESQL_PASSWORD="$POSTGRESQL_PASSWORD_INPUT"
fi
echo "Database name:"
read POSTGRESQL_DB_NAME_INPUT
if [ -n "$POSTGRESQL_DB_NAME_INPUT" ]; then
	POSTGRESQL_DB_NAME="$POSTGRESQL_DB_NAME_INPUT"
fi

echo "