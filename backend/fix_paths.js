const mongoose = require('mongoose');
const dotenv = require('dotenv');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/antigravity_chat';

const fixPaths = async () => {
    try {
        await mongoose.connect(MONGO_URI);
        console.log('Connected to MongoDB');

        const db = mongoose.connection.db;
        const usersCollection = db.collection('users');

        const result = await usersCollection.updateMany(
            { avatar: { $regex: "localhost" } },
            [
                {
                    $set: {
                        avatar: {
                            $replaceOne: {
                                input: "$avatar",
                                find: "http://localhost:5000",
                                replacement: ""
                            }
                        }
                    }
                }
            ]
        );

        console.log(`Updated ${result.modifiedCount} user documents.`);
        process.exit(0);
    } catch (error) {
        console.error('Error fixing paths:', error);
        process.exit(1);
    }
};

fixPaths();
