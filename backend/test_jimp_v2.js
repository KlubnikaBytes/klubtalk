const { Jimp } = require('jimp');
console.log('Jimp class:', Jimp);
try {
    const j = new Jimp(100, 100);
    console.log('Jimp instance created');
} catch (e) {
    console.error('Jimp instance error:', e);
}
