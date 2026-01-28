const User = require('../models/User');

/**
 * Check if there is a block relationship between two users.
 * Returns true if userA blocks userB OR userB blocks userA.
 * @param {string} userIdA 
 * @param {string} userIdB 
 * @returns {Promise<boolean>}
 */
exports.isBlocked = async (userIdA, userIdB) => {
    try {
        if (!userIdA || !userIdB) return false;
        if (userIdA.toString() === userIdB.toString()) return false;

        // Check if A blocks B or B blocks A
        // We can query just one user if relations are synced, but better to query both OR find one doc with strict check
        // Optimization: Find User A and check both fields?
        // Since we explicitly sync blockedUsers and blockedByUsers, we only need to check one user.
        // But to be 100% safe against sync drift, we can check both.
        // Let's check efficient $or query.

        const count = await User.countDocuments({
            $or: [
                { _id: userIdA, blockedUsers: userIdB },      // A blocks B
                { _id: userIdA, blockedByUsers: userIdB },    // A is blocked by B
                { _id: userIdB, blockedUsers: userIdA },      // B blocks A
                { _id: userIdB, blockedByUsers: userIdA }     // B is blocked by A
            ]
        });

        return count > 0;
    } catch (e) {
        console.error("isBlocked Check Error:", e);
        return false; // Fail safe? Or Fail strict? Fail safe allowing usually.
    }
};

/**
 * Update block status.
 * @param {string} blockerId 
 * @param {string} blockedId 
 * @param {string} action 'block' or 'unblock'
 */
exports.modifyBlock = async (blockerId, blockedId, action) => {
    const mongoose = require('mongoose');

    // CRITICAL VALIDATION: Prevent empty strings and invalid IDs
    if (!blockerId || !blockedId) {
        throw new Error('Both blockerId and blockedId are required');
    }

    if (blockerId.toString().trim() === '' || blockedId.toString().trim() === '') {
        throw new Error('User IDs cannot be empty strings');
    }

    if (!mongoose.Types.ObjectId.isValid(blockerId)) {
        throw new Error(`Invalid blockerId: ${blockerId}`);
    }

    if (!mongoose.Types.ObjectId.isValid(blockedId)) {
        throw new Error(`Invalid blockedId: ${blockedId}`);
    }

    // Prevent self-blocking
    if (blockerId.toString() === blockedId.toString()) {
        throw new Error('Cannot block yourself');
    }

    if (action === 'block') {
        console.log(`🚫 Blocking: ${blockerId} blocks ${blockedId}`);
        // Add to blocker's blockedUsers
        await User.findByIdAndUpdate(blockerId, { $addToSet: { blockedUsers: blockedId } });
        // Add to blocked's blockedByUsers
        await User.findByIdAndUpdate(blockedId, { $addToSet: { blockedByUsers: blockerId } });
    } else if (action === 'unblock') {
        console.log(`✅ Unblocking: ${blockerId} unblocks ${blockedId}`);
        // Remove
        await User.findByIdAndUpdate(blockerId, { $pull: { blockedUsers: blockedId } });
        await User.findByIdAndUpdate(blockedId, { $pull: { blockedByUsers: blockerId } });
    }
};
