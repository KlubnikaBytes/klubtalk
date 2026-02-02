require('dotenv').config();
const mongoose = require('mongoose');

const testConnection = async () => {
    console.log("Testing connection to:", process.env.MONGO_URI.replace(/:([^:@]+)@/, ':****@')); // Hide password in log
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log("✅ Connection Successful!");
        process.exit(0);
    } catch (error) {
        console.error("❌ Connection Failed:", error.message);
        console.error("Full Error:", error);
        process.exit(1);
    }
};

testConnection();
