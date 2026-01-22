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
    if (action === 'block') {
        // Add to blocker's blockedUsers
        await User.findByIdAndUpdate(blockerId, { $addToSet: { blockedUsers: blockedId } });
        // Add to blocked's blockedByUsers
        await User.findByIdAndUpdate(blockedId, { $addToSet: { blockedByUsers: blockerId } });
    } else if (action === 'unblock') {
        // Remove
        await User.findByIdAndUpdate(blockerId, { $pull: { blockedUsers: blockedId } });
        await User.findByIdAndUpdate(blockedId, { $pull: { blockedByUsers: blockerId } });
    }
};
