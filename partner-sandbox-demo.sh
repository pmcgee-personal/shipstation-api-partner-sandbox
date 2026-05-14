#!/usr/bin/env bash
#
# Partner Sandbox Demo
#
# Exercises the full partner -> seller -> carrier registration -> rate -> label flow
# against the ShipStation API using a sandbox partner account.
# Note that the sandbox environment has some limitations and may not perfectly reflect production behavior, especially around account creation and carrier registration. In a real integration, you would want to implement retry logic and more robust error handling to account for eventual consistency and other issues.
# For now this script waits 30 seconds after account creation for propagation, then runs all steps without retrying.
#
# Required env vars:
#   PARTNER_API_KEY  - API key for the sandbox partner account
#
# Optional env vars:
#   BASE_URL         - API base URL (default: https://api.shipengine.com)

set -euo pipefail

if [[ -z "${PARTNER_API_KEY:-}" ]]; then
  echo "ERROR: PARTNER_API_KEY environment variable is required"
  exit 1
fi

BASE_URL="${BASE_URL:-https://api.shipengine.com}"
BASE_URL="${BASE_URL%/}"

# Addresses
read -r -d '' TEST_ADDRESS << 'EOF' || true
{
  "name": "John Doe",
  "phone": "512-555-1234",
  "company_name": "Example Corp",
  "address_line1": "4009 Marathon Blvd",
  "address_line2": "Suite 300",
  "city_locality": "Austin",
  "state_province": "TX",
  "postal_code": "78756",
  "country_code": "US"
}
EOF

read -r -d '' DEST_ADDRESS << 'EOF' || true
{
  "name": "Jane Smith",
  "phone": "213-555-5678",
  "company_name": "Receiving Inc",
  "address_line1": "525 S Virgil Ave",
  "city_locality": "Los Angeles",
  "state_province": "CA",
  "postal_code": "90020",
  "country_code": "US"
}
EOF

read -r -d '' INTL_DEST_ADDRESS << 'EOF' || true
{
  "name": "James Wilson",
  "phone": "+44-20-7946-0958",
  "company_name": "UK Imports Ltd",
  "address_line1": "10 Downing Street",
  "city_locality": "London",
  "state_province": "England",
  "postal_code": "SW1A 2AA",
  "country_code": "GB"
}
EOF

read -r -d '' PACKAGE << 'EOF' || true
{
  "weight": {"value": 1.0, "unit": "pound"},
  "dimensions": {"length": 6.0, "width": 4.0, "height": 3.0, "unit": "inch"}
}
EOF

read -r -d '' CUSTOMS << 'EOF' || true
{
  "contents": "merchandise",
  "customs_items": [
    {
      "description": "Test item",
      "quantity": 1,
      "value": {"amount": 25.00, "currency": "USD"},
      "country_of_origin": "US"
    }
  ],
  "non_delivery": "return_to_sender"
}
EOF

# Helper: POST as partner (no on-behalf-of)
partner_post() {
  local url="$1"
  local body="$2"

  echo ""
  echo "=== POST ${url}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$url" \
    -H "Content-Type: application/json" \
    -H "api-key: ${PARTNER_API_KEY}" \
    -d "$body")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
    echo "  FAILED: ${HTTP_CODE} ${BODY}"
    exit 1
  fi
  echo "  ${HTTP_CODE} OK"
}

# Helper: POST as seller (with on-behalf-of)
seller_post() {
  local url="$1"
  local body="$2"

  echo ""
  echo "=== POST ${url}"
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$url" \
    -H "Content-Type: application/json" \
    -H "api-key: ${PARTNER_API_KEY}" \
    -H "on-behalf-of: ${ACCOUNT_ID}" \
    -d "$body")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
    echo "  FAILED: ${HTTP_CODE} ${BODY}"
    return 1
  fi
  echo "  ${HTTP_CODE} OK"
}

# --- Step 1: Create account ---

UNIQUE=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
partner_post "${BASE_URL}/v1/partners/accounts" \
  "{
    \"first_name\": \"Test\",
    \"last_name\": \"Seller\",
    \"email\": \"test-seller-${UNIQUE}@example.com\",
    \"company_name\": \"Test Seller Co ${UNIQUE}\",
    \"origin_country_code\": \"US\"
  }"

ACCOUNT_ID=$(echo "$BODY" | jq -r '.account_id')
echo "  Account ID: ${ACCOUNT_ID}"

echo ""
echo "=== Waiting 30 seconds for account propagation..."
sleep 30
echo "  Done waiting."

# --- Step 2: Create warehouse ---

seller_post "${BASE_URL}/v1/warehouses" \
  "{
    \"name\": \"Primary Warehouse\",
    \"origin_address\": ${TEST_ADDRESS},
    \"return_address\": ${TEST_ADDRESS}
  }" || exit 1

WAREHOUSE_ID=$(echo "$BODY" | jq -r '.warehouse_id')
echo "  Warehouse ID: ${WAREHOUSE_ID}"

# --- Step 3: Register Stamps.com ---

UNIQUE=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
seller_post "${BASE_URL}/v1/registration/stamps_com" \
  "{
    \"nickname\": \"stamps-${UNIQUE}\",
    \"email\": \"stamps-${UNIQUE}@example.com\",
    \"agree_to_carrier_terms\": true,
    \"address\": ${TEST_ADDRESS}
  }" || exit 1

STAMPS_CARRIER_ID=$(echo "$BODY" | jq -r '.carrier_id')
echo "  Carrier ID: ${STAMPS_CARRIER_ID}"

# --- Step 4: Register DHL Express Walleted ---

UNIQUE=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
seller_post "${BASE_URL}/v1/registration/dhl_express_walleted" \
  "{\"nickname\": \"dhl-${UNIQUE}\"}" || exit 1

