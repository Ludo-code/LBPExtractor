#!/usr/bin/env bash
# End-to-end tests for the shell lbpextract.
# Uses tests/pdftotext_mock.py as a `pdftotext` test double when the real
# poppler-utils is not installed (set MOCK_PDFTOTEXT=1, default when
# pdftotext is missing).
set -u
cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd)
WORK=$(mktemp -d /tmp/lbpextract-tests.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL - %s\n' "$1"; }
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1"; printf '  expected: %s\n  actual:   %s\n' "$2" "$3"; fi
}

# pdftotext: real one if present, else the mock.
if ! { command -v pdftotext >/dev/null 2>&1 && [ "${MOCK_PDFTOTEXT:-0}" != "1" ]; }; then
    MOCKDIR="$WORK/mockbin"
    mkdir -p "$MOCKDIR"
    cat > "$MOCKDIR/pdftotext" <<EOF
#!/usr/bin/env bash
exec python3 "$REPO/tests/pdftotext_mock.py" "\$@"
EOF
    chmod +x "$MOCKDIR/pdftotext"
    export PATH="$MOCKDIR:$PATH"
fi

python3 tests/make_fixtures.py "$WORK/fixtures" >/dev/null
mkdir -p "$WORK/in"
cp "$WORK"/fixtures/*.pdf "$WORK/in/"

LBP="bash $REPO/lbpextract"

# --- test 1: basic conversion -------------------------------------------------
( cd "$WORK/in" && $LBP '*.pdf' >/dev/null 2>&1 )
check "exit code 0" "0" "$?"
check "three CSVs created (jan+dec+copy merged, livret, francs)" "3" "$(ls "$WORK/in"/*.csv 2>/dev/null | wc -l)"
# dec + jan + jan_copy merged into the same account, sorted by date desc:
expected_acct='date,amount,description
2024-01-20,1500.00,VIREMENT
2023-12-15,-100.00,PRELEVEMENT EDF
2023-01-12,-50.00,CARTE | RETRAIT DAB
2023-01-10,2500.00,VIREMENT SALAIRE
2023-01-03,-123.45,PRELEVEMENT EDF'
check "account CSV content (merged, sorted desc)" "$expected_acct" "$(cat "$WORK/in/12345678901.csv")"
check "livret CSV content" 'date,amount,description
2023-01-05,12.34,INTERETS' "$(cat "$WORK/in/98765432109.csv")"

# --- test 2: refuses to overwrite without --remove ----------------------------
( cd "$WORK/in" && $LBP '*.pdf' >/dev/null 2>&1 )
check "second run without --remove fails" "1" "$?"
( cd "$WORK/in" && $LBP --remove '*.pdf' >/dev/null 2>&1 )
check "second run with --remove succeeds" "0" "$?"

# --- test 3: --separate --------------------------------------------------------
mkdir -p "$WORK/sep" && cp "$WORK"/fixtures/releve_jan.pdf "$WORK/sep/"
( cd "$WORK/sep" && $LBP --separate releve_jan.pdf >/dev/null 2>&1 )
check "--separate header" "date,income,spending,description" "$(head -1 "$WORK/sep/12345678901.csv")"
check "--separate debit row" "2023-01-03,0.00,-123.45,PRELEVEMENT EDF" "$(grep 'PRELEVEMENT' "$WORK/sep/12345678901.csv")"
check "--separate credit row" "2023-01-10,2500.00,0.00,VIREMENT SALAIRE" "$(grep 'VIREMENT SALAIRE' "$WORK/sep/12345678901.csv")"

# --- test 4: --output-dir ------------------------------------------------------
mkdir -p "$WORK/out"
( cd "$WORK/in" && $LBP -o "$WORK/out" --remove releve_livret.pdf >/dev/null 2>&1 )
check "--output-dir writes there" "1" "$(ls "$WORK/out"/*.csv 2>/dev/null | wc -l)"

# --- test 5: no match -> exit 2 -------------------------------------------------
( cd "$WORK/in" && $LBP 'nothing-*.pdf' >/dev/null 2>&1 )
check "no PDF matched -> exit 2" "2" "$?"

# --- test 6: multiple directories require -o -----------------------------------
mkdir -p "$WORK/a" "$WORK/b"
cp "$WORK"/fixtures/releve_jan.pdf "$WORK/a/"
cp "$WORK"/fixtures/releve_livret.pdf "$WORK/b/"
( $LBP "$WORK/a/releve_jan.pdf" "$WORK/b/releve_livret.pdf" >/dev/null 2>&1 )
check "multi-dir without -o -> exit 1" "1" "$?"
( $LBP -o "$WORK/out2" --remove "$WORK/a/releve_jan.pdf" "$WORK/b/releve_livret.pdf" >/dev/null 2>&1 )
check "multi-dir with -o -> exit 0" "0" "$?"
check "multi-dir output has 2 CSVs" "2" "$(ls "$WORK/out2"/*.csv 2>/dev/null | wc -l)"

# --- test 7: duplicate detection ----------------------------------------------
mkdir -p "$WORK/dup" && cp "$WORK"/fixtures/releve_jan.pdf "$WORK"/fixtures/releve_jan_copy.pdf "$WORK/dup/"
out=$( cd "$WORK/dup" && $LBP '*.pdf' 2>&1 >/dev/null )
case "$out" in *duplicate*) ok "duplicate detected" ;; *) bad "duplicate detected"; echo "$out" ;; esac

# --- test 8: --help / --version -------------------------------------------------
$LBP --help >/dev/null 2>&1; check "--help exit 0" "0" "$?"
$LBP --version 2>/dev/null | grep -q 'lbpextract'; check "--version prints name" "0" "$?"

# --- test 8b: francs-era statement (extra column, x<400 => debit) --------------
mkdir -p "$WORK/francs" && cp "$WORK"/fixtures/releve_2001_francs.pdf "$WORK/francs/"
( cd "$WORK/francs" && $LBP releve_2001_francs.pdf >/dev/null 2>&1 )
check "francs statement exit 0" "0" "$?"
check "francs debit sign (x<400)" "2001-06-08,-200.00,PRELEVEMENT" "$(grep PRELEVEMENT "$WORK/francs/55555555555.csv")"
check "francs credit sign" "2001-06-20,1000.00,VIREMENT" "$(grep VIREMENT "$WORK/francs/55555555555.csv")"

# --- test 8c: GUI mode (zenity mock) -------------------------------------------
GUIMOCK="$WORK/guimock"
mkdir -p "$GUIMOCK"
cp "$REPO/tests/zenity_mock.sh" "$GUIMOCK/zenity"
chmod +x "$GUIMOCK/zenity"
mkdir -p "$WORK/gui_in"
cp "$WORK"/fixtures/releve_jan.pdf "$WORK/gui_in/"
# answers: 1=input dir, 2=output dir (empty), 3=remove=yes, 4=separate=yes
export ZENITY_MOCK_LOG="$WORK/zenity.log"
export ZENITY_MOCK_ANSWERS="$WORK/gui_in

yes
yes"
( PATH="$GUIMOCK:$MOCKDIR:$PATH" ZENITY_MOCK_LOG="$ZENITY_MOCK_LOG" ZENITY_MOCK_ANSWERS="$ZENITY_MOCK_ANSWERS" \
    bash "$REPO/lbpextract" --gui >/dev/null 2>&1 )
check "GUI mode exit 0" "0" "$?"
check "GUI produced CSV in input dir" "1" "$(ls "$WORK/gui_in"/*.csv 2>/dev/null | wc -l)"
check "GUI --separate applied" "date,income,spending,description" "$(head -1 "$WORK/gui_in"/12345678901.csv 2>/dev/null)"
unset ZENITY_MOCK_LOG ZENITY_MOCK_ANSWERS

# GUI with no PDFs in the chosen dir -> exit 1
mkdir -p "$WORK/gui_empty"
export ZENITY_MOCK_LOG="$WORK/zenity2.log"
export ZENITY_MOCK_ANSWERS="$WORK/gui_empty

yes
no"
( PATH="$GUIMOCK:$MOCKDIR:$PATH" ZENITY_MOCK_LOG="$ZENITY_MOCK_LOG" ZENITY_MOCK_ANSWERS="$ZENITY_MOCK_ANSWERS" \
    bash "$REPO/lbpextract" -g >/dev/null 2>&1 )
check "GUI with empty dir -> exit 1" "1" "$?"
unset ZENITY_MOCK_LOG ZENITY_MOCK_ANSWERS

# --- test 9: invalid pdf -> exit 3 ----------------------------------------------
mkdir -p "$WORK/bad" && echo "not a pdf" > "$WORK/bad/broken.pdf"
cp "$WORK"/fixtures/releve_jan.pdf "$WORK/bad/"
( cd "$WORK/bad" && $LBP '*.pdf' >/dev/null 2>&1 )
check "invalid pdf -> exit 3 (others still processed)" "3" "$?"
check "valid pdf still produced CSV" "1" "$(ls "$WORK/bad"/12345678901.csv 2>/dev/null | wc -l)"

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
