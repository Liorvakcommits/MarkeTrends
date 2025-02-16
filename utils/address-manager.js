const fs = require('fs');
const path = require('path');

const ADDRESS_FILE = path.join(__dirname, '..', 'contract_addresses.json');

function getAddresses() {
  if (fs.existsSync(ADDRESS_FILE)) {
    return JSON.parse(fs.readFileSync(ADDRESS_FILE, 'utf8'));
  }
  return {};
}

function saveAddresses(addresses) {
  fs.writeFileSync(ADDRESS_FILE, JSON.stringify(addresses, null, 2));
}

function getAddress(contractName) {
  const addresses = getAddresses();
  return addresses[contractName];
}

function setAddress(contractName, address) {
  const addresses = getAddresses();
  addresses[contractName] = address;
  saveAddresses(addresses);
}

function updateFromTxtFile(filePath) {
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    const addresses = getAddresses();
    
    lines.forEach(line => {
      const [name, address] = line.split(':').map(s => s.trim());
      if (name && address) {
        addresses[name] = address;
      }
    });

    saveAddresses(addresses);
    console.log(`עודכנו כתובות מהקובץ ${filePath}`);
  }
}

module.exports = {
  getAddress,
  setAddress,
  getAddresses,
  saveAddresses,
  updateFromTxtFile
};