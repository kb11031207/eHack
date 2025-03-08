const mysql = require('mysql2/promise');
const dotenv = require('dotenv');

dotenv.config();

const pool = mysql.createPool({
   host: process.env.host || 'localhost',
   user: process.env.user || 'roo',
   password: process.env.password || '',
   database: process.env.database || 'MiddleGroundDB',
   waitForConnections: true,
   connectionLimit: 10,
   queueLimit: 0
 });

function handleDisconnect(pool) {
    pool.on('error', (err) => {
        if (err.code === 'PROTOCOL_CONNECTION_LOST') {
            console.error('Database connection lost. Attempting to reconnect...');
            setTimeout(() => {
                handleDisconnect(pool);
            }, 2000);
        } else {
            throw err;
        }
    });
}

handleDisconnect(pool);

module.exports = pool;