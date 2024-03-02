# Nation3 Agreement Smart Contracts

This repository contains the smart contracts and core infrastructure for the Nation3 Agreements.

## User Interface

See https://github.com/nation3/agreements-app

## Documentation

https://github.com/nation3/agreements-app/blob/main/README.md#documentation

## How to deploy/redeploy subgraph
Update `networks.json` file before deploying subgraph

#### Mainnet
```
yarn auth
yarn codegen
yarn build-mainnet 
yarn deploy-mainnet
```

#### Sepolia  
```
yarn auth
yarn codegen
yarn build-sepolia
yarn deploy-sepolia
```
