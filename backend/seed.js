const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('./src/models/User');

dotenv.config();

const seed = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/whatsapp_clone');
        console.log('✅ MongoDB Connected');

        // Fix: Drop conflicting index from old schema if it exists
        try {
            await mongoose.connection.collection('users').dropIndex('phoneNumber_1');
            console.log('✅ Dropped deprecated index: phoneNumber_1');
        } catch (e) {
            // Index might not exist, ignore
        }

        const dummyUsers = [
            {
                firebaseUid: 'user_alice',
                phone: '+15550101',
                name: 'Alice',
                about: 'Available',
                avatar: 'https://ui-avatars.com/api/?name=Alice&background=FFCDD2&color=fff'
            },
            {
                firebaseUid: 'user_bob',
                phone: '+15550102',
                name: 'Bob',
                about: 'Busy',
                avatar: 'https://ui-avatars.com/api/?name=Bob&background=C8E6C9&color=fff'
            },
            {
                firebaseUid: 'user_charlie',
                phone: '+15550103',
                name: 'Charlie',
                about: 'At the gym',
                avatar: 'https://ui-avatars.com/api/?name=Charlie&background=BBDEFB&color=fff'
            }
        ];

        for (const u of dummyUsers) {
            await User.findOneAndUpdate(
                { firebaseUid: u.firebaseUid },
                { $set: u },
                { upsert: true, new: true }
            );
            console.log(`User seeded: ${u.name} (${u.phone})`);
        }

        console.log('✅ Seeding Complete');
        process.exit(0);
    } catch (error) {
        console.error('Seeding Failed:', error);
        process.exit(1);
    }
};

seed();
