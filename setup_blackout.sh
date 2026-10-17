#!/bin/bash
# =====================================================================
#  ECE Linux Workshop — Operation Blackout (setup script)
#  Στήνει ολόκληρο το σενάριο στον φάκελο ~/ece_blackout.
#  Είναι ασφαλές να τρέξει ξανά: καθαρίζει την προηγούμενη προσπάθεια.
# =====================================================================

# Χρώματα
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

DIR="$HOME/ece_blackout"

# --- ΕΛΕΓΧΟΣ & ΕΓΚΑΤΑΣΤΑΣΗ ΕΡΓΑΛΕΙΩΝ ---------------------------------
echo -e "${CYAN}>>> SYSTEM CHECK: Επιβεβαίωση απαραίτητων εργαλείων...${NC}"

MISSING_PACKAGES=""
command -v gcc  &> /dev/null || MISSING_PACKAGES="$MISSING_PACKAGES build-essential"
command -v htop &> /dev/null || MISSING_PACKAGES="$MISSING_PACKAGES htop"
command -v nano &> /dev/null || MISSING_PACKAGES="$MISSING_PACKAGES nano"

if [ -n "$MISSING_PACKAGES" ]; then
    echo -e "${YELLOW}Προσοχή: Λείπουν τα εξής πακέτα:$MISSING_PACKAGES${NC}"

    if ! command -v apt-get &> /dev/null; then
        echo -e "${RED}Δεν βρέθηκε το apt-get. Το workshop προϋποθέτει Ubuntu/Debian.${NC}"
        echo "Ζήτησε βοήθεια από τον εκπαιδευτή."
        exit 1
    fi

    echo "Για να συνεχίσουμε, πληκτρολογήστε τον κωδικό σας (sudo) ώστε να εγκατασταθούν."
    echo "(Θυμήσου: ο κωδικός ΔΕΝ εμφανίζεται καθώς τον γράφεις — γράψε τον και πάτα Enter.)"
    if sudo apt-get update && sudo apt-get install -y $MISSING_PACKAGES; then
        echo -e "${GREEN}Τα εργαλεία εγκαταστάθηκαν επιτυχώς!${NC}\n"
    else
        echo -e "${RED}Η εγκατάσταση απέτυχε. Ζήτησε βοήθεια από τον εκπαιδευτή.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Όλα τα εργαλεία (gcc, htop, nano) είναι ήδη έτοιμα!${NC}\n"
fi

sleep 1

# --- ΕΝΑΡΞΗ ΠΡΟΣΟΜΟΙΩΣΗΣ -----------------------------------------------
echo -e "${RED}>>> INITIATING SYSTEM FAILURE PROTOTYPE...${NC}"
sleep 1

# 0. Καθαρισμός προηγούμενης προσπάθειας (αν το script τρέξει δεύτερη φορά)
pkill -f rogue_surge.sh 2> /dev/null
rm -rf "$DIR" /tmp/rogue_surge.sh

# 1. Βασικός φάκελος
mkdir -p "$DIR"
cd "$DIR" || exit 1

# 2. Stage 1: Tar Archive  (flag: ALPHA_77)
mkdir -p temp_backup
echo "NODE_KEY: [ALPHA_77]" > temp_backup/auth_key.txt
tar -czf system_backup.tar.gz temp_backup
rm -rf temp_backup

# 3. Stage 2: Log Analysis  (flag: OMEGA_99)
#    Ένα μόνο αρχείο με 10.000 γραμμές. Μόνο μία περιέχει FATAL.
mkdir -p logs
echo -e "${CYAN}Generating 10,000 lines of system logs...${NC}"
NOW=$(date +%s)
{
    for i in $(seq 1 4302); do
        echo "TIMESTAMP $((NOW - 10000 + i)) - [INFO] Voltage at node $i is stable (220V)."
    done
    echo "TIMESTAMP $((NOW - 10000 + 4303)) - [FATAL_OVERLOAD] Node ID: [OMEGA_99] - System halted!"
    for i in $(seq 4304 10000); do
        echo "TIMESTAMP $((NOW - 10000 + i)) - [ERROR] Connection lost to node $i."
    done
} > logs/server.log

# 4. Stage 3: The Rogue Process
#    Καίει έναν πυρήνα CPU, ώστε να φαίνεται πρώτο στο htop (CPU% ~100).
#    Σταματά μόνο του μετά από 1 ώρα, για να μη μείνει ξεχασμένο.
cat << 'EOF' > /tmp/rogue_surge.sh
#!/bin/bash
SECONDS=0
while [ "$SECONDS" -lt 3600 ]; do :; done
EOF
chmod +x /tmp/rogue_surge.sh
setsid /tmp/rogue_surge.sh > /dev/null 2>&1 &

# 5. Stage 4: Permissions  (flag: CHM0D_M4STER)
#    Το reboot.sh αρνείται να δουλέψει όσο τρέχει η rogue διεργασία,
#    άρα το Stage 3 ελέγχεται αυτόματα.
cat << 'EOF' > reboot.sh
#!/bin/bash
if ps -eo stat=,args= | grep -v '^Z' | grep -q '[r]ogue_surge\.sh'; then
    echo "ΣΦΑΛΜΑ: Η επανεκκίνηση απέτυχε. Η διεργασία που υπερθερμαίνει το σύστημα τρέχει ακόμα!"
    echo "Βρες την με htop (ταξινόμησε με F6 -> PERCENT_CPU) και τερμάτισέ την με kill <PID>."
    exit 1
