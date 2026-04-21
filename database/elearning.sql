-- ============================================================
-- DATABASE: ELearningDB
-- MÔ TẢ: Hệ thống quản lý học tập (LMS)
-- PHIÊN BẢN: 2.0 (có điểm số động, test_question, hỗ trợ tự luận)
-- ============================================================

DROP DATABASE IF EXISTS ELearningDB;
CREATE DATABASE ELearningDB;
USE ELearningDB;

-- ------------------------------------------------------------
-- 1. DANH MỤC CƠ SỞ
-- ------------------------------------------------------------
CREATE TABLE Role (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Status (
    status_id INT AUTO_INCREMENT PRIMARY KEY,
    status_display VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Semester (
    semester_id INT AUTO_INCREMENT PRIMARY KEY,
    semester_start DATE NOT NULL,
    semester_end DATE NOT NULL,
    CONSTRAINT chk_semester_dates CHECK (semester_start < semester_end)
);

CREATE TABLE Faculty (
    faculty_id INT AUTO_INCREMENT PRIMARY KEY,
    faculty_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Subject (
    subject_id INT AUTO_INCREMENT PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    faculty_id INT NOT NULL,
    FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
);

-- ------------------------------------------------------------
-- 2. NGƯỜI DÙNG & PHÂN QUYỀN
-- ------------------------------------------------------------
CREATE TABLE User (
    id INT AUTO_INCREMENT PRIMARY KEY,
    firstName VARCHAR(50) NOT NULL,
    middleName VARCHAR(50),
    lastName VARCHAR(50) NOT NULL,
    sex ENUM('Male', 'Female', 'Other') NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    birthday DATE,
    nationality VARCHAR(50)
);

CREATE TABLE Student (
    id INT PRIMARY KEY,
    s_mssv VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE Lecturer (
    id INT PRIMARY KEY,
    l_msgv VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE Admin (
    id INT PRIMARY KEY,
    a_msqt VARCHAR(20) UNIQUE NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE User_acc (
    ua_id INT PRIMARY KEY,
    ua_username VARCHAR(50) UNIQUE NOT NULL,
    ua_password VARCHAR(255) NOT NULL,
    ua_image VARCHAR(255),
    role_id INT NOT NULL,
    FOREIGN KEY (ua_id) REFERENCES User(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES Role(role_id)
);

-- ------------------------------------------------------------
-- 3. LỚP HỌC
-- ------------------------------------------------------------
CREATE TABLE Class (
    class_id INT AUTO_INCREMENT PRIMARY KEY,
    class_name VARCHAR(100) NOT NULL,
    subject_id INT NOT NULL,
    semester_id INT NOT NULL,
    status_id INT NOT NULL,
    lecturer_id INT,
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id),
    FOREIGN KEY (semester_id) REFERENCES Semester(semester_id),
    FOREIGN KEY (status_id) REFERENCES Status(status_id),
    FOREIGN KEY (lecturer_id) REFERENCES Lecturer(id)
);

CREATE TABLE Enrollment (
    student_id INT,
    class_id INT,
    PRIMARY KEY (student_id, class_id),
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE,
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 4. NỘI DUNG HỌC TẬP
-- ------------------------------------------------------------
CREATE TABLE Chapter (
    class_id INT,
    chapter_id INT,
    chapter_name VARCHAR(255) NOT NULL,
    PRIMARY KEY (class_id, chapter_id),
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

CREATE TABLE Topic (
    class_id INT,
    chapter_id INT,
    topic_id INT,
    topic_name VARCHAR(255) NOT NULL,
    topic_content TEXT,
    PRIMARY KEY (class_id, chapter_id, topic_id),
    FOREIGN KEY (class_id, chapter_id) REFERENCES Chapter(class_id, chapter_id) ON DELETE CASCADE
);

CREATE TABLE File (
    class_id INT,
    chapter_id INT,
    topic_id INT,
    file_id INT,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(512) NOT NULL,
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (class_id, chapter_id, topic_id, file_id),
    FOREIGN KEY (class_id, chapter_id, topic_id) REFERENCES Topic(class_id, chapter_id, topic_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 5. BÀI KIỂM TRA
-- ------------------------------------------------------------
CREATE TABLE Test (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(255) NOT NULL,
    test_start DATETIME,
    test_end DATETIME,
    test_timer INT COMMENT 'Thời gian làm bài (phút)',
    class_id INT NOT NULL,
    chapter_id INT,
    FOREIGN KEY (class_id) REFERENCES Class(class_id),
    FOREIGN KEY (class_id, chapter_id) REFERENCES Chapter(class_id, chapter_id),
    CONSTRAINT chk_test_dates CHECK (test_start < test_end)
);

CREATE TABLE Quiz (
    test_id INT PRIMARY KEY,
    quizz_id VARCHAR(50) UNIQUE NOT NULL,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

CREATE TABLE File_submission (
    test_id INT PRIMARY KEY,
    fs_id VARCHAR(50) UNIQUE NOT NULL,
    path VARCHAR(512),
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 6. NGÂN HÀNG CÂU HỎI (có max_score mặc định)
-- ------------------------------------------------------------
CREATE TABLE Question (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    question_type ENUM('multiple_choice', 'true_false', 'essay') NOT NULL,
    question_content TEXT NOT NULL,
    max_score DECIMAL(5,2) DEFAULT 1.0 NOT NULL COMMENT 'Điểm tối đa mặc định của câu hỏi',
    test_id INT NOT NULL,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

-- Bảng trung gian: gán điểm cụ thể cho câu hỏi trong từng bài test
CREATE TABLE Test_Question (
    test_id INT NOT NULL,
    question_id INT NOT NULL,
    custom_score DECIMAL(5,2) DEFAULT NULL COMMENT 'Điểm tùy chỉnh cho câu hỏi trong bài test này. NULL nghĩa là dùng max_score của Question',
    PRIMARY KEY (test_id, question_id),
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE
);

CREATE TABLE Choice (
    choice_id INT AUTO_INCREMENT PRIMARY KEY,
    choice_content TEXT NOT NULL,
    is_true BOOLEAN DEFAULT FALSE,
    question_id INT NOT NULL,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 7. LẦN LÀM BÀI (ATTEMPT) - SCORE LÀ DẪN XUẤT
-- ------------------------------------------------------------
CREATE TABLE Attempt (
    attempt_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_index INT NOT NULL,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    timer INT COMMENT 'Thời gian đã sử dụng (giây)',
    test_id INT NOT NULL,
    student_id INT NOT NULL,
    -- Cột điểm được tính tự động dựa trên câu trả lời đúng và điểm của từng câu
    score DECIMAL(7,2) GENERATED ALWAYS AS (
        (SELECT COALESCE(SUM(
            CASE
                WHEN q.question_type IN ('multiple_choice', 'true_false') THEN
                    COALESCE(tq.custom_score, q.max_score)
                ELSE
                    COALESCE(sa.score_awarded, 0)
            END
        ), 0)
        FROM Student_answer sa
        JOIN Question q ON sa.question_id = q.question_id
        LEFT JOIN Test_Question tq ON tq.test_id = sa.attempt_id AND tq.question_id = sa.question_id
        LEFT JOIN Choice c ON sa.choice_id = c.choice_id
        WHERE sa.attempt_id = attempt_id
          AND (
              (q.question_type IN ('multiple_choice', 'true_false') AND c.is_true = 1)
              OR
              (q.question_type = 'essay' AND sa.score_awarded IS NOT NULL)
          )
        )
    ) STORED COMMENT 'Điểm tổng được tính tự động từ câu trả lời đúng và điểm câu hỏi',
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE
);

-- Bảng lưu câu trả lời của sinh viên
CREATE TABLE Student_answer (
    ans_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_id INT NOT NULL,
    question_id INT NOT NULL,
    choice_id INT NULL,
    answer_text TEXT NULL,
    score_awarded DECIMAL(5,2) DEFAULT NULL COMMENT 'Điểm giáo viên chấm cho câu tự luận',
    FOREIGN KEY (attempt_id) REFERENCES Attempt(attempt_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE,
    FOREIGN KEY (choice_id) REFERENCES Choice(choice_id) ON DELETE CASCADE,
    CONSTRAINT chk_answer CHECK (
        (choice_id IS NOT NULL AND answer_text IS NULL) OR
        (choice_id IS NULL AND answer_text IS NOT NULL)
    )
);

-- ------------------------------------------------------------
-- 8. TƯƠNG TÁC LỚP HỌC
-- ------------------------------------------------------------
CREATE TABLE Post (
    post_id INT AUTO_INCREMENT PRIMARY KEY,
    post_name VARCHAR(255) NOT NULL,
    post_description TEXT,
    post_start DATETIME,
    post_end DATETIME,
    ua_id INT NOT NULL,
    class_id INT NOT NULL,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id),
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

CREATE TABLE Comment (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    comment_content TEXT NOT NULL,
    comment_start DATETIME DEFAULT CURRENT_TIMESTAMP,
    post_id INT NOT NULL,
    ua_id INT NOT NULL,
    FOREIGN KEY (post_id) REFERENCES Post(post_id) ON DELETE CASCADE,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id)
);

-- ------------------------------------------------------------
-- 9. TRIGGER NGHIỆP VỤ: KIỂM TRA THỜI GIAN LÀM BÀI
-- ------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_check_attempt_time
BEFORE INSERT ON Attempt
FOR EACH ROW
BEGIN
    DECLARE test_start_dt DATETIME;
    DECLARE test_end_dt DATETIME;

    SELECT test_start, test_end INTO test_start_dt, test_end_dt
    FROM Test
    WHERE test_id = NEW.test_id;

    IF NEW.start_time < test_start_dt OR NEW.start_time > test_end_dt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian bắt đầu làm bài không nằm trong khoảng cho phép của bài kiểm tra.';
    END IF;

    IF NEW.end_time IS NOT NULL AND NEW.end_time > test_end_dt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian kết thúc làm bài vượt quá thời gian kết thúc của bài kiểm tra.';
    END IF;
END//

DELIMITER ;

-- ------------------------------------------------------------
-- 10. DỮ LIỆU MẪU (MỖI BẢNG ÍT NHẤT 5 DÒNG)
-- ------------------------------------------------------------
-- Role
INSERT INTO Role (role_name) VALUES ('Student'), ('Lecturer'), ('Admin'), ('Teaching Assistant'), ('Guest');

-- Status
INSERT INTO Status (status_display) VALUES ('Open'), ('Closed'), ('Ongoing'), ('Cancelled'), ('Completed');

-- Semester
INSERT INTO Semester (semester_start, semester_end) VALUES
('2025-01-01', '2025-05-31'),
('2025-06-01', '2025-08-31'),
('2025-09-01', '2025-12-31'),
('2026-01-01', '2026-05-31'),
('2026-06-01', '2026-08-31');

-- Faculty
INSERT INTO Faculty (faculty_name) VALUES
('Computer Science'), ('Electrical Engineering'), ('Mechanical Engineering'),
('Civil Engineering'), ('Business Administration');

-- Subject
INSERT INTO Subject (subject_name, faculty_id) VALUES
('Database Systems', 1),
('Data Structures', 1),
('Circuit Analysis', 2),
('Thermodynamics', 3),
('Structural Analysis', 4),
('Marketing Principles', 5);

-- User
INSERT INTO User (firstName, middleName, lastName, sex, email, birthday, nationality) VALUES
('Nguyen', 'Van', 'An', 'Male', 'an.nguyen@hcmut.edu.vn', '2000-01-15', 'Vietnam'),
('Tran', 'Thi', 'Binh', 'Female', 'binh.tran@hcmut.edu.vn', '2001-03-22', 'Vietnam'),
('Le', 'Quang', 'Chau', 'Male', 'chau.le@hcmut.edu.vn', '2000-07-30', 'Vietnam'),
('Pham', 'Minh', 'Duc', 'Male', 'duc.pham@hcmut.edu.vn', '1999-11-11', 'Vietnam'),
('Hoang', 'Thi', 'Giang', 'Female', 'giang.hoang@hcmut.edu.vn', '2001-05-05', 'Vietnam'),
('Vo', 'Van', 'Hai', 'Male', 'hai.vo@hcmut.edu.vn', '1985-09-12', 'Vietnam'),
('Dang', 'Thi', 'Lan', 'Female', 'lan.dang@hcmut.edu.vn', '1990-12-03', 'Vietnam'),
('Bui', 'Duc', 'Minh', 'Male', 'minh.bui@hcmut.edu.vn', '1988-04-18', 'Vietnam'),
('Ngo', 'Thanh', 'Nga', 'Female', 'nga.ngo@hcmut.edu.vn', '1992-06-25', 'Vietnam'),
('Trinh', 'Van', 'Phong', 'Male', 'phong.trinh@hcmut.edu.vn', '1980-10-10', 'Vietnam');

-- Student (id 1-5)
INSERT INTO Student (id, s_mssv) VALUES (1, 'SV001'), (2, 'SV002'), (3, 'SV003'), (4, 'SV004'), (5, 'SV005');

-- Lecturer (id 6-8)
INSERT INTO Lecturer (id, l_msgv) VALUES (6, 'GV001'), (7, 'GV002'), (8, 'GV003');

-- Admin (id 9-10)
INSERT INTO Admin (id, a_msqt) VALUES (9, 'AD001'), (10, 'AD002');

-- User_acc
INSERT INTO User_acc (ua_id, ua_username, ua_password, ua_image, role_id) VALUES
(1, 'an.nguyen', 'pass123', NULL, 1),
(2, 'binh.tran', 'pass123', NULL, 1),
(3, 'chau.le', 'pass123', NULL, 1),
(4, 'duc.pham', 'pass123', NULL, 1),
(5, 'giang.hoang', 'pass123', NULL, 1),
(6, 'hai.vo', 'gvpass', NULL, 2),
(7, 'lan.dang', 'gvpass', NULL, 2),
(8, 'minh.bui', 'gvpass', NULL, 2),
(9, 'nga.ngo', 'adminpass', NULL, 3),
(10, 'phong.trinh', 'adminpass', NULL, 3);

-- Class
INSERT INTO Class (class_name, subject_id, semester_id, status_id, lecturer_id) VALUES
('DB-2025-01', 1, 1, 1, 6),
('DS-2025-01', 2, 1, 1, 7),
('Circuit-2025-01', 3, 1, 1, 8),
('Thermo-2025-01', 4, 1, 1, 6),
('Struct-2025-01', 5, 1, 2, 7);

-- Enrollment
INSERT INTO Enrollment (student_id, class_id) VALUES
(1,1), (1,2), (2,1), (2,3), (3,2), (3,4), (4,3), (4,5), (5,1), (5,4);

-- Chapter
INSERT INTO Chapter (class_id, chapter_id, chapter_name) VALUES
(1,1,'Introduction'), (1,2,'Relational Model'),
(2,1,'Arrays'), (2,2,'Linked Lists'),
(3,1,'Ohm Law'), (3,2,'Kirchhoff Laws'),
(4,1,'Laws of Thermodynamics'), (4,2,'Entropy'),
(5,1,'Forces'), (5,2,'Beam Deflection');

-- Topic (mỗi chương 2 topic)
INSERT INTO Topic (class_id, chapter_id, topic_id, topic_name, topic_content) VALUES
(1,1,1,'DBMS Overview','...'), (1,1,2,'Data Models','...'),
(1,2,1,'Keys','...'), (1,2,2,'Normalization','...'),
(2,1,1,'Array operations','...'), (2,1,2,'Multi-dim arrays','...'),
(2,2,1,'Singly Linked List','...'), (2,2,2,'Doubly Linked List','...'),
(3,1,1,'Voltage & Current','...'), (3,1,2,'Resistance','...'),
(3,2,1,'KVL','...'), (3,2,2,'KCL','...'),
(4,1,1,'Zeroth Law','...'), (4,1,2,'First Law','...'),
(4,2,1,'Second Law','...'), (4,2,2,'Third Law','...'),
(5,1,1,'Equilibrium','...'), (5,1,2,'Stress & Strain','...'),
(5,2,1,'Elastic Curve','...'), (5,2,2,'Superposition','...');

-- File (5 file)
INSERT INTO File (class_id, chapter_id, topic_id, file_id, file_name, file_path) VALUES
(1,1,1,1,'lecture1.pdf','/files/lecture1.pdf'),
(1,1,2,1,'slides.pptx','/files/slides.pptx'),
(2,1,1,1,'array_examples.zip','/files/array_examples.zip'),
(3,2,2,1,'kcl_simulation.mp4','/files/kcl_simulation.mp4'),
(4,1,2,1,'thermo_lab.pdf','/files/thermo_lab.pdf');

-- Test (5 bài)
INSERT INTO Test (test_name, test_start, test_end, test_timer, class_id, chapter_id) VALUES
('Midterm DB', '2025-03-15 09:00:00', '2025-03-15 10:30:00', 90, 1, 1),
('Quiz 1 DS', '2025-03-20 10:00:00', '2025-03-20 10:30:00', 30, 2, 1),
('Final Circuit', '2025-05-10 13:00:00', '2025-05-10 15:00:00', 120, 3, NULL),
('Thermo Assignment', '2025-04-01 00:00:00', '2025-04-07 23:59:59', 0, 4, NULL),
('Struct Quiz', '2025-03-25 08:00:00', '2025-03-25 08:45:00', 45, 5, 2);

-- Quiz & File_submission
INSERT INTO Quiz (test_id, quizz_id) VALUES (1, 'QZ001'), (2, 'QZ002');
INSERT INTO File_submission (test_id, fs_id, path) VALUES (4, 'FS001', '/submissions/'), (5, 'FS002', '/submissions/');

-- Question (có max_score)
INSERT INTO Question (question_type, question_content, max_score, test_id) VALUES
('multiple_choice', 'What is a primary key?', 1.5, 1),
('true_false', 'A foreign key can be NULL.', 1.0, 1),
('multiple_choice', 'Which is not a linear data structure?', 2.0, 2),
('essay', 'Explain KVL with example.', 5.0, 3),
('multiple_choice', 'First law of thermodynamics is about?', 1.0, 4);

-- Choice (câu trắc nghiệm)
INSERT INTO Choice (choice_content, is_true, question_id) VALUES
('Unique identifier', 1, 1), ('Can be duplicate', 0, 1), ('Always integer', 0, 1),
('True', 1, 2), ('False', 0, 2),
('Array', 0, 3), ('Stack', 0, 3), ('Tree', 1, 3),
('Conservation of energy', 1, 5), ('Conservation of mass', 0, 5);

-- Test_Question (tuỳ chỉnh điểm nếu muốn, để NULL thì dùng max_score của Question)
INSERT INTO Test_Question (test_id, question_id, custom_score) VALUES
(1, 1, NULL),  -- dùng 1.5
(1, 2, NULL),  -- dùng 1.0
(2, 3, 2.5);   -- ghi đè thành 2.5

-- Attempt
INSERT INTO Attempt (attempt_index, start_time, end_time, timer, test_id, student_id) VALUES
(1, '2025-03-15 09:05:00', '2025-03-15 10:20:00', 4500, 1, 1),
(1, '2025-03-20 10:02:00', '2025-03-20 10:28:00', 1560, 2, 2),
(1, '2025-03-15 09:10:00', '2025-03-15 10:25:00', 4500, 1, 3),
(2, '2025-03-16 14:00:00', '2025-03-16 15:30:00', 5400, 1, 1),
(1, '2025-03-26 08:05:00', '2025-03-26 08:40:00', 2100, 5, 4);

-- Student_answer (có chấm điểm cho câu tự luận)
INSERT INTO Student_answer (attempt_id, question_id, choice_id, answer_text, score_awarded) VALUES
(1, 1, 1, NULL, NULL),          -- đúng -> 1.5
(1, 2, 4, NULL, NULL),          -- đúng -> 1.0
(2, 3, 8, NULL, NULL),          -- đúng -> 2.5 (do custom_score)
(3, 1, 1, NULL, NULL),          -- đúng
(3, 2, 4, NULL, NULL),          -- đúng
(4, 1, 2, NULL, NULL),          -- sai -> 0
(4, 2, 5, NULL, NULL),          -- sai -> 0
(5, 5, 9, NULL, NULL);          -- đúng -> 1.0

-- Post & Comment
INSERT INTO Post (post_name, post_description, post_start, ua_id, class_id) VALUES
('Welcome to DB', 'Introduction post', NOW(), 1, 1),
('Assignment 1', 'Submit by 15/4', '2025-04-01 00:00:00', 6, 1),
('Lecture notes', 'Chapter 1 slides', NOW(), 6, 2),
('Quiz reminder', 'Next Monday', '2025-03-19 08:00:00', 7, 2),
('Project groups', 'Form groups of 3', NOW(), 8, 3);

INSERT INTO Comment (comment_content, post_id, ua_id) VALUES
('Thanks!', 1, 2),
('When is deadline?', 2, 3),
('Good material', 3, 4),
('I will attend', 4, 5),
('Group 1: A, B, C', 5, 1);

-- ============================================================
-- KẾT THÚC
-- ============================================================