#!/bin/bash
# =====================================================================
#  ECE Linux Workshop — OPERATION BLACKOUT
#
#  Στήνει το σενάριο στον φάκελο ~/ece_blackout, παίζει τη δραματική
#  εισαγωγή και αφήνει τον φοιτητή σε ένα ειδικό shell [BLACKOUT]
#  που ΕΛΕΓΧΕΙ ΜΟΝΟ ΤΟΥ τα 5 στάδια μετά από κάθε εντολή.
#
#  ΚΑΝΟΝΑΣ: ένα στάδιο περνάει ΜΟΝΟ όταν
#    (α) έχει γίνει πραγματικά η δουλειά του σταδίου ΚΑΙ
#    (β) ο φοιτητής έχει φτιάξει άδειο αρχείο με το όνομα του κλειδιού
#        (touch ΚΛΕΙΔΙ — χωρίς τις αγκύλες).
#
#    1. Backup    : tar -xzf (υπάρχει temp_backup/auth_key.txt)  + touch ALPHA_77
#    2. Log       : βρέθηκε το node ID στο server.log             + touch OMEGA_99
#    3. Rogue CPU : η rogue_surge.sh δεν τρέχει (kill). Το κλειδί
#                   της είναι γραμμένο στην εντολή της (htop)      + touch SURG3_K1LL3R
#    4. Reboot    : reboot.sh εκτελέσιμο ΚΑΙ έτρεξε με επιτυχία   + touch CHM0D_M4STER
#    5. Κώδικας C : το voltage_regulator.c κάνει compile και βγάζει
#                   231.00 V. Το κλειδί ΔΕΝ υπάρχει στο .c: τυπώνεται
#                   από κρυφό header (.core/vault.h) μόνο όταν η τάση
#                   βγει σωστή                                     + touch C_H4CKER
#
#  Όταν περάσουν και τα 5: οθόνη επιτυχίας, χρόνος, και αρχείο
#  ~/ece_blackout/MISSION_COMPLETE.txt.
#
#  Για πρόβα χωρίς καθυστερήσεις:  BLACKOUT_FAST=1 bash setup_blackout.sh
#  Είναι ασφαλές να ξανατρέξει: καθαρίζει την προηγούμενη προσπάθεια.
# =====================================================================

