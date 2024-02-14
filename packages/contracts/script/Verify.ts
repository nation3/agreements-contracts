import { exec } from "child_process";

const verifyArbitrationToken = async (address: string, path: string) => {
  exec(
    ["forge verify-contract", address, path, "--constructor-args", "000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000b436f75727420546f6b656e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024354000000000000000000000000000000000000000000000000000000000000", "--chain-id", 11155111, "--etherscan-api-key", "6EI6Z7T8UAAVRIY8JXRXKVKM5A1WH8PURD"].join(" "),
    (error, stdout, stderr) => {
      console.log(error)
      console.log(stdout)
      console.log(stderr)
    }
  );
}


const verifyArbitrator = async (address: string, path: string) => {
  exec(
    ["forge verify-contract", address, path, "--constructor-args", "000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba30000000000000000000000000c47a93ffca9bc0b116d055f2a062b625481677d", "--chain-id", 11155111, "--etherscan-api-key", "6EI6Z7T8UAAVRIY8JXRXKVKM5A1WH8PURD"].join(" "),
    (error, stdout, stderr) => {
      console.log(error)
      console.log(stdout)
      console.log(stderr)
    }
  );
}
const verifyCollateralAgreementFramework = async (address: string, path: string) => {
  exec(
    ["forge verify-contract", address, path, "--constructor-args", "000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba30000000000000000000000000c47a93ffca9bc0b116d055f2a062b625481677d", "--chain-id", 11155111, "--etherscan-api-key", "6EI6Z7T8UAAVRIY8JXRXKVKM5A1WH8PURD"].join(" "),
    (error, stdout, stderr) => {
      console.log(error)
      console.log(stdout)
      console.log(stderr)
    }
  );
}
const main = async () => {
  console.log("Contract verification...")
  await verifyArbitrationToken("0xF35121DAf5895bc3595a8271Ab8a746E2df4403b", "lib/solmate/src/test/utils/mocks/MockERC20.sol:MockERC20")
  await verifyArbitrator("0xb6deAC61E2011301D771750368d2616df9941C67", "src/Arbitrator.sol:Arbitrator")
  await verifyCollateralAgreementFramework("0x663cF9E09A82057defC2d574472B010b4d9e9Cf6", "src/frameworks/CollateralAgreement.sol:CollateralAgreement")
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
