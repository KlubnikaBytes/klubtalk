const User = require('../models/User');

// Seed Dummy Users
const seedUsers = async (req, res) => {
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

    try {
        for (const u of dummyUsers) {
            await User.findOneAndUpdate(
                { firebaseUid: u.firebaseUid },
                { $set: u },
                { upsert: true, new: true }
            );
        }
        res.status(200).json({ message: 'Dummy users seeded successfully', count: dummyUsers.length });
    } catch (error) {
        console.error('Seeding Error:', error);
        res.status(500).json({ error: 'Seeding failed' });
    }
};

module.exports = { seedUsers };
