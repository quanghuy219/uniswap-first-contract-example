const { ethers, upgrades } = require("hardhat");

async function upgrade() {
    // Deploy the contract
    console.log("start deployment...")
    const SimpleSwap = await ethers.getContractFactory("SwapExamples");
    const simpleSwap = await upgrades.upgradeProxy("0x62805A97AA27D7173545b1692d54a2DdDC3dE7C2", SimpleSwap);
    console.log("Box upgraded");
}

upgrade().catch(err => {
    console.error(err)
    process.exitCode = 1
})