RED='\033[0;31m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREY='\033[0;90m'
NC='\033[0m'

DIR="$HOME/ece_blackout"
STATE="/tmp/.blackout_state_$(id -u)"

# Αν ο φοιτητής βρίσκεται ήδη μέσα σε challenge, μην το ξαναστήσεις από μέσα.
if [ -n "$BLACKOUT_ACTIVE" ]; then
    echo -e "${YELLOW}Είσαι ήδη μέσα στο challenge.${NC}"
    echo "Για επανεκκίνηση: γράψε  exit  (βγαίνεις από το [BLACKOUT] shell), μετά  cd ~  και ξανατρέξε  bash setup_blackout.sh"
    exit 1
fi

# Χωρίς καθυστερήσεις όταν ζητηθεί ή όταν δεν υπάρχει πραγματικό τερματικό.
FAST=0
if [ -n "$BLACKOUT_FAST" ] || [ ! -t 1 ]; then FAST=1; fi

pause() { [ "$FAST" = 1 ] || sleep "$1"; }

type_line() {      # εφέ γραφομηχανής:  type_line "κείμενο" [καθυστέρηση ανά χαρακτήρα]
    local s="$1" d="${2:-0.025}" i
    if [ "$FAST" = 1 ]; then printf '%s\n' "$s"; return; fi
    for ((i = 0; i < ${#s}; i++)); do printf '%s' "${s:i:1}"; sleep "$d"; done
    printf '\n'
}

boot_ok()   { printf "[  ${BGREEN}OK${NC}  ] %s\n" "$1";   pause "${2:-0.17}"; }
boot_warn() { printf "[ ${YELLOW}WARN${NC} ] %s\n" "$1";   pause "${2:-0.35}"; }
boot_fail() { printf "[${BRED}FAILED${NC}] %s\n" "$1";     pause "${2:-0.45}"; }

show_banner() {    # show_banner "χρώμα" "κείμενο banner"  (γραμμή-γραμμή)
    local col="$1" line
    while IFS= read -r line; do
        printf '%b%s%b\n' "$col" "$line" "$NC"
        pause 0.12
    done <<< "$2"
}

BANNER_BLACKOUT='
  ####   #       ###    ####  #   #   ###   #   #  #####
  #   #  #      #   #  #      #  #   #   #  #   #    #
  ####   #      #####  #      ###    #   #  #   #    #
  #   #  #      #   #  #      #  #   #   #  #   #    #
  ####   #####  #   #   ####  #   #   ###    ###     #'

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

pause 1

# --- ΣΤΗΣΙΜΟ ΤΟΥ ΣΕΝΑΡΙΟΥ ------------------------------------------------
echo -e "${BRED}>>> INITIATING SYSTEM FAILURE PROTOTYPE...${NC}"
pause 1

# 0. Καθαρισμός προηγούμενης προσπάθειας
pkill -f rogue_surge.sh 2> /dev/null
rm -rf "$DIR" /tmp/rogue_surge.sh "$STATE"
mkdir -p "$STATE"

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

# 4. Stage 3: The Rogue Process  (flag: SURG3_K1LL3R)
#    Καίει έναν πυρήνα CPU, ώστε να φαίνεται πρώτο στο htop (CPU% ~100).
#    Το κλειδί είναι ορίσμα της εντολής, άρα φαίνεται στη στήλη Command του htop
#    (και στο ps aux). Το script το αγνοεί.
#    Σταματά μόνο του μετά από 1 ώρα, για να μη μείνει ξεχασμένο.
cat << 'EOF' > /tmp/rogue_surge.sh
#!/bin/bash
SECONDS=0
while [ "$SECONDS" -lt 3600 ]; do :; done
EOF
chmod +x /tmp/rogue_surge.sh
setsid /tmp/rogue_surge.sh "NODE_KEY=[SURG3_K1LL3R]" > /dev/null 2>&1 &
sleep 0.4
if ps -eo stat=,args= | grep -v '^Z' | grep -q '[r]ogue_surge\.sh'; then
    : > "$STATE/rogue_started"
else
    # Δεν ξεκίνησε: μην αφήσεις τον φοιτητή κολλημένο. Το "rogue_started" δεν
    # υπάρχει, οπότε το στάδιο 3 θα περνά μόνο με το touch του κλειδιού.
    echo -e "${YELLOW}(Προσοχή: η rogue διεργασία δεν ξεκίνησε. Το στάδιο 3 θα περάσει με το touch του κλειδιού.)${NC}"
    : > "$STATE/rogue_started"
fi

# 5. Stage 4: Permissions  (flag: CHM0D_M4STER)
#    Αρνείται να δουλέψει: (α) χωρίς δικαίωμα εκτέλεσης, (β) όσο τρέχει η rogue διεργασία.
#    Όταν πετύχει, αφήνει σημάδι ώστε ο έλεγχος να ξέρει ότι έτρεξε.
cat << 'EOF' > reboot.sh
#!/bin/bash
STATE="/tmp/.blackout_state_$(id -u)"
if [ ! -x "$0" ]; then
    echo "ΑΡΝΗΣΗ ΠΡΟΣΒΑΣΗΣ: το reboot.sh δεν έχει δικαίωμα εκτέλεσης (x)."
    echo "Το σύστημα δεν δέχεται εντολές επανεκκίνησης από αρχείο χωρίς άδεια."
    echo "Δώσε του δικαίωμα εκτέλεσης και τρέξ' το ως ./reboot.sh"
    exit 1
fi
if ps -eo stat=,args= | grep -v '^Z' | grep -q '[r]ogue_surge\.sh'; then
    echo "ΣΦΑΛΜΑ: Η επανεκκίνηση απέτυχε. Η διεργασία που υπερθερμαίνει το σύστημα τρέχει ακόμα!"
    echo "Βρες την με htop (ταξινόμησε με F6 -> PERCENT_CPU) και τερμάτισέ την με kill <PID>."
    exit 1
fi
echo "Εκκίνηση... ΕΠΙΤΥΧΙΑ!"
echo "Το κλειδί επανεκκίνησης είναι: [CHM0D_M4STER]"
echo "Τελευταίο βήμα: Διόρθωσε το voltage_regulator.c, κάντο compile και τρέξτο."
mkdir -p "$STATE" && : > "$STATE/reboot_ok"
EOF
chmod -x reboot.sh   # Αφαίρεση δικαιωμάτων εκτέλεσης

# 6. Stage 5: The Buggy C Code  (flag: C_H4CKER)
#    2 λάθη: ένα συντακτικό (δεν γίνεται compile) κι ένα λογικό (λάθος τάση).
#    Το flag ΔΕΝ υπάρχει μέσα στο .c. Βρίσκεται κωδικοποιημένο (XOR) στο κρυφό
#    header .core/vault.h και τυπώνεται από τη reveal_flag() μόνο όταν η τάση
#    βγει σωστή. Ούτε το "strings" στο εκτελέσιμο το δείχνει.
mkdir -p .core
VAULT_FLAG="C_H4CKER"
VAULT_BYTES=""
for ((i = 0; i < ${#VAULT_FLAG}; i++)); do
    c=$(printf '%d' "'${VAULT_FLAG:i:1}")
    VAULT_BYTES+=$(printf '0x%02x,' $((c ^ 90)))
done

cat << VEOF > .core/vault.h
#ifndef VAULT_H
#define VAULT_H
#include <stdio.h>

/* Κρυφό χρηματοκιβώτιο του συστήματος: τυπώνει το κλειδί ασφαλείας. */
static void reveal_flag(void) {
    static const unsigned char k[] = { $VAULT_BYTES };
    size_t i;
    for (i = 0; i < sizeof k; i++) putchar(k[i] ^ 0x5A);
}

#endif
VEOF

cat << 'EOF' > voltage_regulator.c
#include <stdio.h>
#include ".core/vault.h"

int main() {
    float I = 10.5; // Ρεύμα σε Αμπέρ
    float R = 22.0; // Αντίσταση σε Ομ

    // TODO: Υπολόγισε την τάση με βάση τον νόμο του Ohm
    float V = I + R;

    printf("Υπολογισμένη Τάση: %.2f Volts\n", V)

    if (V > 230.9 && V < 231.1) {
        printf("Η τάση είναι 231.00 Volts, το σύστημα σώθηκε! Το τελικό flag είναι: [");
        reveal_flag();
        printf("]\n");
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

ΠΩΣ ΠΕΡΝΑΕΙ ΕΝΑ ΣΤΑΔΙΟ: κάνε τη δουλειά του σταδίου και βρες το κλειδί του
(μορφή [ΚΑΤΙ_ΤΕΤΟΙΟ]). Μετά δημιούργησε ένα ΑΔΕΙΟ αρχείο με όνομα το κλειδί,
χωρίς τις αγκύλες, με την εντολή touch. Το σύστημα περνά το στάδιο μόνο αν
έχει γίνει και η δουλειά και το αρχείο.

  Στάδιο 1: Το backup σου είναι συμπιεσμένο (system_backup.tar.gz). Άνοιξέ το
            και διάβασε το κλειδί που κρύβει.
  Στάδιο 2: Στον φάκελο logs/ υπάρχει ένα αρχείο με 10.000 γραμμές.
            Μία από αυτές αναφέρει θανατηφόρο σφάλμα (FATAL). Βρες το node ID
            (ό,τι είναι μέσα στις αγκύλες). Αυτό είναι το κλειδί σου.
  Στάδιο 3: Κάτι καίει την CPU. Βρες το και τερμάτισέ το. Η διεργασία
            κουβαλάει το δικό της κλειδί: διάβασέ το πριν την τερματίσεις!
  Στάδιο 4: Το reboot.sh δεν τρέχει. Διόρθωσε το πρόβλημα και τρέξε το.
  Στάδιο 5: Το voltage_regulator.c έχει bugs. Διόρθωσέ τα, κάνε compile και
            τρέξτο. Το τελευταίο κλειδί εμφανίζεται ΜΟΝΟ αν το πρόγραμμα
            δουλέψει σωστά.

Το σύστημα ελέγχει μόνο του την πρόοδό σου, μετά από κάθε εντολή.
Όταν ολοκληρώσεις ένα στάδιο θα το δεις αμέσως. Το prompt δείχνει πρόοδο και χρόνο.

Γράψε  status  για να δεις πού βρίσκεσαι.
Κόλλησες; Πρώτα το Cheat Sheet (στο πρώτο tab, ή: less ~/student_cheat_sheet.md),
μετά <εντολή> --help, μετά man <εντολή>. Καλή επιτυχία!
EOF

echo -e "${BGREEN}>>> SYSTEM FAILURE SIMULATION READY.${NC}\n"
pause 1.5

# =====================================================================
#  ΔΡΑΜΑΤΙΚΗ ΕΙΣΑΓΩΓΗ
# =====================================================================
[ "$FAST" = 1 ] || clear

# Κανονική εκκίνηση του server...
boot_ok "Started Power Grid Controller"
boot_ok "Started Cooling & Thermal Management"
boot_ok "Mounted /dev/ece-lab/data"
boot_ok "Started Voltage Regulator Service"
boot_ok "Reached target ECE Lab Server Online" 0.9

# ...και μετά η κατάρρευση.
boot_warn "Voltage spike detected on the main grid"
if [ "$FAST" = 1 ]; then
    printf "[ ${YELLOW}WARN${NC} ] CPU temperature: ${BRED}104°C${NC}\n"
else
    for t in 71 78 85 91 97 104; do
        printf "\r[ ${YELLOW}WARN${NC} ] CPU temperature: ${BRED}%s°C${NC}   " "$t"
        sleep 0.3
    done
    printf '\n'
fi
boot_fail "cooling.service: Failed with result 'overload'"
boot_fail "gpu-display.service: graphics hardware burned out"
boot_fail "voltage-regulator.service: Unit contains bugs (exit-code 1)" 0.8
echo
printf "${BRED}"
type_line "Kernel panic - not syncing: Fatal exception in interrupt handler" 0.02
type_line "---[ end Kernel panic - not syncing: FATAL_OVERLOAD ]---" 0.02
printf "${NC}"
pause 1.8

# Το blackout.
[ "$FAST" = 1 ] || clear
pause 2.2
show_banner "$BRED" "$BANNER_BLACKOUT"
echo
pause 0.8

printf "${BRED}"
type_line "  SITUATION REPORT" 0.04
printf "${NC}"
pause 0.4
type_line "  Ο κεντρικός server του εργαστηρίου κατέρρευσε." 0.02
type_line "  Η κάρτα γραφικών κάηκε. Έχεις μόνο αυτό το τερματικό." 0.02
type_line "  Μια άγνωστη διεργασία υπερθερμαίνει το σύστημα," 0.02
type_line "  και ο κώδικας επαναφοράς έχει bugs." 0.02
echo
pause 0.6
echo -e "${GREY}  ------------------------------------------------------${NC}"
sed 's/^/  /' MISSION.txt
echo -e "${GREY}  ------------------------------------------------------${NC}"
echo
pause 1.5

echo -e "${YELLOW}  Το ρολόι ξεκινά σε...${NC}"
for n in 3 2 1; do
    if [ "$FAST" = 1 ]; then
        echo "    $n"
    else
        printf "\r${BRED}        ▶▶  %s  ◀◀   ${NC}" "$n"
        sleep 1
    fi
done
[ "$FAST" = 1 ] || printf '\n'
echo -e "${BGREEN}  ► ΞΕΚΙΝΑ ΤΩΡΑ! Είσαι ήδη μέσα στον φάκελο ~/ece_blackout.${NC}"
echo

# Το ρολόι της αποστολής ξεκινά εδώ.
printf '%(%s)T\n' -1 > "$STATE/start"

# =====================================================================
#  ΤΟ SHELL ΤΟΥ CHALLENGE (με αυτόματο έλεγχο σταδίων)
# =====================================================================
# Ένα script δεν μπορεί να αλλάξει τον φάκελο του τερματικού που το έτρεξε,
# γι' αυτό ανοίγουμε νέο shell εδώ μέσα. Το "exit" επιστρέφει στο προηγούμενο.
if [ -t 0 ] && [ -t 1 ]; then
    export BLACKOUT_DIR="$DIR" BLACKOUT_STATE="$STATE" BLACKOUT_ACTIVE=1
    RC="$(mktemp)"
    cat << 'RCEOF' > "$RC"
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

# ---------- βοηθητικά ----------
__bo_pause() { [ -n "$BLACKOUT_FAST" ] || sleep "$1"; }

__bo_count() {                      # -> __BO_C = πόσα στάδια έχουν περάσει
    local n; __BO_C=0
    for n in 1 2 3 4 5; do [ -f "$BLACKOUT_STATE/stage$n" ] && __BO_C=$((__BO_C + 1)); done
}

__bo_bar() {                        # -> __BO_BAR = ██░░░
    local i; __BO_BAR=""
    for ((i = 1; i <= 5; i++)); do
        if [ "$i" -le "$1" ]; then __BO_BAR+="█"; else __BO_BAR+="░"; fi
    done
}

__bo_time() {                       # -> __BO_T = mm:ss από την έναρξη (παγώνει στη νίκη)
    local start=0 end s
    [ -r "$BLACKOUT_STATE/start" ] && read -r start < "$BLACKOUT_STATE/start"
    if [ -r "$BLACKOUT_STATE/won" ]; then read -r end < "$BLACKOUT_STATE/won"
    else printf -v end '%(%s)T' -1; fi
    s=$((end - start)); [ "$s" -lt 0 ] && s=0
    printf -v __BO_T '%02d:%02d' $((s / 60)) $((s % 60))
}

# ---------- prompt: [BLACKOUT ██░░░ 03:12] ~/ece_blackout$ ----------
__bo_ps1() {
    __bo_count; __bo_time; __bo_bar "$__BO_C"
    if [ -f "$BLACKOUT_STATE/won" ]; then
        printf '\001\033[1;32m\002[RESTORED ✔ %s]\001\033[0m\002 ' "$__BO_T"
    else
        printf '\001\033[1;31m\002[BLACKOUT %s %s]\001\033[0m\002 ' "$__BO_BAR" "$__BO_T"
    fi
}
PS1='$(__bo_ps1)\[\033[1;34m\]\w\[\033[0m\]\$ '

# ---------- οι έλεγχοι των σταδίων ----------
__bo_rogue_alive() { ps -eo stat=,args= 2> /dev/null | grep -v '^Z' | grep -q '[r]ogue_surge\.sh'; }

# Έχει φτιάξει ο φοιτητής αρχείο με όνομα το κλειδί (touch ΚΛΕΙΔΙ);
# Δεκτά: ΚΛΕΙΔΙ, [ΚΛΕΙΔΙ], κλειδί με μικρά. Ψάχνει στον φάκελο της αποστολής,
# στους υποφακέλους του (1 επίπεδο), στον τρέχοντα φάκελο και στο home.
__bo_flag() {
    local nm="$1" d p
    for d in "$BLACKOUT_DIR" "$BLACKOUT_DIR"/*/ "$PWD" "$HOME"; do
        for p in "$nm" "[$nm]" "${nm,,}"; do
            [ -e "${d%/}/$p" ] && return 0
        done
    done
    return 1
}

__bo_t1() {                         # έγινε tar -xzf του backup + touch ALPHA_77
    local p ok=1
    for p in "$BLACKOUT_DIR" "$PWD" "$HOME"; do
        [ -f "$p/temp_backup/auth_key.txt" ] && ok=0
    done
    [ "$ok" -eq 0 ] && __bo_flag ALPHA_77
}

__bo_t2() { __bo_flag OMEGA_99; }                          # touch <node ID>

__bo_t3() {                         # η rogue δεν τρέχει πια + touch SURG3_K1LL3R
    [ -f "$BLACKOUT_STATE/rogue_started" ] && ! __bo_rogue_alive && __bo_flag SURG3_K1LL3R
}

__bo_t4() {                         # το reboot.sh έτρεξε με επιτυχία + touch CHM0D_M4STER
    [ -f "$BLACKOUT_STATE/reboot_ok" ] && [ -x "$BLACKOUT_DIR/reboot.sh" ] && __bo_flag CHM0D_M4STER
}

__bo_t5() {                         # το .c κάνει compile, βγάζει 231.00 V + flag, και touch C_H4CKER
    local src="$BLACKOUT_DIR/voltage_regulator.c" stamp="$BLACKOUT_STATE/t5stamp" tmp out
    __bo_flag C_H4CKER || return 1
    [ -f "$src" ] || return 1
    # Μην ξανακάνεις compile αν το αρχείο δεν άλλαξε από τον τελευταίο έλεγχο.
    if [ -f "$stamp" ] && [ ! "$src" -nt "$stamp" ]; then return 1; fi
    touch -d '2 seconds ago' "$stamp"
    tmp=$(mktemp -d) || return 1
    out=$(gcc -w -o "$tmp/vr" "$src" 2> /dev/null && timeout 5 "$tmp/vr" 2> /dev/null)
    rm -rf "$tmp"
    case "$out" in *231.00*C_H4CKER*) return 0 ;; esac
    return 1
}

# ---------- ανακοίνωση σταδίου ----------
__bo_title=("" "ΤΟ BACKUP ΑΝΟΙΧΤΗΚΕ" "ΤΟ ΘΑΝΑΤΗΦΟΡΟ ΣΦΑΛΜΑ ΕΝΤΟΠΙΣΤΗΚΕ" "Η ΥΠΕΡΘΕΡΜΑΝΣΗ ΣΤΑΜΑΤΗΣΕ" "Η ΕΠΑΝΕΚΚΙΝΗΣΗ ΕΠΙΤΥΧΕ" "Η ΤΑΣΗ ΣΤΑΘΕΡΟΠΟΙΗΘΗΚΕ")
__bo_msg=(
    ""
    "Το κλειδί πρόσβασης έγινε δεκτό. Το σύστημα αναγνωρίζει την ταυτότητά σου."
    "Ο κόμβος που προκάλεσε την κατάρρευση εντοπίστηκε μέσα σε 10.000 γραμμές."
    "Η rogue διεργασία τερματίστηκε. Οι ανεμιστήρες αρχίζουν να ησυχάζουν..."
    "Η επανεκκίνηση ολοκληρώθηκε. Τα φώτα ανάβουν ένα ένα."
    "231 Volts. Ο νόμος του Ohm νίκησε. Το σύστημα αναπνέει ξανά."
)

__bo_announce() {
    local n=$1
    __bo_count; __bo_bar "$__BO_C"; __bo_time
    printf '\n\033[1;32m ══════════════════════════════════════════════════\033[0m\n'
    printf '\033[1;32m ▌ ✔ ΣΤΑΔΙΟ %s/5 ΟΛΟΚΛΗΡΩΘΗΚΕ\033[0m\n' "$n"
    printf '\033[1;32m ▌ %s\033[0m\n' "${__bo_title[$n]}"
    printf '\033[0;32m ▌ %s\033[0m\n' "${__bo_msg[$n]}"
    printf '\033[1;33m ▌ ΠΡΟΟΔΟΣ  %s  %s/5    ⏱ %s\033[0m\n' "$__BO_BAR" "$__BO_C" "$__BO_T"
    printf '\033[1;32m ══════════════════════════════════════════════════\033[0m\n\n'
    __bo_pause 0.5
}

# ---------- η τελική νίκη ----------
__bo_victory() {
    local end line
    printf -v end '%(%s)T' -1
    echo "$end" > "$BLACKOUT_STATE/won"
    __bo_time
    echo
    printf '[  \033[1;32mOK\033[0m  ] Cooling subsystem online\n';              __bo_pause 0.35
    printf '[  \033[1;32mOK\033[0m  ] Voltage regulator stable at 231 V\n';     __bo_pause 0.35
    printf '[  \033[1;32mOK\033[0m  ] Graphics output restored\n';              __bo_pause 0.35
    printf '[  \033[1;32mOK\033[0m  ] Reached target ECE Lab Server Online\n';  __bo_pause 0.9
    echo
    while IFS= read -r line; do
        printf '\033[1;32m%s\033[0m\n' "$line"
        __bo_pause 0.12
    done << 'BANNER'
  ####   #####   ####  #####   ###   ####   #####  ####
  #   #  #      #        #    #   #  #   #  #      #   #
  ####   ####    ###     #    #   #  ####   ####   #   #
  #  #   #          #    #    #   #  #  #   #      #   #
  #   #  #####  ####     #     ###   #   #  #####  ####
BANNER
    echo
    printf '\033[1;32m  ΤΟ ΣΥΣΤΗΜΑ ΕΠΑΝΗΛΘΕ. Ο server του εργαστηρίου λειτουργεί ξανά.\033[0m\n'
    printf '\033[1;32m  MISSION STATUS: SUCCESS  ·  5/5 στάδια  ·  ⏱ %s\033[0m\n' "$__BO_T"
    echo
    printf '\033[1;33m  ► Φώναξε τον εκπαιδευτή και δείξε του αυτή την οθόνη.\033[0m\n\n'
    {
        echo "OPERATION BLACKOUT — ΟΛΟΚΛΗΡΩΘΗΚΕ"
        echo "Χρήστης:   $USER"
        echo "Χρόνος:    $__BO_T"
        echo "Ημερομηνία: $(date '+%d/%m/%Y %H:%M:%S')"
    } > "$BLACKOUT_DIR/MISSION_COMPLETE.txt"
}

# ---------- ο έλεγχος που τρέχει πριν από κάθε prompt ----------
__bo_check() {
    local rc=$? n
    [ -d "$BLACKOUT_STATE" ] || return $rc
    [ -f "$BLACKOUT_STATE/won" ] && return $rc
    for n in 1 2 3 4 5; do
        [ -f "$BLACKOUT_STATE/stage$n" ] && continue
        if "__bo_t$n"; then
            : > "$BLACKOUT_STATE/stage$n"
            __bo_announce "$n"
        fi
    done
    __bo_count
    [ "$__BO_C" -eq 5 ] && __bo_victory
    return $rc
}
PROMPT_COMMAND="__bo_check${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

# ---------- η εντολή status ----------
status() {
    local names=("" "Το backup ανοίγει" "Εντοπισμός θανατηφόρου σφάλματος" "Σταματά η υπερθέρμανση (CPU)" "Επανεκκίνηση συστήματος" "Σταθεροποίηση τάσης (κώδικας C)") n
    __bo_count; __bo_bar "$__BO_C"; __bo_time
    printf '\n \033[1;37mΚΑΤΑΣΤΑΣΗ ΑΠΟΣΤΟΛΗΣ\033[0m   %s  %s/5   ⏱ %s\n\n' "$__BO_BAR" "$__BO_C" "$__BO_T"
    for n in 1 2 3 4 5; do
        if [ -f "$BLACKOUT_STATE/stage$n" ]; then
            printf '   \033[1;32m✔\033[0m  Στάδιο %s   %s\n' "$n" "${names[$n]}"
        else
            printf '   \033[1;31m✘\033[0m  Στάδιο %s   %s\n' "$n" "${names[$n]}"
        fi
    done
    echo
}

rm -f "${BASH_SOURCE[0]}"
RCEOF
    cd "$DIR" || exit 1
    exec bash --rcfile "$RC"
else
    echo -e "${YELLOW}Το αυτόματο σύστημα ελέγχου χρειάζεται διαδραστικό τερματικό.${NC}"
    echo -e "${YELLOW}Γράψε:  cd ~/ece_blackout${NC}"
fi
