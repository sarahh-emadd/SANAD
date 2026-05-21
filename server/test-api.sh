#!/bin/bash

API="http://localhost:3000"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 SANAD API Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Root
echo "1️⃣  Testing Root Endpoint"
curl -s $API/ | jq '.'
echo ""

# Test 2: Health Check
echo "2️⃣  Testing Health Check"
curl -s $API/api/v1/health | jq '.'
echo ""

# Test 3: Auth Sync (should fail - invalid Firebase UID)
echo "3️⃣  Testing Auth Sync (expect error)"
curl -s -X POST $API/api/v1/auth/sync \
  -H "Content-Type: application/json" \
  -d '{
    "firebase_uid": "test123",
    "email": "test@example.com",
    "name": "Test User"
  }' | jq '.'
echo ""

# Test 4: QR Connect (should fail - missing token)
echo "4️⃣  Testing QR Connect (expect error)"
curl -s -X POST $API/api/v1/qr/connect \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
echo ""

# Test 5: QR Verify (should fail - missing token)
echo "5️⃣  Testing QR Verify (expect error)"
curl -s -X POST $API/api/v1/qr/verify \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
echo ""

# Test 6: Elderly List (should fail - no auth)
echo "6️⃣  Testing Elderly List (expect error)"
curl -s $API/api/v1/elderly | jq '.'
echo ""

# Test 7: 404 Route
echo "7️⃣  Testing 404 (non-existent route)"
curl -s $API/api/v1/nonexistent | jq '.'
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All tests completed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"