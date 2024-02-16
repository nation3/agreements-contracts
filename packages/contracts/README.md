# Nation3 Jurisdiction Smart Contracts

## Local build & testing

This repo uses Foundry. Install it as follows:
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependencies:
```
forge install
```

Build contracts:
```
forge build --via-ir
```
(You will need to use `--via-ir` to avoid stack too deep problems while building)

Run tests:
```
forge test
```

## Deployment
Before deployment, you should specify the ARBITRATION_TOKEN in script/deploy.sol, in this case, we use $NATION token 
```
    address ARBITRATION_TOKEN = 0x333A4823466879eeF910A04D473505da62142069; // Mainnet
```

Run the deploy script first to verify that can be broadcasted:
```
forge script DeployStack --rpc-url ${RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --optimize --optimizer-runs 20000 -vvvv --ffi --via-ir
```

Run again broadcasting to the desired chain:
```
forge script DeployStack --rpc-url ${RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY} --optimize --optimizer-runs 20000 -vvvv --ffi --via-ir --broadcast
```

## Verifying

Take a look at [Foundry Deploying and Verifying](https://book.getfoundry.sh/forge/deploying).

Forge's built-in verifying functionality use to fail with this codebase. To troubleshoot this, we manually verify with Etherscan using JSON-standard-input format. You can find the verification files under `build-inputs` directory.

Shortcut to get the latest input sources:
```
rm -r build-info;
forge build --force --optimize --optimizer-runs 20000 --build-info --build-info-path build-info;
jq .input build-info/*.json > inputs.json;
rm -r build-info;
```

Alternatively, we can use the Verify.ts script to verify contracts:
```
ts-node script/Verify.ts
```

You can find constructor arguments on Etherscan
![image](https://github.com/nation3/jurisdiction/assets/42999269/36b465e6-bd92-4f97-a46a-3bffcf032514)
