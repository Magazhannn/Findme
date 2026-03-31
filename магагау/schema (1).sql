-- ============================================================
-- FindMe AI — MySQL 8.0+ Database Schema
-- Architecture: FastAPI backend + FAISS in-memory + MySQL storage
-- ============================================================

CREATE DATABASE IF NOT EXISTS findme_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE findme_db;

-- ──────────────────────────────────────────────
-- USERS
-- ──────────────────────────────────────────────
CREATE TABLE users (
    id           VARCHAR(36)  PRIMARY KEY DEFAULT (UUID()),
    email        VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name    VARCHAR(255),
    role         ENUM('user', 'admin') DEFAULT 'user',
    is_active    BOOLEAN DEFAULT TRUE,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- PERSONS
-- Core entity: the missing/tracked person
-- ──────────────────────────────────────────────
CREATE TABLE persons (
    id              VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    internal_status ENUM('missing', 'found', 'tracking') DEFAULT 'missing',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- SEARCHES
-- Tracks every search request submitted by users
-- ──────────────────────────────────────────────
CREATE TABLE searches (
    id                 VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id            VARCHAR(36) NOT NULL,
    input_image_url    VARCHAR(500),
    search_parameters  JSON,
    status             ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending',
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at       TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_status (status),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- FACE EMBEDDINGS
-- Stores float32 face vectors as BLOB for FAISS reload
-- ──────────────────────────────────────────────
CREATE TABLE face_embeddings (
    id               VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    person_id        VARCHAR(36) NULL,
    embedding        BLOB NOT NULL,         -- float32 array (128 or 512 dims)
    source_image_url VARCHAR(500),
    source_type      ENUM('uploaded', 'scraped_vk', 'scraped_ig', 'scraped_linkedin', 'cctv') DEFAULT 'uploaded',
    metadata         JSON,                  -- confidence, model_name, etc.
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- CHARACTERISTICS
-- Structured person attributes — used for fast filtered search
-- ──────────────────────────────────────────────
CREATE TABLE characteristics (
    id           VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    person_id    VARCHAR(36) NOT NULL,
    gender       ENUM('male', 'female', 'unknown') DEFAULT 'unknown',
    hair_color   ENUM('blond', 'black', 'brown', 'white', 'pink', 'yellow', 'other'),
    hair_type    ENUM('straight', 'curly', 'wavy', 'bald'),
    hair_length  ENUM('very_long', 'long', 'medium', 'short', 'very_short'),
    height       ENUM('very_tall', 'tall', 'above_avg', 'average', 'below_avg', 'short', 'very_short'),
    body_type    ENUM('large', 'medium', 'slim'),
    skin_color   ENUM('white', 'yellow', 'pale', 'tan', 'dark'),
    facial_hair  ENUM('beard', 'mustache', 'both', 'none'),
    tattoo       BOOLEAN DEFAULT FALSE,
    age_range    ENUM('child', 'teen', 'adult', 'elderly'),
    FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
    INDEX idx_gender_age (gender, age_range),
    INDEX idx_physical (height, body_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- CLOTHING & ACCESSORIES
-- Stored as JSON for flexible CLIP-based search
-- ──────────────────────────────────────────────
CREATE TABLE clothing_and_accessories (
    id           VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    person_id    VARCHAR(36) NOT NULL,
    hat          JSON,  -- {"type": "cap"}
    upper_clothes JSON, -- {"type": "hoodie", "color": "red"}
    lower_clothes JSON, -- {"type": "joggers", "color": "black"}
    shoes        JSON,  -- {"type": "sneakers", "color": "white"}
    accessories  JSON,  -- {"glasses": {"color": "black"}, "bag": "backpack", "watch": "Casio"}
    FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- CAMERA STREAMS
-- RTSP/WebRTC camera registry
-- ──────────────────────────────────────────────
CREATE TABLE camera_streams (
    id        VARCHAR(36)  PRIMARY KEY DEFAULT (UUID()),
    name      VARCHAR(255) NOT NULL,
    rtsp_url  VARCHAR(500) NOT NULL,
    lat       DECIMAL(10, 8),
    lng       DECIMAL(11, 8),
    location  VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- DETECTIONS
-- Every time a face is spotted on a camera
-- ──────────────────────────────────────────────
CREATE TABLE detections (
    id           VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    embedding_id VARCHAR(36) NOT NULL,
    camera_id    VARCHAR(36) NOT NULL,
    confidence   FLOAT       NOT NULL,
    emotion      ENUM('neutral', 'fear', 'aggression', 'panic', 'running') DEFAULT 'neutral',
    lat          DECIMAL(10, 8),
    lng          DECIMAL(11, 8),
    timestamp    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (embedding_id) REFERENCES face_embeddings(id) ON DELETE CASCADE,
    FOREIGN KEY (camera_id)    REFERENCES camera_streams(id)  ON DELETE CASCADE,
    INDEX idx_timestamp (timestamp),
    INDEX idx_embedding_id (embedding_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- SEARCH RESULTS
-- Links a search request to matched face embeddings
-- ──────────────────────────────────────────────
CREATE TABLE search_results (
    id                  VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    search_id           VARCHAR(36) NOT NULL,
    face_embedding_id   VARCHAR(36) NOT NULL,
    similarity_score    FLOAT       NOT NULL,
    is_verified_by_user BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (search_id)         REFERENCES searches(id)        ON DELETE CASCADE,
    FOREIGN KEY (face_embedding_id) REFERENCES face_embeddings(id) ON DELETE CASCADE,
    INDEX idx_search_id (search_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- EXTERNAL PROFILES (OSINT)
-- Social media profiles linked to detected faces
-- ──────────────────────────────────────────────
CREATE TABLE external_profiles (
    id            VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    person_id     VARCHAR(36) NULL,
    platform      VARCHAR(50) NOT NULL,   -- VK, Instagram, LinkedIn
    external_id   VARCHAR(255),
    profile_url   VARCHAR(500),
    username      VARCHAR(255),
    display_name  VARCHAR(255),
    profile_pic_url VARCHAR(500),
    bio           TEXT,
    scraped_data  JSON,
    last_scraped_at TIMESTAMP NULL,
    FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE SET NULL,
    INDEX idx_platform (platform),
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- ALERTS
-- Real-time notifications sent to users
-- ──────────────────────────────────────────────
CREATE TABLE alerts (
    id           VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    search_id    VARCHAR(36) NOT NULL,
    detection_id VARCHAR(36) NOT NULL,
    sent_to_user BOOLEAN DEFAULT FALSE,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (search_id)    REFERENCES searches(id)   ON DELETE CASCADE,
    FOREIGN KEY (detection_id) REFERENCES detections(id) ON DELETE CASCADE,
    INDEX idx_search_id (search_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ──────────────────────────────────────────────
-- HEATMAP POINTS
-- Aggregated sighting data for map visualization
-- ──────────────────────────────────────────────
CREATE TABLE heatmap_points (
    id           VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    person_id    VARCHAR(36) NOT NULL,
    lat          DECIMAL(10, 8) NOT NULL,
    lng          DECIMAL(11, 8) NOT NULL,
    weight       FLOAT DEFAULT 1.0,  -- intensity of sighting
    timestamp    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE,
    INDEX idx_person_time (person_id, timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
