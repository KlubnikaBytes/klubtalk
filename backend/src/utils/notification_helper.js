const { admin } = require('../config/firebase');
const User = require('../models/User');

/**
 * Send a message notification to a user via data-only FCM
 * Data-only messages ensure instant delivery in all app states
 * @param {String} recipientId - User ID of the recipient
 * @param {String} senderName - Name of the message sender
 * @param {String} messageText - Content of the message
 * @param {Object} data - Additional data { chatId, messageId, senderId }
 */
async function sendMessageNotification(recipientId, senderName, messageText, data) {
    try {
        const recipient = await User.findById(recipientId);
        if (!recipient || !recipient.fcmToken) {
            console.log(`No FCM token for user ${recipientId}`);
            return;
        }

        // DATA-ONLY message - no notification field for instant delivery
        const message = {
            token: recipient.fcmToken,
            data: {
                type: 'message',
                chatId: data.chatId || '',
                senderName: senderName,
                message: messageText,
                messageId: data.messageId || '',
                senderId: data.senderId || ''
            },
            android: {
                priority: 'high'  // Critical for instant delivery
            }
        };

        const response = await admin.messaging().send(message);
        console.log(`Data-only message notification sent to ${recipientId}`);
    } catch (error) {
        console.error('Error sending message notification:', error);
        // If token is invalid, clear it from the database
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
            await User.findByIdAndUpdate(recipientId, { fcmToken: '' });
            console.log(`Cleared invalid FCM token for user ${recipientId}`);
        }
    }
}

/**
 * Send a call notification to a user
 * @param {String} recipientId - User ID of the recipient
 * @param {String} callerName - Name of the caller
 * @param {String} callType - 'voice' or 'video'
 * @param {Object} callData - Call data including offer, from, etc.
 */
async function sendCallNotification(recipientId, callerName, callType, callData) {
    try {
        const recipient = await User.findById(recipientId);
        if (!recipient || !recipient.fcmToken) {
            console.log(`No FCM token for user ${recipientId}`);
            return;
        }

        // DATA-ONLY for Calls (Let Flutter build the UI with Actions)
        const message = {
            token: recipient.fcmToken,
            data: {
                type: 'call',
                callType: callType,
                callerId: callData.from,
                callerName: callerName,
                callId: (callData.callId || '').toString(), // Send Call ID
                // offer: REMOVED to prevent "Payload too big"
                chatId: callData.chatId || ''
            },
            android: {
                priority: 'high',
                ttl: 30000, // 30s expiry
            },
            apns: {
                headers: {
                    'apns-priority': '10',
                },
                payload: {
                    aps: {
                        alert: {
                            title: `Incoming ${callType} call`,
                            body: `${callerName} is calling...`,
                        },
                        sound: 'default',
                        'content-available': 1,
                    },
                },
            },
        };

        const response = await admin.messaging().send(message);
        console.log(`Call notification sent to ${recipientId}:`, response);
    } catch (error) {
        console.error('Error sending call notification:', error);
        // If token is invalid, clear it from the database
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
            await User.findByIdAndUpdate(recipientId, { fcmToken: '' });
            console.log(`Cleared invalid FCM token for user ${recipientId}`);
        }
    }
}

/**
 * Send notification to cancel message notification when read
 * @param {String} recipientId - User ID to cancel notification for
 * @param {String} messageId - Message ID to cancel
 */
async function sendMessageReadNotification(recipientId, messageId) {
    try {
        const recipient = await User.findById(recipientId);
        if (!recipient || !recipient.fcmToken) return;

        const message = {
            token: recipient.fcmToken,
            data: {
                type: 'message_read',
                messageId: messageId
            }
        };

        await admin.messaging().send(message);
        console.log(`Message read notification sent to ${recipientId} for message ${messageId}`);
    } catch (error) {
        console.error('Error sending message read notification:', error);
    }
}

/**
 * Send notification to cancel call notification (missed/ended)
 * @param {String} recipientId - User ID
 */
async function sendCallEndNotification(recipientId) {
    try {
        const recipient = await User.findById(recipientId);
        if (!recipient || !recipient.fcmToken) return;

        const message = {
            token: recipient.fcmToken,
            data: {
                type: 'call_end',
            },
            android: { priority: 'high' }
        };

        await admin.messaging().send(message);
        console.log(`Call END notification sent to ${recipientId}`);
    } catch (error) {
        console.error('Error sending call end notification:', error);
    }
}

/**
 * Send notification to reject call (Caller receives this)
 * @param {String} recipientId - User ID (The Caller)
 */
async function sendCallRejectNotification(recipientId) {
    try {
        const recipient = await User.findById(recipientId);
        if (!recipient || !recipient.fcmToken) return;

        const message = {
            token: recipient.fcmToken,
            data: {
                type: 'call_reject',
                reason: 'busy'
            },
            android: { priority: 'high' }
        };

        await admin.messaging().send(message);
        console.log(`Call REJECT notification sent to ${recipientId}`);
    } catch (error) {
        console.error('Error sending call reject notification:', error);
    }
}

module.exports = {
    sendMessageNotification,
    sendCallNotification,
    sendMessageReadNotification,
    sendCallEndNotification,
    sendCallRejectNotification,
};
