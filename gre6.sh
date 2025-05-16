#!/bin/bash

# Script to configure or remove /etc/rc.local for Iran or Kharej server and apply immediately

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Function to validate IPv6 address
validate_ipv6() {
    local ip=$1
    if [[ $ip =~ ^[0-9a-fA-F:]+$ ]]; then
        return 0
    else
        echo "Invalid IPv6 address: $ip"
        return 1
    fi
}

# Function to create and execute /etc/rc.local for Iran Server
create_rc_local_iran() {
    local iran_ipv6=$1
    local kharej_ipv6=$2
    echo "Creating /etc/rc.local for Iran Server..."
    cat > /etc/rc.local << EOF
#!/bin/bash

# Enable IPv6 and IPv4 forwarding
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.forwarding=1

# Configure GRE6 tunnel
ip tunnel add GRE6 mode ip6gre remote $kharej_ipv6 local $iran_ipv6
ip addr add 172.16.1.1/30 dev GRE6
ip link set GRE6 mtu 1420
ip link set GRE6 up

# Configure iptables NAT rules
iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination 172.16.1.1
iptables -t nat -A PREROUTING -p tcp --dport 1:65535 -j DNAT --to-destination 172.16.1.2:1-65535
iptables -t nat -A PREROUTING -p udp --dport 1:65535 -j DNAT --to-destination 172.16.1.2:1-65535
iptables -t nat -A POSTROUTING -j MASQUERADE

exit 0
EOF
    chmod +x /etc/rc.local
    echo "/etc/rc.local created and made executable."
    echo "Executing /etc/rc.local to apply changes immediately..."
    if bash /etc/rc.local; then
        echo "Changes applied successfully."
    else
        echo "Error: Failed to execute /etc/rc.local. Check the configuration."
        exit 1
    fi
}

# Function to create and execute /etc/rc.local for Kharej Server
create_rc_local_kharej() {
    local kharej_ipv6=$1
    local iran_ipv6=$2
    echo "Creating /etc/rc.local for Kharej Server..."
    cat > /etc/rc.local << EOF
#!/bin/bash

# Enable IPv6 and IPv4 forwarding
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.forwarding=1

# Configure GRE6 tunnel
ip tunnel add GRE6 mode ip6gre local $kharej_ipv6 remote $iran_ipv6
ip addr add 172.16.1.2/30 dev GRE6
ip link set GRE6 mtu 1420
ip link set GRE6 up

exit 0
EOF
    chmod +x /etc/rc.local
    echo "/etc/rc.local created and made executable."
    echo "Executing /etc/rc.local to apply changes immediately..."
    if bash /etc/rc.local; then
        echo "Changes applied successfully."
    else
        echo "Error: Failed to execute /etc/rc.local. Check the configuration."
        exit 1
    fi
}

# Function to remove GRE6 tunnel and NAT rules
remove_tunnel() {
    echo "Removing GRE6 tunnel and NAT rules..."
    # Remove GRE6 tunnel
    ip tunnel del GRE6 2>/dev/null || echo "No GRE6 tunnel found or already removed."
    # Remove iptables NAT rules (specific to Iran Server)
    iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination 172.16.1.1 2>/dev/null || echo "TCP port 22 NAT rule not found."
    iptables -t nat -D PREROUTING -p tcp --dport 1:65535 -j DNAT --to-destination 172.16.1.2:1-65535 2>/dev/null || echo "TCP port range NAT rule not found."
    iptables -t nat -D PREROUTING -p udp --dport 1:65535 -j DNAT --to-destination 172.16.1.2:1-65535 2>/dev/null || echo "UDP port range NAT rule not found."
    iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null || echo "MASQUERADE rule not found."
    # Remove or clear /etc/rc.local
    if [[ -f /etc/rc.local ]]; then
        echo "Removing /etc/rc.local..."
        rm /etc/rc.local
        echo "/etc/rc.local removed."
    else
        echo "/etc/rc.local does not exist."
    fi
    echo "Tunnel and NAT rules removal completed."
}

# Prompt for option
echo "Select an option:"
echo "1) Configure Iran Server"
echo "2) Configure Kharej Server"
echo "3) Remove Tunnel"
read -p "Enter choice (1, 2, or 3): " choice

case "$choice" in
    1)
        # Iran Server configuration
        echo "Configuring Iran Server..."
        read -p "Enter Iran Server Public IPv6 address: " iran_ipv6
        if ! validate_ipv6 "$iran_ipv6"; then
            exit 1
        fi
        read -p "Enter Kharej Server Public IPv6 address: " kharej_ipv6
        if ! validate_ipv6 "$kharej_ipv6"; then
            exit 1
        fi
        create_rc_local_iran "$iran_ipv6" "$kharej_ipv6"
        ;;
    2)
        # Kharej Server configuration
        echo "Configuring Kharej Server..."
        read -p "Enter Kharej Server Public IPv6 address: " kharej_ipv6
        if ! validate_ipv6 "$kharej_ipv6"; then
            exit 1
        fi
        read -p "Enter Iran Server Public IPv6 address: " iran_ipv6
        if ! validate_ipv6 "$iran_ipv6"; then
            exit 1
        fi
        create_rc_local_kharej "$kharej_ipv6" "$iran_ipv6"
        ;;
    3)
        # Remove tunnel and NAT rules
        remove_tunnel
        ;;
    *)
        echo "Invalid choice. Please select 1, 2, or 3."
        exit 1
        ;;
esac

exit 0
