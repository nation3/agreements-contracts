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
  await verifyArbitrationToken("0x23Ca3002706b71a440860E3cf8ff64679A00C9d7", "lib/solmate/src/test/utils/mocks/MockERC20.sol:MockERC20")
  await verifyArbitrator("0xBe67cEdCD1FE38aac8a5781A51250FDeFB344E6C", "src/Arbitrator.sol:Arbitrator")
  await verifyCollateralAgreementFramework("0xD96aA6e2568f4e9632D2A5234Bb8410ca7609a27", "src/frameworks/CollateralAgreement.sol:CollateralAgreement")
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
