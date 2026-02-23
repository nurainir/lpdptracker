#!/bin/bash
# =============================================================================
# Script   : get_first_author_affiliation.sh
# Deskripsi: Mengambil affiliasi dan ORCID first author dari REST API Crossref
#            berdasarkan funder ID (LPDP - Lembaga Pengelola Dana Pendidikan)
# API      : https://api.crossref.org/funders/{funder_id}/works
# Dependensi: curl, jq
# =============================================================================

# --- Konfigurasi ---
FUNDER_ID="501100014538" #LPDP funder
ROWS=5
BASE_URL="https://api.crossref.org/funders/${FUNDER_ID}/works"
API_URL="${BASE_URL}?rows=${ROWS}"

# Opsional: tambahkan email untuk polite pool Crossref (lebih stabil)
# API_URL="${BASE_URL}?rows=${ROWS}&mailto=email@kamu.com"

# Warna output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Fungsi: Cek dependensi ---
check_dependencies() {
    local missing=0
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}[ERROR] Perintah '$cmd' tidak ditemukan. Silakan install terlebih dahulu.${NC}"
            missing=1
        fi
    done
    [ "$missing" -eq 1 ] && exit 1
}

# --- Fungsi: Tampilkan header ---
print_header() {
    echo -e "${BOLD}${CYAN}"
    echo "============================================================"
    echo "  Crossref API - First Author Affiliation & ORCID Extractor"
    echo "============================================================${NC}"
    echo -e "${YELLOW}Funder ID : ${FUNDER_ID} (LPDP)${NC}"
    echo -e "${YELLOW}Endpoint  : ${API_URL}${NC}"
    echo -e "${YELLOW}Jumlah    : ${ROWS} artikel${NC}"
    echo "------------------------------------------------------------"
}

# --- Fungsi: Ambil data dari API ---
fetch_data() {
    echo -e "\n${CYAN}[INFO] Mengambil data dari Crossref API...${NC}"
    
    RESPONSE=$(curl -s \
        --max-time 30 \
        --retry 3 \
        --retry-delay 2 \
        -H "User-Agent: AffiliationScript/1.0" \
        "$API_URL")

    if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
        echo -e "${RED}[ERROR] Gagal mengambil data dari API. Periksa koneksi internet.${NC}"
        exit 1
    fi

    # Cek status response
    STATUS=$(echo "$RESPONSE" | jq -r '.status' 2>/dev/null)
    if [ "$STATUS" != "ok" ]; then
        echo -e "${RED}[ERROR] API mengembalikan status: ${STATUS}${NC}"
        echo "$RESPONSE" | jq '.message' 2>/dev/null
        exit 1
    fi

    TOTAL=$(echo "$RESPONSE" | jq -r '.message["total-results"]')
    echo -e "${GREEN}[OK] Berhasil. Total hasil tersedia: ${TOTAL} artikel.${NC}"
    echo "------------------------------------------------------------"
}

# --- Fungsi: Ekstrak ORCID ID bersih dari URL ORCID ---
# Input : "https://orcid.org/0000-0002-1234-5678" atau sudah berupa ID
# Output: "0000-0002-1234-5678"
parse_orcid() {
    local raw="$1"
    # Hapus prefix URL jika ada, ambil bagian ID saja
    echo "$raw" | sed 's|https\?://orcid\.org/||'
}