fi
echo "Εκκίνηση... ΕΠΙΤΥΧΙΑ!"
echo "Το κλειδί επανεκκίνησης είναι: [CHM0D_M4STER]"
echo "Τελευταίο βήμα: Διόρθωσε το voltage_regulator.c, κάντο compile και τρέξτο."
EOF
chmod -x reboot.sh   # Αφαίρεση δικαιωμάτων εκτέλεσης

# 6. Stage 5: The Buggy C Code  (flag: C_H4CKER)
#    2 λάθη: ένα συντακτικό (δεν γίνεται compile) κι ένα λογικό (λάθος τάση).
#    Το τελικό flag τυπώνεται ΜΟΝΟ αν η τάση βγει σωστή.
cat << 'EOF' > voltage_regulator.c
#include <stdio.h>

int main() {
    float I = 10.5; // Ρεύμα σε Αμπέρ
    float R = 22.0; // Αντίσταση σε Ομ

    // TODO: Υπολόγισε την τάση με βάση τον νόμο του Ohm
    float V = I + R;

    printf("Υπολογισμένη Τάση: %.2f Volts\n", V)

    if (V > 230.9 && V < 231.1) {
        printf("Η τάση είναι 231.00 Volts, το σύστημα σώθηκε! Το τελικό flag είναι: [C_H4CKER]\n");
    } else {
        printf("Η τάση δεν είναι σωστή. Το σύστημα παραμένει εκτός λειτουργίας.\n");
    }
    return 0;
}
EOF

# 7. Αποστολή: ό,τι χρειάζονται οι φοιτητές, χωρίς spoilers
cat << 'EOF' > MISSION.txt
=== OPERATION BLACKOUT: Αποστολή ===

Το σύστημα έπεσε. Επανάφερέ το βήμα βήμα.
Τα στάδια 1, 2, 4 και 5 κρύβουν ένα flag της μορφής [ΚΑΤΙ_ΤΕΤΟΙΟ]. Δείξε το στον εκπαιδευτή.
Το στάδιο 3 θα το ελέγξει το στάδιο 4.

  Στάδιο 1: Το backup σου είναι συμπιεσμένο (system_backup.tar.gz). Άνοιξέ το.
            Το flag είναι κρυμμένο μέσα του.
  Στάδιο 2: Στον φάκελο logs/ υπάρχει ένα αρχείο με 10.000 γραμμές.
            Μία από αυτές αναφέρει θανατηφόρο σφάλμα (FATAL). Βρες το node ID.
  Στάδιο 3: Κάτι καίει την CPU. Βρες το και τερμάτισέ το.
  Στάδιο 4: Το reboot.sh δεν τρέχει. Διόρθωσε το πρόβλημα και τρέξε το.
  Στάδιο 5: Το voltage_regulator.c έχει bugs. Διόρθωσέ τα, κάνε compile και τρέξτο.

Κόλλησες; Πρώτα το Cheat Sheet (στο πρώτο tab, ή: less ~/cheat_sheet.md),
μετά <εντολή> --help, μετά man <εντολή>. Καλή επιτυχία!
EOF

echo -e "${GREEN}>>> SYSTEM FAILURE SIMULATION READY.${NC}\n"
sleep 1

# --- ΕΚΚΙΝΗΣΗ ΤΟΥ CHALLENGE -------------------------------------------
[ -t 1 ] && clear
echo -e "${RED}"
echo "  ################################################"
echo "  #                                              #"
echo "  #            OPERATION  BLACKOUT               #"
echo "  #                                              #"
echo "  ################################################"
echo -e "${NC}"
echo -e "${RED}SITUATION REPORT:${NC}"
echo "Ο κεντρικός server του εργαστηρίου καταρρέει."
echo "Η κάρτα γραφικών κάηκε. Έχετε μόνο αυτό το τερματικό."
echo "Μια άγνωστη διεργασία υπερθερμαίνει το σύστημα και ο κώδικας επαναφοράς έχει bugs."
echo
cat MISSION.txt
echo
echo -e "${YELLOW}Ο χρόνος ξεκινά σε...${NC}"
for n in 3 2 1; do
    echo -e "${YELLOW}  $n${NC}"
    sleep 1
done
echo -e "${GREEN}ΤΩΡΑ! Είσαι ήδη μέσα στον φάκελο ~/ece_blackout. Καλή επιτυχία!${NC}"
echo

# Αφήνουμε τον φοιτητή μέσα στον φάκελο της αποστολής, με ξεχωριστό prompt.
# (Ένα script δεν μπορεί να αλλάξει τον φάκελο του τερματικού που το έτρεξε,
#  γι' αυτό ανοίγουμε νέο shell εδώ μέσα. Το "exit" επιστρέφει στο προηγούμενο.)
if [ -t 0 ] && [ -t 1 ]; then
    RC="$(mktemp)"
    cat << 'EOF' > "$RC"
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
PS1='\[\033[1;31m\][BLACKOUT]\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\]\$ '
EOF
    cd "$DIR" || exit 1
    exec bash --rcfile "$RC"
else
    echo -e "${YELLOW}Γράψε:  cd ~/ece_blackout${NC}"
fi
