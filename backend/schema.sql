CREATE TABLE users (
 id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(120) NOT NULL, email VARCHAR(254) NOT NULL UNIQUE,
 password_hash VARCHAR(100) NOT NULL, role ENUM('STUDENT','LECTURER','HEAD','STAFF') NOT NULL,
 department VARCHAR(60) NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE auth_sessions (
 id INT PRIMARY KEY AUTO_INCREMENT, user_id INT NOT NULL, token_hash CHAR(64) NOT NULL UNIQUE,
 expires_at DATETIME(3) NOT NULL, FOREIGN KEY (user_id) REFERENCES users(id), INDEX(expires_at)
) ENGINE=InnoDB;
CREATE TABLE rooms (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(60) NOT NULL UNIQUE, capacity INT NOT NULL CHECK(capacity > 0)) ENGINE=InnoDB;
CREATE TABLE sections (
 id INT PRIMARY KEY AUTO_INCREMENT, code VARCHAR(80) NOT NULL UNIQUE, course VARCHAR(120) NOT NULL,
 department VARCHAR(60) NOT NULL, lecturer_id INT NOT NULL, FOREIGN KEY(lecturer_id) REFERENCES users(id), INDEX(department)
) ENGINE=InnoDB;
CREATE TABLE enrollments (
 section_id INT NOT NULL, student_id INT NOT NULL, PRIMARY KEY(section_id,student_id),
 FOREIGN KEY(section_id) REFERENCES sections(id), FOREIGN KEY(student_id) REFERENCES users(id), INDEX(student_id)
) ENGINE=InnoDB;
CREATE TABLE class_sessions (
 id INT PRIMARY KEY AUTO_INCREMENT, section_id INT NOT NULL, room_id INT NOT NULL,
 start_at DATETIME(3) NOT NULL, end_at DATETIME(3) NOT NULL, version INT NOT NULL DEFAULT 0,
 attendance_saved BOOLEAN NOT NULL DEFAULT FALSE, CHECK(end_at > start_at),
 FOREIGN KEY(section_id) REFERENCES sections(id), FOREIGN KEY(room_id) REFERENCES rooms(id),
 INDEX(start_at,end_at), INDEX(room_id,start_at), INDEX(section_id,start_at)
) ENGINE=InnoDB;
CREATE TABLE attendance (
 session_id INT NOT NULL, student_id INT NOT NULL, status ENUM('PRESENT','ABSENT','LATE','EXCUSED') NOT NULL,
 updated_by INT NOT NULL, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY(session_id,student_id), FOREIGN KEY(session_id) REFERENCES class_sessions(id),
 FOREIGN KEY(student_id) REFERENCES users(id), FOREIGN KEY(updated_by) REFERENCES users(id)
) ENGINE=InnoDB;
CREATE TABLE leave_requests (
 id INT PRIMARY KEY AUTO_INCREMENT, session_id INT NOT NULL, requester_id INT NOT NULL, reason VARCHAR(1000) NOT NULL,
 status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING', version INT NOT NULL DEFAULT 0,
 reviewer_id INT NULL, review_note VARCHAR(1000), reviewed_at DATETIME(3), created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(session_id,requester_id), FOREIGN KEY(session_id) REFERENCES class_sessions(id),
 FOREIGN KEY(requester_id) REFERENCES users(id), FOREIGN KEY(reviewer_id) REFERENCES users(id), INDEX(status)
) ENGINE=InnoDB;
CREATE TABLE change_requests (
 id INT PRIMARY KEY AUTO_INCREMENT, session_id INT NOT NULL, requester_id INT NOT NULL, reason VARCHAR(1000) NOT NULL,
 proposed_room_id INT NOT NULL, proposed_start DATETIME(3) NOT NULL, proposed_end DATETIME(3) NOT NULL,
 session_version INT NOT NULL, status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING', version INT NOT NULL DEFAULT 0,
 reviewer_id INT NULL, review_note VARCHAR(1000), reviewed_at DATETIME(3), created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 pending_session INT GENERATED ALWAYS AS (CASE WHEN status='PENDING' THEN session_id ELSE NULL END) STORED UNIQUE,
 CHECK(proposed_end > proposed_start), FOREIGN KEY(session_id) REFERENCES class_sessions(id),
 FOREIGN KEY(proposed_room_id) REFERENCES rooms(id), FOREIGN KEY(requester_id) REFERENCES users(id),
 FOREIGN KEY(reviewer_id) REFERENCES users(id), INDEX(status)
) ENGINE=InnoDB;
CREATE TABLE academic_lock (id INT PRIMARY KEY, version INT NOT NULL DEFAULT 0) ENGINE=InnoDB;
INSERT INTO academic_lock(id) VALUES(1);
CREATE TABLE audit_logs (
 id INT PRIMARY KEY AUTO_INCREMENT, actor_id INT NOT NULL, action VARCHAR(60) NOT NULL,
 entity VARCHAR(60) NOT NULL, entity_id INT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(actor_id) REFERENCES users(id), INDEX(entity,entity_id)
) ENGINE=InnoDB;
