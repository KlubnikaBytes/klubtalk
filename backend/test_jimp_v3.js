const { Jimp } = require('jimp');
console.log('Jimp.read type:', typeof Jimp.read);
if (typeof Jimp.read === 'function') {
    console.log('Jimp.read exists');
} else {
    console.log('Jimp.read MISSING');
}
