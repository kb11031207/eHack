const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const dotenv = require('dotenv');

dotenv.config();

exports.register = async (req, res) => {
    const { username, firstName, lastName, email, password, polLean } = req.body;
    
    // Validate input
    if (!username || !firstName || !lastName || !email || !password || !polLean) {
      return res.status(400).json({ 
        success: false, 
        message: 'Please provide all required fields: username, firstName, lastName, email, password, and political leaning' 
      });
    }

    // Validate political leaning
    const validPolLeans = ['FL', 'L', 'SL', 'M', 'SR', 'R', 'FR'];
    if (!validPolLeans.includes(polLean)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid political leaning. Must be one of: FL, L, SL, M, SR, R, FR'
        });
    }

    try {
        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Call the stored procedure to insert user
        const [result] = await db.query(
            'CALL insertUser(?, ?, ?, ?, ?, ?)',
            [username, firstName, lastName, email, hashedPassword, polLean]
        );

        // Check if user was created successfully
        if (result[0][0].message === 'User Created') {
            // Generate JWT token
            const token = jwt.sign(
                { username: username },
                process.env.JWT_SECRET,
                { expiresIn: '1h' }
            );

            // Return success response
            return res.status(201).json({
                success: true,
                message: 'Registration successful',
                token,
                user: {
                    username,
                    firstName,
                    lastName,
                    email,
                    polLean
                }
            });
        } else {
            // This shouldn't happen with the stored procedure, but just in case
            return res.status(500).json({
                success: false,
                message: 'Registration failed'
            });
        }
    } catch (error) {
        console.error('Registration error:', error);
        
        // Handle specific error messages from the stored procedure
        if (error.message.includes('Username in Use')) {
            return res.status(409).json({
                success: false,
                message: 'Username already in use'
            });
        } else if (error.message.includes('Email in Use')) {
            return res.status(409).json({
                success: false,
                message: 'Email already in use'
            });
        }
        
        res.status(500).json({
            success: false,
            message: 'Registration failed'
        });
    }
};

exports.login = async (req, res) => {
    const { username, password } = req.body;
    console.log(username + " " + password);
    // Validate input
    if (!username || !password) {
        return res.status(400).json({
            success: false,
            message: 'Please provide username and password'
        });
    }

    try {
        // Check if user exists
        const [users] = await db.query(
            'SELECT * FROM Users WHERE username = ?',
            [username]
        );

        if (users.length === 0) {
            return res.status(401).json({
                success: false,  
                message: 'Invalid credentials'  
            });
        }

        const user = users[0];

        // Check password
        const validPassword = await bcrypt.compare(password, user.passHash);

        if (!validPassword) {       
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        // Generate JWT token
        const token = jwt.sign(
            { email: user.email,
                username: user.username
             },
            process.env.JWT_SECRET,
            { expiresIn: '1h' }
        );

        // Return success response
        res.json({
            success: true,
            message: 'Login successful',
            token,
            user: {
                username: user.username,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                polLean: user.polLean,
                accVerify: user.accVerify
            }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Login failed'
        });
    }
};

// Get current user profile
exports.getProfile = async (req, res) => {
    try {
        const [users] = await db.query(
            'SELECT username, firstName, lastName, email, polLean, accVerify, dateCreate FROM Users WHERE username = ?',
            [req.user.username]
        );

        if (users.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        res.json({
            success: true,
            user: users[0]
        });
    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to retrieve profile'
        });
    }
};

module.exports = exports;