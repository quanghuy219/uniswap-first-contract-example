const { ethers, upgrades } = require("hardhat");

async function deploy() {
    // Deploy the contract
    console.log("start deployment...")
    const SimpleSwap = await ethers.getContractFactory("SwapExamples");
    const simpleSwap = await upgrades.deployProxy(SimpleSwap, ["0xE592427A0AEce92De3Edee1F18E0157C05861564"]);

    await simpleSwap.waitForDeployment()

    console.log(await simpleSwap.getAddress()," SimpleSwap(proxy) address")
    // console.log(simpleSwap.getImplementationAddress()," getImplementationAddress")
    // console.log(simpleSwap.getContractFactory())," getAdminAddress")
}

deploy().catch(err => {
    console.error(err)
    process.exitCode = 1
})
