#!/bin/bash

source settings.conf

# Check if first user provided
if [ -z "$1" ]; then
    echo "Usage: $0 user"
    exit 1
fi

# Path to xray folder
XRAY_DIR="xray"

# Check if directory exists
if [ ! -d "$XRAY_DIR" ]; then
    echo "Directory $XRAY_DIR does not exist!"
    exit 1
fi

cd "$XRAY_DIR" || exit 1

# Replace example.com with user domain in config.json
if [ -f "config.json" ]; then
    sed -i "s/example\.com/$SERVER_DOMAIN/g" config.json
    echo "Updated config.json with domain $SERVER_DOMAIN"
else
    echo "config.json not found!"
fi

# Replace example.com with user domain in Caddyfile
if [ -f "Caddyfile" ]; then
    sed -i "s/example\.com/$SERVER_DOMAIN/g" Caddyfile
    echo "Updated Caddyfile with domain $SERVER_DOMAIN"
else
    echo "Caddyfile not found!"
fi

USERNAME="$1"
EMAIL="${USERNAME}@${SERVER_DOMAIN}"

# Check if the user already exists
if grep -q "\"email\": \"$EMAIL\"" "$CONFIG"; then
    echo "User with email $EMAIL already exists!"
    exit 1
fi

# Generate UUID
UUID=$(openssl rand -hex 16 | sed 's/\(..\)/\1-/4' | sed 's/-/-4/' | sed 's/-[89ab]/a/' | cut -c1-36 | sed 's/-$//')

echo "Creating client: $EMAIL"
echo "UUID: $UUID"

mkdir -p "$USERS_DIR"

# Create temporary file with JSON block
TMP="/tmp/newclient.tmp"

cat > "$TMP" <<EOF
          {
            "id": "$UUID",
            "flow": "$FLOW",
            "level": 0,
            "email": "$EMAIL"
          }
EOF

# Insert the block after the "clients": [ line
sed -i "/\"clients\": \[/r $TMP" "$CONFIG"

rm "$TMP"

echo "Added to config.json"

# Generate VLESS URL
VLESS_URL="vless://$UUID@$SERVER_DOMAIN:$PORT?encryption=none&security=tls&flow=$FLOW&sni=$SERVER_DOMAIN&fp=$FINGERPRINT#$USERNAME"

USER_CONF="$USERS_DIR/$USERNAME.conf"
echo "$VLESS_URL" > "$USER_CONF"

echo "Created file $USER_CONF"

# Display QR code in terminal
echo
qrencode -t ANSIUTF8 "$VLESS_URL"


# Start containers
echo "Start Docker containers..."
docker-compose up -d

echo "Done!"
