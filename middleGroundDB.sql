-- Step 1: Create the database
DROP DATABASE IF EXISTS MiddleGroundDB; -- Ensure the database does not already exist
CREATE DATABASE MiddleGroundDB; -- Create the database
USE MiddleGroundDB; 

-- Step 2: Create the Users table
CREATE TABLE Users (
    username VARCHAR(50) PRIMARY KEY, -- Unique string identifier for each user
    firstName VARCHAR(50) NOT NULL, -- User's first name
    lastName VARCHAR(50) NOT NULL, -- User's last name
    email VARCHAR(100) UNIQUE NOT NULL, -- User's email address, must be unique
    passHash VARCHAR(255) NOT NULL, -- Hashed password for security
    polLean ENUM('FL', 'L', 'SL', 'M', 'SR', 'R', 'FR') NOT NULL, -- Political leaning of the user
    accVerify BOOLEAN DEFAULT FALSE, -- Account verification status
    dateCreate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Step 3: Create the PostsData table
CREATE TABLE PostsData (
    postID INT AUTO_INCREMENT PRIMARY KEY, -- default Unique identifier for each post
    username VARCHAR(50) NOT NULL, -- Username of the user who created the post
    title VARCHAR(255) NOT NULL, -- Title of the post
    body TEXT NOT NULL, -- Content of the post
    sources TEXT NULL, -- Optional sources for the post
    datePosted TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
    FOREIGN KEY (username) REFERENCES Users(username) ON DELETE CASCADE -- links the posts username to the Users table
);

-- Step 4: Create the Comments table with Nested Comments Support
CREATE TABLE Comments (
    commentID INT AUTO_INCREMENT PRIMARY KEY, -- default Unique identifier for each comment
    entityType ENUM('POST', 'COMMENT') NOT NULL, -- Type of entity being commented on (post or comment)
    entityID INT NOT NULL, -- ID of the post or comment being commented on
    username VARCHAR(50) NOT NULL, -- Username of the user who created the comment
    body TEXT NOT NULL, -- Content of the comment
    datePosted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (username) REFERENCES Users(username) ON DELETE CASCADE, -- links the comments username to the Users table
    CHECK (entityType = 'POST' AND entityID IN (SELECT postID FROM PostsData) OR entityType = 'COMMENT' AND entityID IN (SELECT commentID FROM Comments)), -- Ensure entityID exists in the corresponding table
);

-- Step 5: Create the Likes table
CREATE TABLE Likes (
    likeID INT AUTO_INCREMENT PRIMARY KEY, -- default Unique identifier for each like
    username VARCHAR(50) NOT NULL, -- Username of the user who liked the post or comment
    entityType ENUM('POST', 'COMMENT') NOT NULL, -- Type of entity being liked (post or comment)
    entityID INT NOT NULL, -- ID of the post or comment being liked *CANNOT GO BASED ON THIS, MUST USE BOTH ENTITY TYPE AND ENTITY ID*
    polLean ENUM('FL', 'L', 'SL', 'M', 'SR', 'R', 'FR') NOT NULL, -- Political leaning of the user who liked the post or comment
    dateLiked TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Timestamp of when the like was made
    UNIQUE KEY unique_like (username, entityType, entityID), -- Prevent duplicate likes
    FOREIGN KEY (username) REFERENCES Users(username) ON DELETE CASCADE
);

-- Step 6: Add Indexes for Performance
CREATE INDEX idx_datePosted ON PostsData(datePosted); -- Index for faster retrieval of posts by date
CREATE INDEX idx_datePosted_comments ON Comments(datePosted); -- Index for faster retrieval of comments by date
CREATE INDEX idx_likes_entity ON Likes(entityType, entityID); -- Index for faster retrieval of likes by entity type and ID
CREATE INDEX idx_likes_user ON Likes(username); -- Index for faster retrieval of likes by user


-- PROCEDURES:

-- PROCEDURE: Insert a new user
-- Example: CALL insertUser('johndoe', 'John', 'Doe', 'johndoe@example.com', 'hashedpassword123', 'M');
DELIMITER $$

CREATE PROCEDURE insertUser(
    IN p_username VARCHAR(50),
    IN p_firstName VARCHAR(50),
    IN p_lastName VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_passHash VARCHAR(255),
    IN p_polLean ENUM('FL', 'L', 'SL', 'M', 'SR', 'R', 'FR')
)
BEGIN
    -- Check if the username already exists
    IF EXISTS (SELECT 1 FROM Users WHERE username = p_username) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username in Use';
    -- Check if the email already exists
    ELSEIF EXISTS (SELECT 1 FROM Users WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email in Use';
    ELSE    -- Insert new user
        INSERT INTO Users (username, firstName, lastName, email, passHash, polLean, accVerify)
        VALUES (p_username, p_firstName, p_lastName, p_email, p_passHash, p_polLean, FALSE);
        
        -- Return success message
        SELECT 'User Created' AS message;
    END IF;
END $$

DELIMITER ;


-- PROCEDURE: Insert a new post
-- Example: CALL insertPost('johndoe', 'Abortion', 'Law: if we make a law in which abortion is...', 'https://ai-news.com');
DELIMITER $$

CREATE PROCEDURE insertPost(
    IN p_username VARCHAR(50),
    IN p_title VARCHAR(255),
    IN p_body TEXT,
    IN p_sources TEXT NULL
)
BEGIN
    -- Insert new post
    INSERT INTO PostsData (username, title, body, sources)
    VALUES (p_username, p_title, p_body, p_sources);

    -- Return success message
    SELECT 'Post Created' AS message;
END $$

DELIMITER ;


-- PROCEDURE: Insert a new comment
-- Example: CALL insertComment('POST', 5, 'johndoe', 'This is a comment on post 5');
-- Example: CALL insertComment('COMMENT', 3, 'janedoe', 'This is a reply to comment 3');
DELIMITER $$

CREATE PROCEDURE insertComment(
    IN p_entityType ENUM('POST', 'COMMENT'), -- Type of entity being commented on
    IN p_entityID INT,                      -- ID of the post or comment being commented on
    IN p_username VARCHAR(50),              -- Username of the user creating the comment
    IN p_body TEXT
)
BEGIN
    -- Validate that the entity exists before inserting the comment
    IF p_entityType = 'POST' AND NOT EXISTS (SELECT 1 FROM PostsData WHERE postID = p_entityID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Post ID';
    ELSEIF p_entityType = 'COMMENT' AND NOT EXISTS (SELECT 1 FROM Comments WHERE commentID = p_entityID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Comment ID';
    ELSE
        -- Insert the new comment
        INSERT INTO Comments (entityType, entityID, username, body)
        VALUES (p_entityType, p_entityID, p_username, p_body);

        -- Return success message
        SELECT 'Comment Created' AS message;
    END IF;
END $$

DELIMITER ;


-- PROCEDURE: Insert a like
-- Example: CALL insertLike('johndoe', 'POST', 5, 'M'); -- JohnDoe likes post with ID 5
DELIMITER $$

CREATE PROCEDURE insertLike(
    IN p_username VARCHAR(50),
    IN p_entityType ENUM('POST', 'COMMENT'),
    IN p_entityID INT,
    IN p_polLean ENUM('FL', 'L', 'SL', 'M', 'SR', 'R', 'FR')
)
BEGIN
    -- Check if the like already exists
    IF EXISTS (
        SELECT 1 FROM Likes 
        WHERE username = p_username 
        AND entityType = p_entityType 
        AND entityID = p_entityID
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Like Already Exists';
    ELSE
        -- Insert new like
        INSERT INTO Likes (username, entityType, entityID, polLean)
        VALUES (p_username, p_entityType, p_entityID, p_polLean);

        -- Return success message
        SELECT 'Like Added' AS message;
    END IF;
END $$

DELIMITER ;


-- PROCEDURE: Get likes for a post or comment
-- Example: CALL getLikes('POST', 5); -- Get all likes for post with ID 5
DELIMITER $$

CREATE PROCEDURE getLikes(
    IN p_entityType ENUM('POST', 'COMMENT'), -- Type of entity ('POST' or 'COMMENT')
    IN p_entityID INT                        -- ID of the post or comment
)
BEGIN
    -- Validate that the entity exists before fetching likes
    IF p_entityType = 'POST' AND NOT EXISTS (SELECT 1 FROM PostsData WHERE postID = p_entityID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Post ID';
    ELSEIF p_entityType = 'COMMENT' AND NOT EXISTS (SELECT 1 FROM Comments WHERE commentID = p_entityID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Comment ID';
    ELSE
        -- Retrieve the count of likes for each political leaning
        SELECT 
            SUM(CASE WHEN polLean = 'FR' THEN 1 ELSE 0 END) AS FR,
            SUM(CASE WHEN polLean = 'R' THEN 1 ELSE 0 END) AS R,
            SUM(CASE WHEN polLean = 'SR' THEN 1 ELSE 0 END) AS SR,
            SUM(CASE WHEN polLean = 'M' THEN 1 ELSE 0 END) AS M,
            SUM(CASE WHEN polLean = 'SL' THEN 1 ELSE 0 END) AS SL,
            SUM(CASE WHEN polLean = 'L' THEN 1 ELSE 0 END) AS L,
            SUM(CASE WHEN polLean = 'FL' THEN 1 ELSE 0 END) AS FL
        FROM Likes
        WHERE entityType = p_entityType AND entityID = p_entityID;
    END IF;
END $$

DELIMITER ;


-- PROCEDURE: get all data from a post
-- Example: CALL getPostData(5); -- Get all data for post with ID 5 
DELIMITER $$

CREATE PROCEDURE getPostData(
    IN p_postID INT -- ID of the post to retrieve
)
BEGIN
    -- Validate that the post exists
    IF NOT EXISTS (SELECT 1 FROM PostsData WHERE postID = p_postID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Post ID';
    ELSE
        -- Retrieve post details
        SELECT 
            postID,
            title,
            body,
            sources,
            username AS poster,
            datePosted
        FROM PostsData
        WHERE postID = p_postID;
    END IF;
END $$

DELIMITER ;


-- PROCEDURE: get all comments for a post
-- Example: CALL getComments(5); -- Get all comments for post with ID 5
DELIMITER $$

CREATE PROCEDURE getComments(
    IN p_postID INT -- ID of the post to retrieve comments for
)
BEGIN
    -- Validate that the post exists
    IF NOT EXISTS (SELECT 1 FROM PostsData WHERE postID = p_postID) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid Post ID';
    ELSE
        -- Retrieve comments associated with the given post
        SELECT 
            commentID,
            entityType,
            entityID,
            username AS commenter,
            body AS comment,
            datePosted
        FROM Comments
        WHERE entityType = 'POST' AND entityID = p_postID
        ORDER BY datePosted ASC; -- Ensures comments are displayed in order
    END IF;
END $$

DELIMITER ;


-- Insert Users for testing
INSERT INTO Users (username, firstName, lastName, email, passHash, polLean, accVerify)
VALUES
    ('johndoe', 'John', 'Doe', 'johndoe@example.com', 'hashedpass123', 'M', TRUE),
    ('janedoe', 'Jane', 'Doe', 'janedoe@example.com', 'hashedpass456', 'L', TRUE),
    ('mark123', 'Mark', 'Smith', 'mark123@example.com', 'hashedpass789', 'R', TRUE),
    ('sarahX', 'Sarah', 'Xavier', 'sarahx@example.com', 'hashedpass111', 'FL', TRUE),
    ('tomGOP', 'Tom', 'Greene', 'tomgop@example.com', 'hashedpass222', 'FR', TRUE);

-- Insert Posts
INSERT INTO PostsData (username, title, body, sources)
VALUES
    ('johndoe', 'The Green Energy Investment Act', 
    'A proposed bill aims to allocate $100 billion towards renewable energy infrastructure over the next decade. This will reduce fossil fuel reliance and create jobs in the green energy sector.', 
    'https://energynews.com'),
    
    ('mark123', 'National Voter ID Requirement', 
    'A new law proposal would require a government-issued photo ID to vote in federal elections. Supporters argue this prevents fraud, while critics believe it could suppress votes.', 
    'https://govtrack.org');

-- Retrieve post IDs (assuming AUTO_INCREMENT)
SET @post1 = (SELECT postID FROM PostsData WHERE title = 'The Green Energy Investment Act');
SET @post2 = (SELECT postID FROM PostsData WHERE title = 'National Voter ID Requirement');

-- Insert Comments for Post 1
INSERT INTO Comments (entityType, entityID, username, body)
VALUES
    ('POST', @post1, 'janedoe', 'Finally, some real investment in our future! Fossil fuels are outdated.'),
    ('POST', @post1, 'tomGOP', 'Whos paying for this? Our taxes? This is unrealistic spending.'),
    ('POST', @post1, 'sarahX', 'This should have happened years ago. Lets go even further with clean energy!');

-- Insert Comments for Post 2
INSERT INTO Comments (entityType, entityID, username, body)
VALUES
    ('POST', @post2, 'johndoe', 'This could make voting harder for low-income citizens. Whats the alternative?'),
    ('POST', @post2, 'tomGOP', 'Election integrity is key! IDs are needed for everything else, why not voting?'),
    ('POST', @post2, 'sarahX', 'This disproportionately affects minorities and the elderly. Bad idea.');