const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🚀 פריסת MarkeTrends Coins (MTC)...");

    const [deployer] = await hre.ethers.getSigners();
    console.log("🔹 כתובת המפיץ:", deployer.address);

    // יצירת חוזה ERC-20
    const MTC = await hre.ethers.getContractFactory("MTC");
    const initialSupply = hre.ethers.parseUnits("1000000", 18); // 1,000,000 MTC
    const mtcToken = await MTC.deploy(initialSupply);

    await mtcToken.waitForDeployment();

    const mtcAddress = await mtcToken.getAddress();
    console.log("✅ MarkeTrends Coins (MTC) נפרס בכתובת:", mtcAddress);

    const deploymentPath = path.join(__dirname, "deployed_addresses.json");
    let deployedAddresses = {};
    if (fs.existsSync(deploymentPath)) {
        deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    }
    deployedAddresses.MTC = mtcAddress;
    fs.writeFileSync(deploymentPath, JSON.stringify(deployedAddresses, null, 2));
    console.log("📄 כתובת MTC נשמרה בקובץ deployed_addresses.json");

    // עדכון ה-metadata
    const metadataPath = path.join(__dirname, "../metadata/mtc.json");
    if (fs.existsSync(metadataPath)) {
        const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
        metadata.contractAddress = mtcAddress;
        fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
        console.log("✅ Metadata עודכן בהצלחה עם כתובת החוזה החדשה");
    } else {
        console.warn("⚠️ קובץ ה-metadata לא נמצא. יש ליצור אותו ידנית.");
    }

    // הדפסת מידע נוסף
    console.log("\n📊 מידע נוסף על הטוקן:");
    console.log(`🔸 שם: ${await mtcToken.name()}`);
    console.log(`🔸 סימול: ${await mtcToken.symbol()}`);
    console.log(`🔸 מספר עשרונות: ${await mtcToken.decimals()}`);
    console.log(`🔸 סך האספקה ההתחלתית: ${hre.ethers.formatUnits(initialSupply, 18)} MTC`);
}

main().catch((error) => {
    console.error("❌ הפריסה נכשלה:", error);
    process.exitCode = 1;
});