# KRChange Dex

Settable fee v2 dex for Kasplex

## Deployments

### Kasplex Testnet

| Contract   | Address |
| ---------- | ------- |
| Factory    |         |
| Router     |         |
| FarmMaster |         |
| AmmZapV1   |         |

### Kasplex Mainnet

| Contract   | Address |
| ---------- | ------- |
| Factory    |         |
| Router     |         |
| FarmMaster |         |
| AmmZapV1   |         |

## build

forge build --via-ir

## deployment

Key variables are set in the script, and should be updated correctly for the network.

forge script script/v2/FactoryPlusRouter.s.sol:FactoryPlusRouter --broadcast --verify -vvv --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
