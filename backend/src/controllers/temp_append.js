
exports.clearCallLogs = async (req, res) => {
    try {
        const result = await Call.deleteMany({});
        console.log(`🧹 [API] Cleared ${result.deletedCount} call logs via HTTP request`);
        res.status(200).json({ message: 'Call logs cleared', count: result.deletedCount });
    } catch (error) {
        console.error('❌ [API] Error clearing call logs:', error);
        res.status(500).json({ error: 'Failed to clear call logs' });
    }
};
