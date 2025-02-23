import React, { useState } from "react";
import { ethers } from "ethers";

const ConnectWallet = () => {
  const [account, setAccount] = useState(null);

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);  // מבקש גישה לחשבון
        const signer = provider.getSigner();  // מקבל את ה-signer
        const address = await signer.getAddress();  // מקבל את כתובת הארנק
        setAccount(address); // מציג את כתובת הארנק שהחובר
        console.log("Wallet connected:", address); // הדפסת הכתובת לקונסול
      } catch (err) {
        console.error("Failed to connect wallet:", err);
      }
    } else {
      alert("Please install MetaMask!");
    }
  };

  const connectInfura = async () => {
    try {
      // חיבור ל-Infura עם JsonRpcProvider הנכון
      const infuraProvider = new ethers.JsonRpcProvider('https://mainnet.infura.io/v3/910875bd8abb4bb8bd3d47eab837019d');
      const network = await infuraProvider.getNetwork();  // מקבל את הרשת
      console.log("Connected to Infura on network:", network);
      alert("Connected to Infura!");
    } catch (err) {
      console.error("Error connecting to Infura:", err);
      alert("Failed to connect to Infura.");
    }
  };

  return (
    <div>
      {account ? (
        <div>
          <h2>Connected to: {account}</h2>
        </div>
      ) : (
        <button onClick={connectWallet}>Connect Wallet</button>
      )}
      <button onClick={connectInfura}>Connect to Infura</button>
    </div>
  );
};

export default ConnectWallet;