DHL_CARRIER_ID=$(echo "$BODY" | jq -r '.carrier_id')
echo "  Carrier ID: ${DHL_CARRIER_ID}"

# --- Step 5: Register UPS ---

UNIQUE=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
seller_post "${BASE_URL}/v1/registration/ups" \
  "{
    \"nickname\": \"ups-${UNIQUE}\",
    \"email\": \"ups-${UNIQUE}@example.com\",
    \"address\": ${TEST_ADDRESS},
    \"accepted_terms\": [
      {\"term_type\": \"ups_technology_agreement\", \"version\": \"1\"},
      {\"term_type\": \"ups_prohibited_items\", \"version\": \"1\"}
    ],
    \"end_user_ip_address\": \"127.0.0.1\"
  }" || exit 1

UPS_CARRIER_ID=$(echo "$BODY" | jq -r '.carrier_id')
echo "  Carrier ID: ${UPS_CARRIER_ID}"

# --- Step 6: Get rates and create labels for each carrier ---

ANY_FAILED=false

get_rates_and_label() {
  local carrier_name="$1"
  local carrier_id="$2"
  local dest_address="$3"
  local is_international="$4"

  # Build rate shipment
  local shipment
  if [[ "$is_international" == "true" ]]; then
    shipment=$(jq -n \
      --argjson ship_from "$TEST_ADDRESS" \
      --argjson ship_to "$dest_address" \
      --argjson packages "[$PACKAGE]" \
      --argjson customs "$CUSTOMS" \
      '{ship_from: $ship_from, ship_to: $ship_to, packages: $packages, customs: $customs}')
  else
    shipment=$(jq -n \
      --argjson ship_from "$TEST_ADDRESS" \
      --argjson ship_to "$dest_address" \
      --argjson packages "[$PACKAGE]" \
      '{ship_from: $ship_from, ship_to: $ship_to, packages: $packages}')
  fi

  local rate_body
  rate_body=$(jq -n \
    --argjson shipment "$shipment" \
    --argjson carrier_ids "[\"$carrier_id\"]" \
    '{shipment: $shipment, rate_options: {carrier_ids: $carrier_ids}, rate_type: "quick"}')

  seller_post "${BASE_URL}/v1/rates" "$rate_body" || {
    echo "  ${carrier_name}: RATES FAILED"
    ANY_FAILED=true
    return
  }

  local rates rate_count
  rates=$(echo "$BODY" | jq '.rate_response.rates')
  rate_count=$(echo "$rates" | jq 'length')

  # Print errors if any
  echo "$BODY" | jq -r '.rate_response.errors[]?.message // empty' | while read -r msg; do
    echo "  Rate error: ${msg}"
  done

  if [[ "$rate_count" -eq 0 ]]; then
    echo "  No rates returned"
    echo "$BODY" | jq -r '.rate_response.invalid_rates[]? | "    \(.service_code): \(.error_messages | join("; "))"'
    echo "  ${carrier_name}: NO RATES"
    ANY_FAILED=true
    return
  fi

  echo "$rates" | jq -r '.[] | "  \(.service_code) @ $\(.shipping_amount.amount)"'

  local selected_service selected_carrier_id
  selected_service=$(echo "$rates" | jq -r '.[0].service_code')
  selected_carrier_id=$(echo "$rates" | jq -r '.[0].carrier_id')
  echo "  Selected: ${selected_service}"

  # Build label shipment
  local label_shipment
  if [[ "$is_international" == "true" ]]; then
    label_shipment=$(jq -n \
      --arg carrier_id "$selected_carrier_id" \
      --arg service_code "$selected_service" \
      --argjson ship_from "$TEST_ADDRESS" \
      --argjson ship_to "$dest_address" \
      --argjson packages "[$PACKAGE]" \
      --argjson customs "$CUSTOMS" \
      '{carrier_id: $carrier_id, service_code: $service_code, ship_from: $ship_from, ship_to: $ship_to, packages: $packages, customs: $customs}')
  else
    label_shipment=$(jq -n \
      --arg carrier_id "$selected_carrier_id" \
      --arg service_code "$selected_service" \
      --argjson ship_from "$TEST_ADDRESS" \
      --argjson ship_to "$dest_address" \
      --argjson packages "[$PACKAGE]" \
      '{carrier_id: $carrier_id, service_code: $service_code, ship_from: $ship_from, ship_to: $ship_to, packages: $packages}')
  fi

  local label_body
  label_body=$(jq -n --argjson shipment "$label_shipment" '{shipment: $shipment}')

  seller_post "${BASE_URL}/v1/labels" "$label_body" || {
    echo "  ${carrier_name}: LABEL FAILED"
    ANY_FAILED=true
    return
  }

  echo "  Label ID: $(echo "$BODY" | jq -r '.label_id')"
  local pdf_url
  pdf_url=$(echo "$BODY" | jq -r '.label_download.pdf // empty')
  if [[ -n "$pdf_url" ]]; then
    echo "  PDF: ${pdf_url}"
  fi
  echo "  ${carrier_name}: OK"
}

get_rates_and_label "USPS (via Stamps.com)" "$STAMPS_CARRIER_ID" "$DEST_ADDRESS" "false"
get_rates_and_label "DHL Express" "$DHL_CARRIER_ID" "$INTL_DEST_ADDRESS" "true"
get_rates_and_label "UPS" "$UPS_CARRIER_ID" "$DEST_ADDRESS" "false"

# --- Summary ---

if [[ "$ANY_FAILED" == "true" ]]; then
  echo ""
  echo "Some carriers failed."
  exit 1
fi
echo ""
echo "=== All carriers completed successfully."
