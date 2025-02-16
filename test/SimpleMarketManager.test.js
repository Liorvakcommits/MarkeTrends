const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleMarketManager", function () {
  let SimpleMarketManager;
  let simpleMarketManager;
  let owner;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    SimpleMarketManager = await ethers.getContractFactory("SimpleMarketManager");
    simpleMarketManager = await SimpleMarketManager.deploy();
    await simpleMarketManager.waitForDeployment();
  });

  it("Should create a new market", async function () {
    await expect(simpleMarketManager.createMarket("Test Market"))
      .to.emit(simpleMarketManager, "MarketCreated")
      .withArgs(1, "Test Market");

    const marketInfo = await simpleMarketManager.getMarketInfo(1);
    expect(marketInfo.name).to.equal("Test Market");
  });

  it("Should increment nextMarketId after creating a market", async function () {
    await simpleMarketManager.createMarket("Test Market 1");
    expect(await simpleMarketManager.nextMarketId()).to.equal(2);

    await simpleMarketManager.createMarket("Test Market 2");
    expect(await simpleMarketManager.nextMarketId()).to.equal(3);
  });
});