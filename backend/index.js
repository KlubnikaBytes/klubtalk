const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const apiRoutes = require('./src/routes/api');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve Static Files (For serving uploaded media from the VPS disk)
// Access via: http://your-domain/uploads/filename.m4a
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/', apiRoutes);

// Start
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Media serving at ${process.env.VPS_PUBLIC_URL || 'http://localhost:' + PORT}/uploads/`);
});
