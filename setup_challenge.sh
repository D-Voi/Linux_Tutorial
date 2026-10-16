#!/bin/bash

# Χρώματα
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- ΕΛΕΓΧΟΣ & ΕΓΚΑΤΑΣΤΑΣΗ ΕΡΓΑΛΕΙΩΝ ---
echo -e "${CYAN}>>> SYSTEM CHECK: Επιβεβαίωση απαραίτητων εργαλείων...${NC}"

MISSING_PACKAGES=""

# Ελέγχουμε αν οι εντολές υπάρχουν στο σύστημα
if ! command -v gcc &> /dev/null; then MISSING_PACKAGES="$MISSING_PACKAGES build-essential"; fi
if ! command -v htop &> /dev/null; then MISSING_PACKAGES="$MISSING_PACKAGES htop"; fi
if ! command -v nano &> /dev/null; then MISSING_PACKAGES="$MISSING_PACKAGES nano"; fi

# Αν λείπει κάτι, ζητάμε sudo και κάνουμε εγκατάσταση
if [ "$MISSING_PACKAGES" != "" ]; then
    echo -e "${YELLOW}Προσοχή: Λείπουν τα εξής πακέτα:$MISSING_PACKAGES${NC}"
    echo "Για να συνεχίσουμε, πληκτρολογήστε τον κωδικό σας (sudo) ώστε να εγκατασταθούν:"
    sudo apt-get update
    sudo apt-get install -y $MISSING_PACKAGES
    echo -e "${GREEN}Τα εργαλεία εγκαταστάθηκαν επιτυχώς!${NC}\n"
else
    echo -e "${GREEN}Όλα τα εργαλεία (gcc, htop, nano) είναι ήδη έτοιμα!${NC}\n"
fi

sleep 1

# --- ΕΝΑΡΞΗ ΠΡΟΣΟΜΟΙΩΣΗΣ ---
echo -e "${RED}>>> INITIATING SYSTEM FAILURE PROTOTYPE...${NC}"
sleep 1

# 1. Δημιουργία Βασικού Φακέλου
DIR="$HOME/ece_blackout"
mkdir -p "$DIR"
cd "$DIR"

# 2. Stage 1: Tar Archive
mkdir -p temp_backup
echo "NODE_KEY: [ALPHA_77]" > temp_backup/auth_key.txt
tar -czf system_backup.tar.gz temp_backup
rm -rf temp_backup

# 3. Stage 2: Log Analysis
mkdir -p logs
echo -e "${CYAN}Generating 10,000 lines of system logs...${NC}"
for i in {1..4302}; do
    echo "TIMESTAMP $(date +%s) - [INFO] Voltage at node $i is stable (220V)." >> logs/server.log
done
echo "TIMESTAMP $(date +%s) - [FATAL_OVERLOAD] Node ID: [OMEGA_99] - System halted!" >> logs/server.log
for i in {4304..10000}; do
    echo "TIMESTAMP $(date +%s) - [ERROR] Connection lost to node $i." >> logs/server.log
done

# 4. Stage 3: The Rogue Process (Background script)
cat << 'EOF' > /tmp/rogue_surge.sh
#!/bin/bash
while true; do
    sleep 60
done
EOF
chmod +x /tmp/rogue_surge.sh
/tmp/rogue_surge.sh & # Ξεκινάει στο background

echo "Ένα background process ξεκίνησε. Βρες το με htop και σκότωσέ το (kill PID)." > logs/process_hint.txt

# 5. Stage 4: Permissions
cat << 'EOF' > reboot.sh
#!/bin/bash
echo "Εκκίνηση... ΕΠΙΤΥΧΙΑ!"
echo "Το κλειδί επανεκκίνησης είναι: [CHM0D_M4STER]"
echo "Τελευταίο βήμα: Διόρθωσε το voltage_regulator.c, κάντο compile και τρέξτο."
EOF
chmod -x reboot.sh # Αφαίρεση δικαιωμάτων εκτέλεσης

# 6. Stage 5: The Buggy C Code
cat << 'EOF' > voltage_regulator.c
#include <stdio.h>

int main() {
    float I = 10.5; // Ρεύμα σε Αμπέρ
    float R = 22.0; // Αντίσταση σε Ομ
    
    // BUG 1: Ο Νόμος του Ohm είναι V = I * R
    float V = I + R; 
    
    // BUG 2: Λείπει το ερωτηματικό στο τέλος της printf
    printf("Υπολογισμένη Τάση: %.2f Volts\n", V)
    
    printf("Αν η τάση είναι 231.00 Volts, το σύστημα σώθηκε! Το τελικό flag είναι: [C_H4CKER]\n");
    return 0;
}
EOF

echo -e "${GREEN}>>> SYSTEM FAILURE SIMULATION READY. GO TO ~/ece_blackout${NC}"
