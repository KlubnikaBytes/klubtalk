try {
    const mediaController = require('./src/controllers/mediaController');
    console.log('mediaController loaded successfully');
} catch (e) {
    console.error('Stack:', e.stack);
    console.error('Message:', e.message);
}
