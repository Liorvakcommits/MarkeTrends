const fs = require("fs");
const path = require("path");

async function main() {
    const deploymentPath = path.join(__dirname, "deployed_addresses.json");
    const metadataPath = path.join(__dirname, "../metadata/mtc.json");

    // בדיקה אם הקבצים קיימים
    if (!fs.existsSync(deploymentPath)) {
        console.error("❌ קובץ הכתובות המפורסות לא נמצא!");
        process.exit(1);
    }

    if (!fs.existsSync(metadataPath)) {
        console.error("❌ קובץ ה-metadata לא נמצא!");
        process.exit(1);
    }

    // קריאת הכתובות המפורסות
    const deployedAddresses = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
    const mtcAddress = deployedAddresses.MTC;

    if (!mtcAddress) {
        console.error("❌ כתובת ה-MTC לא נמצאה בקובץ הכתובות המפורסות!");
        process.exit(1);
    }

    // קריאה ועדכון ה-metadata
    const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
    metadata.contractAddress = mtcAddress;

    // עדכון שדות נוספים ב-metadata
    metadata.lastUpdated = new Date().toISOString();
    metadata.network = process.env.HARDHAT_NETWORK || "unknown";

    // שמירת ה-metadata המעודכן
    fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 4));

    console.log(`✅ Metadata עודכן בהצלחה:`);
    console.log(`🔹 כתובת חוזה: ${mtcAddress}`);
    console.log(`🔹 תאריך עדכון: ${metadata.lastUpdated}`);
    console.log(`🔹 רשת: ${metadata.network}`);
}

main().catch((error) => {
    console.error("❌ עדכון ה-metadata נכשל:", error);
    process.exit(1);
});
