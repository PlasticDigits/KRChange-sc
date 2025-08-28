# KRChange Dex

Settable fee v2 dex for Kasplex

## Deployments

### Kasplex Testnet

| Contract | Address                                    |
| -------- | ------------------------------------------ |
| Factory  | 0xa1b0785Cb418D666BE9069400f4d4D7a86e3F5e0 |
| Router   | 0x820d8AE8378eD32eFfa50C93A0ee06e5942FB175 |
| AmmZapV1 | 0x991291B2bB4c49228a687CeD72EABd34d7Aeaa0b |

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

forge script script/DeployDex.s.sol:DeployDex --broadcast --verify -vvv --rpc-url https://rpc.kasplextest.xyz --verifier blockscout --verifier-url 'https://explorer.testnet.kasplextest.xyz/api/' -i 1 --sender $DEPLOYER_ADDRESS

# LICENSE

License: AGPL-3.0 — see [LICENSE](./LICENSE).
