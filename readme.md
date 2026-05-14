# ShipStation API Partner Sandbox Demo

This bash script exercises the full partner-to-seller flow against the ShipStation API using a sandbox partner account.

### What it does:

1. Creates a new sub-account (seller) under a Partner API key.
2. Creates a primary warehouse with test addresses.
3. Registers three carriers for the seller: Stamps.com (USPS), DHL Express and UPS.
4. Generates domestic and international rates.
5. Generates test shipping labels for the selected rates.
6. Re-run the script to add additional accounts linked to the Partner API key

### Prerequisites

- `jq` must be installed on your machine (e.g. `brew install jq`).
- A valid ShipStation API Partner Sandbox API Key (e.g. TEST_XXXXXX)

### How to Run

Provide your sandbox API key as an environment variable when executing the script:

```bash
chmod +x partner-sandbox-demo.sh
export PARTNER_API_KEY="your_partner_sandbox_key"
./partner-sandbox-demo.sh

### Acknowledgements
* Original script provided by Auctane Co-Worker for testing the ShipStation API Partner Sandbox flow.
* Maintained by Peter McGee.

```
