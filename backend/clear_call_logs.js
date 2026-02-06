const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Call = require('./src/models/Call');

dotenv.config();

const clearLogs = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ Connected to MongoDB');

        const result = await Call.deleteMany({});
        console.log(`🗑️ Deleted ${result.deletedCount} call logs.`);

        await mongoose.disconnect();
        console.log('👋 Disconnected');
    } catch (error) {
        console.error('❌ Error clearing logs:', error);
        process.exit(1);
    }
};

clearLogs();