# --- Fungsi: Ekstrak & tampilkan affiliasi + ORCID first author ---
extract_affiliations() {
    echo -e "\n${BOLD}DAFTAR AFFILIASI & ORCID FIRST AUTHOR${NC}\n"

    ITEM_COUNT=$(echo "$RESPONSE" | jq '.message.items | length')

    for i in $(seq 0 $((ITEM_COUNT - 1))); do
        ITEM=$(echo "$RESPONSE" | jq ".message.items[$i]")

        # Judul artikel
        TITLE=$(echo "$ITEM" | jq -r '.title[0] // "Judul tidak tersedia"')

        # DOI
        DOI=$(echo "$ITEM" | jq -r '.DOI // "N/A"')

        # Tahun terbit
        YEAR=$(echo "$ITEM" | jq -r '.issued["date-parts"][0][0] // "N/A"')

        # First author: cari author dengan sequence = "first"
        FIRST_AUTHOR=$(echo "$ITEM" | jq '
            .author // [] |
            map(select(.sequence == "first")) |
            first // {}
        ')

        if [ -z "$FIRST_AUTHOR" ] || [ "$FIRST_AUTHOR" = "null" ] || [ "$FIRST_AUTHOR" = "{}" ]; then
            FIRST_AUTHOR=$(echo "$ITEM" | jq '.author[0] // {}')
        fi

        # Nama first author
        GIVEN=$(echo "$FIRST_AUTHOR" | jq -r '.given // ""')
        FAMILY=$(echo "$FIRST_AUTHOR" | jq -r '.family // "Tidak diketahui"')
        AUTHOR_NAME="${GIVEN} ${FAMILY}"
        AUTHOR_NAME=$(echo "$AUTHOR_NAME" | xargs)  # trim whitespace

        # ORCID first author
        # Field "ORCID" di Crossref berisi URL penuh, misal: "https://orcid.org/0000-0002-XXXX-XXXX"
        ORCID_RAW=$(echo "$FIRST_AUTHOR" | jq -r '.ORCID // ""')
        ORCID_AUTHENTICATED=$(echo "$FIRST_AUTHOR" | jq -r '."authenticated-orcid" // false')

        if [ -z "$ORCID_RAW" ] || [ "$ORCID_RAW" = "null" ]; then
            ORCID_DISPLAY="Tidak tersedia"
            ORCID_URL="N/A"
        else
            ORCID_ID=$(parse_orcid "$ORCID_RAW")
            ORCID_URL="https://orcid.org/${ORCID_ID}"
            # Tampilkan tanda (✓) jika ORCID sudah terautentikasi
            if [ "$ORCID_AUTHENTICATED" = "true" ]; then
                ORCID_DISPLAY="${ORCID_ID}  ✓ (terautentikasi)"
            else
                ORCID_DISPLAY="${ORCID_ID}  ✗ (belum terautentikasi)"
            fi
        fi

        # Affiliasi first author (bisa lebih dari satu)
        AFFILIATIONS=$(echo "$FIRST_AUTHOR" | jq -r '
            .affiliation // [] |
            if length == 0 then
                ["Affiliasi tidak tersedia"]
            else
                map(.name // "N/A")
            end |
            .[]
        ')

        # Tampilkan hasil
        echo -e "${BOLD}Artikel $((i + 1))${NC}"
        echo -e "  ${YELLOW}Judul        :${NC} $TITLE"
        echo -e "  ${YELLOW}DOI          :${NC} https://doi.org/$DOI"
        echo -e "  ${YELLOW}Tahun        :${NC} $YEAR"
        echo -e "  ${YELLOW}First Author :${NC} $AUTHOR_NAME"
        echo -e "  ${YELLOW}ORCID        :${NC} $ORCID_DISPLAY"
        if [ "$ORCID_URL" != "N/A" ]; then
            echo -e "  ${YELLOW}ORCID URL    :${NC} $ORCID_URL"
        fi
        echo -e "  ${YELLOW}Affiliasi    :${NC}"

        if [ -z "$AFFILIATIONS" ]; then
            echo -e "               - Affiliasi tidak tersedia"
        else
            while IFS= read -r aff; do
                echo -e "               - $aff"
            done <<< "$AFFILIATIONS"
        fi

        echo "------------------------------------------------------------"
    done
}

# --- Fungsi: Ekspor ke CSV ---
export_csv() {
    CSV_FILE="first_author_affiliations.csv"
    echo -e "\n${CYAN}[INFO] Menyimpan hasil ke ${CSV_FILE}...${NC}"

    echo '"No","Judul","DOI","Tahun","Nama First Author","ORCID ID","ORCID URL","ORCID Terautentikasi","Affiliasi"' > "$CSV_FILE"

    ITEM_COUNT=$(echo "$RESPONSE" | jq '.message.items | length')

    for i in $(seq 0 $((ITEM_COUNT - 1))); do
        ITEM=$(echo "$RESPONSE" | jq ".message.items[$i]")

        TITLE=$(echo "$ITEM" | jq -r '.title[0] // ""' | tr '"' "'")
        DOI=$(echo "$ITEM" | jq -r '.DOI // ""')
        YEAR=$(echo "$ITEM" | jq -r '.issued["date-parts"][0][0] // ""')

        FIRST_AUTHOR=$(echo "$ITEM" | jq '
            .author // [] |
            map(select(.sequence == "first")) |
            first // (.author[0] // {})
        ')

        GIVEN=$(echo "$FIRST_AUTHOR" | jq -r '.given // ""')
        FAMILY=$(echo "$FIRST_AUTHOR" | jq -r '.family // ""')
        AUTHOR_NAME="${GIVEN} ${FAMILY}"
        AUTHOR_NAME=$(echo "$AUTHOR_NAME" | xargs)

        # ORCID
        ORCID_RAW=$(echo "$FIRST_AUTHOR" | jq -r '.ORCID // ""')
        ORCID_AUTHENTICATED=$(echo "$FIRST_AUTHOR" | jq -r '."authenticated-orcid" // false')
        if [ -z "$ORCID_RAW" ] || [ "$ORCID_RAW" = "null" ]; then
            ORCID_ID="Tidak tersedia"
            ORCID_URL_CSV=""
        else
            ORCID_ID=$(parse_orcid "$ORCID_RAW")
            ORCID_URL_CSV="https://orcid.org/${ORCID_ID}"
        fi

        AFFILIATIONS=$(echo "$FIRST_AUTHOR" | jq -r '
            [.affiliation // [] | .[] | .name // ""] | join("; ")
        ')
        [ -z "$AFFILIATIONS" ] && AFFILIATIONS="Tidak tersedia"

        echo "\"$((i + 1))\",\"$TITLE\",\"https://doi.org/$DOI\",\"$YEAR\",\"$AUTHOR_NAME\",\"$ORCID_ID\",\"$ORCID_URL_CSV\",\"$ORCID_AUTHENTICATED\",\"$AFFILIATIONS\"" >> "$CSV_FILE"
    done

    echo -e "${GREEN}[OK] File CSV tersimpan: ${CSV_FILE}${NC}"
}

# =============================================================================
# MAIN
# =============================================================================
check_dependencies
print_header
fetch_data
extract_affiliations
export_csv

echo -e "\n${GREEN}${BOLD}Selesai!${NC}\n"
