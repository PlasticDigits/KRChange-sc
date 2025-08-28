# KRChange Dex

Settable fee v2 dex for Kasplex

## Deployments

### Kasplex Testnet

| Contract | Address |
| -------- | ------- |
| Factory  |         |
| Router   |         |
| AmmZapV1 |         |

### Kasplex Mainnet

| Contract | Address |
| -------- | ------- |
| Factory  |         |
| Router   |         |
| AmmZapV1 |         |

## build

forge build --via-ir

## deployment

Key variables are set in the script, and should be updated correctly for the network.

forge script script/v2/DeployDex.s.sol:DeployDex --broadcast --verify -vvv --rpc-url $RPC_URL --verifier blockscout --verifier-url 'https://explorer.testnet.kasplextest.xyz/api/' -i 1 --sender $DEPLOYER_ADDRESS
