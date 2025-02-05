# השתמש בתמונה בסיסית של Node.js
FROM node:18

# הגדר את תיקיית העבודה
WORKDIR /app

# העתק את קובץ ה-package.json ואת כל שאר הקבצים
COPY package.json package-lock.json ./

# התקן את התלויות
RUN npm install

# העתק את שאר הקבצים לתוך הקונטיינר
COPY . .

# הפעל את ה־Hardhat Node בעת הפעלת הקונטיינר
CMD ["npx", "hardhat", "node"]

