import React, { useState } from "react";
import { ethers } from "ethers";

const CreateMarket = () => {
  const [marketName, setMarketName] = useState("");
  const [expirationTime, setExpirationTime] = useState("");
  const [account, setAccount] = useState(null);
  const marketManagerAddress = "הכתובת של החוזה שלך";

  // יצירת שוק חדש
  const createMarket = async () => {
    if (!marketName || !expirationTime) {
      alert("Please enter market name and expiration time");
      return;
    }

    try {
      const provider = new ethers.JsonRpcProvider(window.ethereum); // השתמש ב-JsonRpcProvider
      const signer = provider.getSigner();
      const marketManager = new ethers.Contract(
        marketManagerAddress,
        [
          "function createMarket(string memory marketName, uint256 expirationTime) public returns (address)",
        ],
        signer
      );

      const tx = await marketManager.createMarket(marketName, parseInt(expirationTime));
      console.log("Market created: ", tx);
      alert("Market created successfully!");
    } catch (err) {
      console.error("Error creating market: ", err);
      alert("There was an error creating the market");
    }
  };

  // חיבור לארנק
  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.JsonRpcProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const address = await signer.getAddress();
        setAccount(address);
      } catch (err) {
        console.error("Failed to connect wallet:", err);
      }
    } else {
      alert("Please install MetaMask!");
    }
  };

  return (
    <div>
      <h1>Create Market</h1>
      <input
        type="text"
        placeholder="Market Name"
        value={marketName}
        onChange={(e) => setMarketName(e.target.value)}
      />
      <input
        type="number"
        placeholder="Expiration Time (Unix timestamp)"
        value={expirationTime}
        onChange={(e) => setExpirationTime(e.target.value)}
      />
      <button onClick={createMarket}>Create Market</button>
      {account && <h2>Connected to: {account}</h2>}
      <button onClick={connectWallet}>Connect Wallet</button>
    </div>
  );
};

export default CreateMarket;


