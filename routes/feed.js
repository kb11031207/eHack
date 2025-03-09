const express = require('express');
const router = express.Router();
const feedController = require('../controllers/feedController');
const auth = require('../middleware/middleware');

// Create a new post (requires auth)
router.post('/posts', auth, feedController.createPost);

// Get all posts with pagination and sorting (public)
router.get('/posts', feedController.getPosts);

// Get comments for a post (public)
router.get('/posts/comments', feedController.getComments);

// Get a single post by ID (public)
router.get('/posts/:id', feedController.getPostById);

// Add a comment to a post (requires auth)
router.post('/comments', auth, feedController.addComment);

// Add a like to a post or comment (requires auth)
router.post('/likes', auth, feedController.addLike);

// Remove a like (requires auth)
router.delete('/likes', auth, feedController.removeLike);

module.exports = router;
