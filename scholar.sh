#!/bin/bash
# scholar.sh
# Usage: ./scholar.sh "Author Name" YOUR_SERPAPI_KEY

AUTHOR_NAME="$1"
API_KEY="$2"

if [[ -z "$AUTHOR_NAME" || -z "$API_KEY" ]]; then
  echo "Usage: $0 \"Author Name\" YOUR_SERPAPI_KEY"
  echo "Contoh: $0 \"Nur Aini Rakhmawati\" xxxxxxxxxxxxxxxx"
  exit 1
fi

# Encode nama untuk URL
ENCODED_NAME=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote_plus(sys.argv[1]))" "$AUTHOR_NAME")

URL="https://serpapi.com/search.json?engine=google_scholar&q=%22${ENCODED_NAME}%22&api_key=${API_KEY}"

echo "Mencari: $AUTHOR_NAME"
echo "-------------------------------------------"

# Ambil response
RESPONSE=$(curl -s "$URL")

# Cek error API
API_ERROR=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('error', ''))
" 2>/dev/null)

if [[ -n "$API_ERROR" ]]; then
  echo "Error: $API_ERROR"
  exit 1
fi

# Parse name & affiliations dari profiles.authors
echo "$RESPONSE" | python3 -c "
import sys, json

data = json.load(sys.stdin)

# Ambil profiles -> authors
authors = data.get('profiles', {}).get('authors', [])

if not authors:
    print('Tidak ada profil ditemukan.')
    sys.exit(0)

for author in authors:
    name        = author.get('name', 'N/A')
    affiliation = author.get('affiliations', 'N/A')
    print(f'Name        : {name}')
    print(f'Affiliations: {affiliation}')
    print()
"
