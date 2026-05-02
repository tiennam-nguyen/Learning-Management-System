-- ============================================================
-- DATABASE: elearning
-- MÔ TẢ: Hệ thống quản lý học tập (LMS)
-- PHIÊN BẢN: 2.8 (Bổ sung đầy đủ ràng buộc nghiệp vụ)
-- ============================================================

DROP DATABASE IF EXISTS elearning;
CREATE DATABASE elearning;
USE elearning;

-- ------------------------------------------------------------
-- 1. DANH MỤC CƠ SỞ
-- ------------------------------------------------------------
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

-- Thêm cột credit (số tín chỉ)
CREATE TABLE Subject (
    subject_id INT AUTO_INCREMENT PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    credit INT NOT NULL DEFAULT 3,
    faculty_id INT NOT NULL,
    FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id),
    CONSTRAINT chk_credit_positive CHECK (credit > 0)
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
    nationality VARCHAR(50),
    CONSTRAINT chk_email_format CHECK (email LIKE '%@hcmut.edu.vn')
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

-- Thêm bảng mới để lưu thuộc tính đa trị degree của giảng viên
CREATE TABLE Lecturer_Degree (
    lecturer_id INT,
    degree ENUM('Bachelor', 'Master', 'PhD') NOT NULL,
    PRIMARY KEY (lecturer_id, degree),
    FOREIGN KEY (lecturer_id) REFERENCES Lecturer(id) ON DELETE CASCADE
);

CREATE TABLE Admin (
    id INT PRIMARY KEY,
    a_msqt VARCHAR(20) UNIQUE NOT NULL,
    degree ENUM('Bachelor', 'Master', 'PhD') NOT NULL,
    FOREIGN KEY (id) REFERENCES User(id) ON DELETE CASCADE
);

CREATE TABLE User_acc (
    ua_id INT PRIMARY KEY,
    ua_username VARCHAR(50) UNIQUE NOT NULL,
    ua_password VARCHAR(255) NOT NULL,
    ua_image VARCHAR(255),
    FOREIGN KEY (ua_id) REFERENCES User(id) ON DELETE CASCADE
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
    is_allowed_to_discuss BOOLEAN DEFAULT TRUE,
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

-- Thêm cột file_size (MB) và ràng buộc <= 200
CREATE TABLE File (
    class_id INT,
    chapter_id INT,
    topic_id INT,
    file_id INT,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(512) NOT NULL,
    file_size INT NOT NULL COMMENT 'Kích thước file (MB)',
    update_date DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (class_id, chapter_id, topic_id, file_id),
    FOREIGN KEY (class_id, chapter_id, topic_id) REFERENCES Topic(class_id, chapter_id, topic_id) ON DELETE CASCADE,
    CONSTRAINT chk_file_size CHECK (file_size <= 200)
);

-- ------------------------------------------------------------
-- 5. BÀI KIỂM TRA
-- ------------------------------------------------------------
CREATE TABLE Test (
    test_id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(255) NOT NULL,
    test_type ENUM('Quiz', 'File_submission') NOT NULL, 
    test_start DATETIME NOT NULL, -- Thêm NOT NULL
    test_end DATETIME NOT NULL,   -- Thêm NOT NULL
    test_timer INT NOT NULL COMMENT 'Thời gian làm bài (phút), 0 nếu không giới hạn', -- Thêm NOT NULL
    class_id INT NOT NULL,
    chapter_id INT,
    FOREIGN KEY (class_id) REFERENCES Class(class_id),
    FOREIGN KEY (class_id, chapter_id) REFERENCES Chapter(class_id, chapter_id),
    CONSTRAINT chk_test_dates CHECK (test_start < test_end)
);

CREATE TABLE Quiz (
    test_id INT PRIMARY KEY,
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);

CREATE TABLE File_submission (
    test_id INT PRIMARY KEY,
    path VARCHAR(512),
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE
);
-- ------------------------------------------------------------
-- 6. NGÂN HÀNG CÂU HỎI
-- ------------------------------------------------------------
CREATE TABLE Question (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    question_type ENUM('multiple_choice', 'true_false', 'essay') NOT NULL,
    question_content TEXT NOT NULL,
    max_score DECIMAL(5,2) DEFAULT 1.0 NOT NULL,
    CONSTRAINT chk_question_max_score_positive CHECK (max_score > 0)
);

CREATE TABLE Test_Question (
    test_id INT NOT NULL,
    question_id INT NOT NULL,
    custom_score DECIMAL(5,2) DEFAULT NULL COMMENT 'NULL = dùng max_score của Question',
    PRIMARY KEY (test_id, question_id),
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE,
    CONSTRAINT chk_custom_score_positive CHECK (custom_score IS NULL OR custom_score > 0)
);

CREATE TABLE Choice (
    choice_id INT AUTO_INCREMENT PRIMARY KEY,
    question_id INT NOT NULL,
    choice_content TEXT NOT NULL,
    is_true BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (question_id) REFERENCES Question(question_id) ON DELETE CASCADE,
    UNIQUE INDEX idx_choice_question (question_id, choice_id)
);

-- ------------------------------------------------------------
-- 7. LẦN LÀM BÀI (ATTEMPT)
-- ------------------------------------------------------------
CREATE TABLE Attempt (
    attempt_id INT AUTO_INCREMENT PRIMARY KEY,
    attempt_index INT NOT NULL,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME,
    timer INT COMMENT 'Thời gian đã sử dụng (giây)',
    test_id INT NOT NULL,
    student_id INT NOT NULL,
    score DECIMAL(7,2) DEFAULT 0 COMMENT 'Điểm tổng, được tính và cập nhật tự động bởi trigger',
    FOREIGN KEY (test_id) REFERENCES Test(test_id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES Student(id) ON DELETE CASCADE,
    CONSTRAINT chk_attempt_timer CHECK (timer IS NULL OR timer >= 0),
    CONSTRAINT chk_attempt_score CHECK (score >= 0)
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
    FOREIGN KEY (question_id, choice_id) REFERENCES Choice(question_id, choice_id) ON DELETE CASCADE,
    CONSTRAINT uq_student_answer UNIQUE (attempt_id, question_id),
    CONSTRAINT chk_answer CHECK (
        (choice_id IS NULL AND answer_text IS NULL) OR
        (choice_id IS NOT NULL AND answer_text IS NULL) OR
        (choice_id IS NULL AND answer_text IS NOT NULL)
    ),
    CONSTRAINT chk_score_awarded CHECK (score_awarded IS NULL OR score_awarded >= 0)
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
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id) ON DELETE CASCADE, -- Đã bổ sung
    FOREIGN KEY (class_id) REFERENCES Class(class_id) ON DELETE CASCADE
);

CREATE TABLE Comment (
    comment_id INT AUTO_INCREMENT PRIMARY KEY,
    comment_content TEXT NOT NULL,
    comment_start DATETIME DEFAULT CURRENT_TIMESTAMP,
    post_id INT NOT NULL,
    ua_id INT NOT NULL,
    FOREIGN KEY (post_id) REFERENCES Post(post_id) ON DELETE CASCADE,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id) ON DELETE CASCADE -- Đã bổ sung
);

-- ------------------------------------------------------------
-- 9. TRIGGER & HÀM HỖ TRỢ
-- ------------------------------------------------------------
DELIMITER //

-- Hàm tính điểm (Viết lại dùng CURSOR và LOOP để đáp ứng barem điểm)
DROP FUNCTION IF EXISTS calculate_score //
CREATE FUNCTION calculate_score(p_attempt_id INT) RETURNS DECIMAL(7,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_score DECIMAL(7,2) DEFAULT 0.00;
    DECLARE v_qtype VARCHAR(20);
    DECLARE v_custom_score DECIMAL(5,2);
    DECLARE v_max_score DECIMAL(5,2);
    DECLARE v_score_awarded DECIMAL(5,2);
    DECLARE v_is_true BOOLEAN;
    DECLARE done INT DEFAULT FALSE;
    
    -- Khai báo con trỏ (Cursor) lấy danh sách câu trả lời của 1 Attempt
    DECLARE cur_answers CURSOR FOR 
        SELECT q.question_type, tq.custom_score, q.max_score, sa.score_awarded, c.is_true
        FROM Student_answer sa
        JOIN Question q ON sa.question_id = q.question_id
        JOIN Attempt a ON sa.attempt_id = a.attempt_id
        JOIN Test_Question tq ON tq.test_id = a.test_id AND tq.question_id = sa.question_id
        LEFT JOIN Choice c ON sa.choice_id = c.choice_id
        WHERE sa.attempt_id = p_attempt_id;
        
    -- Xử lý khi hết dữ liệu trong Cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Kiểm tra tham số đầu vào (Yêu cầu bắt buộc của Barem 2.4)
    IF p_attempt_id IS NULL OR p_attempt_id <= 0 THEN
        RETURN 0.00;
    END IF;

    OPEN cur_answers;

    -- Vòng lặp tính toán điểm
    read_loop: LOOP
        FETCH cur_answers INTO v_qtype, v_custom_score, v_max_score, v_score_awarded, v_is_true;
        
        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Câu lệnh IF kiểm tra logic tính điểm
        IF v_qtype IN ('multiple_choice', 'true_false') THEN
            IF v_is_true = TRUE THEN
                SET total_score = total_score + COALESCE(v_custom_score, v_max_score);
            END IF;
        ELSEIF v_qtype = 'essay' THEN
            IF v_score_awarded IS NOT NULL THEN
                SET total_score = total_score + v_score_awarded;
            END IF;
        END IF;
        
    END LOOP;

    CLOSE cur_answers;
    RETURN total_score;
END//

-- Triggers cập nhật điểm
CREATE TRIGGER trg_update_score_after_insert
AFTER INSERT ON Student_answer
FOR EACH ROW
BEGIN
    UPDATE Attempt SET score = calculate_score(NEW.attempt_id)
    WHERE attempt_id = NEW.attempt_id;
END//

CREATE TRIGGER trg_update_score_after_update
AFTER UPDATE ON Student_answer
FOR EACH ROW
BEGIN
    UPDATE Attempt SET score = calculate_score(NEW.attempt_id)
    WHERE attempt_id = NEW.attempt_id;
END//

CREATE TRIGGER trg_update_score_after_delete
AFTER DELETE ON Student_answer
FOR EACH ROW
BEGIN
    UPDATE Attempt SET score = calculate_score(OLD.attempt_id)
    WHERE attempt_id = OLD.attempt_id;
END//

-- Trigger xác thực câu trả lời
CREATE TRIGGER trg_validate_student_answer
BEFORE INSERT ON Student_answer
FOR EACH ROW
BEGIN
    DECLARE v_question_type VARCHAR(20);
    DECLARE v_test_id INT;
    
    SELECT question_type INTO v_question_type
    FROM Question WHERE question_id = NEW.question_id;
    
    SELECT test_id INTO v_test_id
    FROM Attempt WHERE attempt_id = NEW.attempt_id;
    
    IF NOT EXISTS (
        SELECT 1 FROM Test_Question
        WHERE test_id = v_test_id AND question_id = NEW.question_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Câu hỏi không thuộc bài kiểm tra này.';
    END IF;
    
    IF v_question_type IN ('multiple_choice', 'true_false') THEN
        IF NEW.choice_id IS NOT NULL AND NEW.answer_text IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Câu hỏi trắc nghiệm chỉ được có choice_id hoặc bỏ trống, không được có answer_text.';
        END IF;
        IF NEW.score_awarded IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể tự gán điểm cho câu hỏi trắc nghiệm.';
        END IF;
    ELSEIF v_question_type = 'essay' THEN
        IF NEW.choice_id IS NOT NULL AND NEW.answer_text IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Câu hỏi tự luận chỉ được có answer_text hoặc bỏ trống, không được có choice_id.';
        END IF;
    END IF;
END//

CREATE TRIGGER trg_validate_student_answer_update
BEFORE UPDATE ON Student_answer
FOR EACH ROW
BEGIN
    DECLARE v_question_type VARCHAR(20);
    DECLARE v_test_id INT;
    
    SELECT question_type INTO v_question_type
    FROM Question WHERE question_id = NEW.question_id;
    
    SELECT test_id INTO v_test_id
    FROM Attempt WHERE attempt_id = NEW.attempt_id;
    
    IF NOT EXISTS (
        SELECT 1 FROM Test_Question
        WHERE test_id = v_test_id AND question_id = NEW.question_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Câu hỏi không thuộc bài kiểm tra này.';
    END IF;
    
    IF v_question_type IN ('multiple_choice', 'true_false') THEN
        IF NEW.choice_id IS NOT NULL AND NEW.answer_text IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Câu hỏi trắc nghiệm chỉ được có choice_id hoặc bỏ trống, không được có answer_text.';
        END IF;
        IF NEW.score_awarded IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể tự gán điểm cho câu hỏi trắc nghiệm.';
        END IF;
    ELSEIF v_question_type = 'essay' THEN
        IF NEW.choice_id IS NOT NULL AND NEW.answer_text IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Câu hỏi tự luận chỉ được có answer_text hoặc bỏ trống, không được có choice_id.';
        END IF;
    END IF;
END//

-- Trigger kiểm tra thời gian làm bài
CREATE TRIGGER trg_check_attempt_time_insert
BEFORE INSERT ON Attempt
FOR EACH ROW
BEGIN
    DECLARE test_start_dt DATETIME;
    DECLARE test_end_dt DATETIME;
    DECLARE test_timer_mins INT;
    DECLARE class_id_val INT;
    
    SELECT test_start, test_end, test_timer, class_id
    INTO test_start_dt, test_end_dt, test_timer_mins, class_id_val
    FROM Test WHERE test_id = NEW.test_id;
    
    IF NEW.start_time < test_start_dt OR NEW.start_time > test_end_dt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian bắt đầu làm bài không hợp lệ.';
    END IF;
    IF NEW.end_time IS NOT NULL AND NEW.end_time > test_end_dt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian kết thúc vượt quá thời gian cho phép.';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM Enrollment
        WHERE student_id = NEW.student_id AND class_id = class_id_val
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sinh viên chưa đăng ký lớp học này.';
    END IF;
    
    IF test_timer_mins > 0 AND NEW.timer IS NOT NULL AND NEW.timer > (test_timer_mins * 60) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian làm bài vượt quá thời gian quy định của bài kiểm tra.';
    END IF;
END//

CREATE TRIGGER trg_check_attempt_time_update
BEFORE UPDATE ON Attempt
FOR EACH ROW
BEGIN
    DECLARE test_start_dt DATETIME;
    DECLARE test_end_dt DATETIME;
    DECLARE test_timer_mins INT;
    DECLARE class_id_val INT;
    
    SELECT test_start, test_end, test_timer, class_id
    INTO test_start_dt, test_end_dt, test_timer_mins, class_id_val
    FROM Test WHERE test_id = NEW.test_id;
    
    IF NEW.start_time < test_start_dt OR NEW.start_time > test_end_dt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian bắt đầu làm bài không hợp lệ.';
    END IF;
    IF NEW.end_time IS NOT NULL AND NEW.end_time > test_end_dt THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian kết thúc vượt quá thời gian cho phép.';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM Enrollment
        WHERE student_id = NEW.student_id AND class_id = class_id_val
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sinh viên chưa đăng ký lớp học này.';
    END IF;
    
    IF test_timer_mins > 0 AND NEW.timer IS NOT NULL AND NEW.timer > (test_timer_mins * 60) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Thời gian làm bài vượt quá thời gian quy định của bài kiểm tra.';
    END IF;
END//

-- Trigger ngăn tạo Choice cho câu hỏi essay
CREATE TRIGGER trg_prevent_choice_for_essay
BEFORE INSERT ON Choice
FOR EACH ROW
BEGIN
    DECLARE v_question_type VARCHAR(20);
    SELECT question_type INTO v_question_type
    FROM Question WHERE question_id = NEW.question_id;
    
    IF v_question_type = 'essay' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể thêm lựa chọn cho câu hỏi tự luận.';
    END IF;
END//

CREATE TRIGGER trg_prevent_choice_for_essay_update
BEFORE UPDATE ON Choice
FOR EACH ROW
BEGIN
    DECLARE v_question_type VARCHAR(20);
    SELECT question_type INTO v_question_type
    FROM Question WHERE question_id = NEW.question_id;
    
    IF v_question_type = 'essay' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể cập nhật lựa chọn cho câu hỏi tự luận.';
    END IF;
END//

-- ========== RÀNG BUỘC MỚI BỔ SUNG ==========

-- 1. Trigger kiểm tra trạng thái lớp trước khi tạo Test (chỉ cho phép status = 'Open')
CREATE TRIGGER trg_check_class_status_for_test
BEFORE INSERT ON Test
FOR EACH ROW
BEGIN
    DECLARE v_status_name VARCHAR(50);
    
    SELECT s.status_display INTO v_status_name
    FROM Class c
    JOIN Status s ON c.status_id = s.status_id
    WHERE c.class_id = NEW.class_id;
    
    IF v_status_name != 'Open' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Chỉ có thể thêm bài kiểm tra vào lớp học đang ở trạng thái Open.';
    END IF;
END//

-- 2. Trigger giới hạn số lượng file tối đa 5 trong một topic
CREATE TRIGGER trg_limit_files_per_topic
BEFORE INSERT ON File
FOR EACH ROW
BEGIN
    DECLARE file_count INT;
    
    SELECT COUNT(*) INTO file_count
    FROM File
    WHERE class_id = NEW.class_id
      AND chapter_id = NEW.chapter_id
      AND topic_id = NEW.topic_id;
    
    IF file_count >= 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Mỗi topic không được có quá 5 file đính kèm.';
    END IF;
END//

DELIMITER ;

-- ============================================================
-- PHẦN BỔ SUNG: CÁC BẢNG VÀ TRIGGER ĐỂ FIX COMMENT CỦA GIẢNG VIÊN
-- ============================================================

-- 1. Xử lý liên kết ĐỆ QUY (Recursive) cho EERD: Bảng môn học tiên quyết
CREATE TABLE Subject_Prerequisite (
    subject_id INT NOT NULL,
    prereq_id INT NOT NULL,
    PRIMARY KEY (subject_id, prereq_id),
    FOREIGN KEY (subject_id) REFERENCES Subject(subject_id) ON DELETE CASCADE,
    FOREIGN KEY (prereq_id) REFERENCES Subject(subject_id) ON DELETE CASCADE,
    CONSTRAINT chk_no_self_prereq CHECK (subject_id != prereq_id)
);

-- 2. Xử lý giới hạn 3 thiết bị đăng nhập: Tạo bảng Session
CREATE TABLE User_Session (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    ua_id INT NOT NULL,
    login_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ua_id) REFERENCES User_acc(ua_id) ON DELETE CASCADE
);

DELIMITER //

-- Bắt lỗi đăng nhập quá 3 thiết bị
CREATE TRIGGER trg_limit_3_devices
BEFORE INSERT ON User_Session
FOR EACH ROW
BEGIN
    DECLARE active_sessions INT;
    SELECT COUNT(*) INTO active_sessions FROM User_Session WHERE ua_id = NEW.ua_id;
    IF active_sessions >= 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tài khoản đang đăng nhập trên 3 thiết bị, vui lòng đăng xuất bớt.';
    END IF;
END//

-- 3. Xử lý thiếu Trigger UPDATE trên bảng Test (Ngăn đổi class_id sang lớp đang Closed)
CREATE TRIGGER trg_check_class_status_for_test_update
BEFORE UPDATE ON Test
FOR EACH ROW
BEGIN
    DECLARE v_status_name VARCHAR(50);
    IF NEW.class_id != OLD.class_id THEN
        SELECT s.status_display INTO v_status_name
        FROM Class c JOIN Status s ON c.status_id = s.status_id
        WHERE c.class_id = NEW.class_id;
        
        IF v_status_name != 'Open' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lớp chuyển đến phải ở trạng thái Open.';
        END IF;
    END IF;
END//

-- 4. Xử lý Ràng buộc: Sinh viên không được hủy lớp nếu làm tổng tín chỉ < 11
CREATE TRIGGER trg_min_11_credits_delete
BEFORE DELETE ON Enrollment
FOR EACH ROW
BEGIN
    DECLARE total_credits INT;
    DECLARE dropping_credit INT;
    
    SELECT su.credit INTO dropping_credit
    FROM Class c JOIN Subject su ON c.subject_id = su.subject_id
    WHERE c.class_id = OLD.class_id;
    
    SELECT COALESCE(SUM(su.credit), 0) INTO total_credits
    FROM Enrollment e
    JOIN Class c ON e.class_id = c.class_id
    JOIN Subject su ON c.subject_id = su.subject_id
    WHERE e.student_id = OLD.student_id 
      AND c.semester_id = (SELECT semester_id FROM Class WHERE class_id = OLD.class_id);
      
    IF (total_credits - dropping_credit) < 11 AND total_credits >= 11 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không thể hủy môn: Tổng số tín chỉ trong học kỳ rớt xuống dưới 11.';
    END IF;
END//

-- 5. Xử lý Ràng buộc: Bài kiểm tra phải có ít nhất 1 câu hỏi
CREATE TRIGGER trg_prevent_delete_last_question
BEFORE DELETE ON Test_Question
FOR EACH ROW
BEGIN
    DECLARE q_count INT;
    SELECT COUNT(*) INTO q_count FROM Test_Question WHERE test_id = OLD.test_id;
    IF q_count <= 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bài kiểm tra phải có ít nhất 1 câu hỏi, không thể xóa câu cuối cùng.';
    END IF;
END//

-- 6. Xử lý Ràng buộc: Câu hỏi phải có ít nhất 1 đáp án đúng
CREATE TRIGGER trg_prevent_delete_last_correct_choice
BEFORE DELETE ON Choice
FOR EACH ROW
BEGIN
    DECLARE correct_count INT;
    IF OLD.is_true = 1 THEN
        SELECT COUNT(*) INTO correct_count FROM Choice WHERE question_id = OLD.question_id AND is_true = 1;
        IF correct_count <= 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Câu hỏi trắc nghiệm phải có ít nhất 1 đáp án đúng.';
        END IF;
    END IF;
END//

CREATE TRIGGER trg_prevent_uncheck_last_correct_choice
BEFORE UPDATE ON Choice
FOR EACH ROW
BEGIN
    DECLARE correct_count INT;
    IF OLD.is_true = 1 AND NEW.is_true = 0 THEN
        SELECT COUNT(*) INTO correct_count FROM Choice WHERE question_id = OLD.question_id AND is_true = 1;
        IF correct_count <= 1 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Câu hỏi trắc nghiệm phải có ít nhất 1 đáp án đúng.';
        END IF;
    END IF;
END//

-- [MỚI] Chặn update câu trắc nghiệm thành tự luận nếu đang có Choice
CREATE TRIGGER trg_prevent_update_to_essay_with_choices
BEFORE UPDATE ON Question
FOR EACH ROW
BEGIN
    DECLARE choice_count INT;
    IF OLD.question_type != 'essay' AND NEW.question_type = 'essay' THEN
        SELECT COUNT(*) INTO choice_count FROM Choice WHERE question_id = NEW.question_id;
        IF choice_count > 0 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Không thể đổi thành câu hỏi tự luận vì câu hỏi này đang chứa các đáp án (Choices). Vui lòng xóa các đáp án trước.';
        END IF;
    END IF;
END//

DELIMITER ;

-- ------------------------------------------------------------
-- 10. DỮ LIỆU MẪU (ĐÃ CẬP NHẬT)
-- ------------------------------------------------------------
-- Status
INSERT INTO Status (status_display) VALUES
('Open'), ('Closed'), ('Ongoing'), ('Cancelled'), ('Completed');

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

-- Subject (đã thêm credit)
INSERT INTO Subject (subject_name, credit, faculty_id) VALUES
('Database Systems', 4, 1),
('Data Structures', 3, 1),
('Circuit Analysis', 3, 2),
('Thermodynamics', 3, 3),
('Structural Analysis', 4, 4),
('Marketing Principles', 3, 5);

-- User (email đều đuôi @hcmut.edu.vn)
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
('Trinh', 'Van', 'Phong', 'Male', 'phong.trinh@hcmut.edu.vn', '1980-10-10', 'Vietnam'),
('Ly', 'Thi', 'Quyen', 'Female', 'quyen.ly@hcmut.edu.vn', '1983-11-01', 'Vietnam'),
('Mai', 'Van', 'Sang', 'Male', 'sang.mai@hcmut.edu.vn', '1987-02-14', 'Vietnam'),
('Do', 'Thi', 'Thuy', 'Female', 'thuy.do@hcmut.edu.vn', '1995-08-20', 'Vietnam'),
('Phan', 'Van', 'Tuan', 'Male', 'tuan.phan@hcmut.edu.vn', '1982-05-09', 'Vietnam'),
('Vu', 'Thi', 'Van', 'Female', 'van.vu@hcmut.edu.vn', '1991-12-30', 'Vietnam');

-- Student
INSERT INTO Student (id, s_mssv) VALUES
(1, 'SV001'), (2, 'SV002'), (3, 'SV003'), (4, 'SV004'), (5, 'SV005');

-- Lecturer (đã có degree)
-- Dữ liệu Lecturer (không còn cột degree)
INSERT INTO Lecturer (id, l_msgv) VALUES
(6, 'GV001'),
(7, 'GV002'),
(8, 'GV003'),
(11, 'GV004'),
(12, 'GV005');

-- Thêm dữ liệu cho bảng Lecturer_Degree (Một giảng viên giờ đây có thể insert nhiều dòng, đại diện cho nhiều bằng cấp)
INSERT INTO Lecturer_Degree (lecturer_id, degree) VALUES
(6, 'Bachelor'), (6, 'Master'), (6, 'PhD'), -- GV001 có cả 3 bằng
(7, 'Bachelor'), (7, 'Master'),             -- GV002 có 2 bằng
(8, 'Bachelor'), (8, 'Master'),
(11, 'Bachelor'), (11, 'PhD'),
(12, 'Bachelor');

-- Admin (đã có degree)
INSERT INTO Admin (id, a_msqt, degree) VALUES
(9, 'AD001', 'Master'),
(10, 'AD002', 'Bachelor'),
(13, 'AD003', 'PhD'),
(14, 'AD004', 'Master'),
(15, 'AD005', 'Bachelor');

-- User_acc
INSERT INTO User_acc (ua_id, ua_username, ua_password, ua_image) VALUES
(1, 'an.nguyen', SHA2('pass123', 256), NULL),
(2, 'binh.tran', SHA2('pass123', 256), NULL),
(3, 'chau.le', SHA2('pass123', 256), NULL),
(4, 'duc.pham', SHA2('pass123', 256), NULL),
(5, 'giang.hoang', SHA2('pass123', 256), NULL),
(6, 'hai.vo', SHA2('gvpass', 256), NULL),
(7, 'lan.dang', SHA2('gvpass', 256), NULL),
(8, 'minh.bui', SHA2('gvpass', 256), NULL),
(9, 'nga.ngo', SHA2('adminpass', 256), NULL),
(10, 'phong.trinh', SHA2('adminpass', 256), NULL),
(11, 'quyen.ly', SHA2('gvpass', 256), NULL),
(12, 'sang.mai', SHA2('gvpass', 256), NULL),
(13, 'thuy.do', SHA2('adminpass', 256), NULL),
(14, 'tuan.phan', SHA2('adminpass', 256), NULL),
(15, 'van.vu', SHA2('adminpass', 256), NULL);

-- Class (đảm bảo status_id tương ứng với 'Open' hoặc 'Ongoing' để Test được tạo)
INSERT INTO Class (class_name, subject_id, semester_id, status_id, lecturer_id) VALUES
('DB-2025-01', 1, 1, 1, 6),      -- status 'Open'
('DS-2025-01', 2, 1, 1, 7),      -- 'Open'
('Circuit-2025-01', 3, 1, 1, 8), -- 'Open'
('Thermo-2025-01', 4, 1, 1, 11),-- 'Open'
('Struct-2025-01', 5, 1, 3, 12); -- 'Ongoing' (status_id=3) – vẫn cho phép tạo Test vì trigger chỉ chặn 'Open'? Cần điều chỉnh: thường 'Ongoing' cũng được phép. Trigger của chúng ta chỉ cho 'Open', nên có thể đổi thành 'Open' hoặc sửa trigger. Tôi sẽ giữ nguyên trigger chỉ cho 'Open' và đổi lớp này thành 'Open' luôn cho an toàn.
UPDATE Class SET status_id = 1 WHERE class_id = 5; -- sửa thành Open

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

-- Topic
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

-- File (có file_size)
INSERT INTO File (class_id, chapter_id, topic_id, file_id, file_name, file_path, file_size) VALUES
(1,1,1,1,'lecture1.pdf','/files/lecture1.pdf', 150),
(1,1,2,1,'slides.pptx','/files/slides.pptx', 80),
(2,1,1,1,'array_examples.zip','/files/array_examples.zip', 50),
(3,2,2,1,'kcl_simulation.mp4','/files/kcl_simulation.mp4', 180),
(4,1,2,1,'thermo_lab.pdf','/files/thermo_lab.pdf', 120);

-- Thêm dữ liệu loại bài kiểm tra vào cột test_type
INSERT INTO Test (test_name, test_type, test_start, test_end, test_timer, class_id, chapter_id) VALUES
('Midterm DB', 'Quiz', '2025-03-15 09:00:00', '2025-03-15 10:30:00', 90, 1, 1),
('Quiz 1 DS', 'Quiz', '2025-03-20 10:00:00', '2025-03-20 10:30:00', 30, 2, 1),
('Final Circuit', 'Quiz', '2025-05-10 13:00:00', '2025-05-10 15:00:00', 120, 3, NULL),
('Thermo Assignment', 'File_submission', '2025-04-01 00:00:00', '2025-04-07 23:59:59', 0, 4, NULL),
('Struct Quiz', 'File_submission', '2025-03-25 08:00:00', '2025-03-25 08:45:00', 45, 5, 2),
('Quiz 2 DB', 'Quiz', '2025-04-10 09:00:00', '2025-04-10 10:00:00', 60, 1, 2),
('Quiz 3 DS', 'Quiz', '2025-04-15 10:00:00', '2025-04-15 10:45:00', 45, 2, 2),
('Assignment 2 Circuit', 'File_submission', '2025-05-01 00:00:00', '2025-05-05 23:59:59', 0, 3, NULL),
('Project DB', 'File_submission', '2025-05-20 00:00:00', '2025-06-01 23:59:59', 0, 1, NULL),
('Final Exam DS', 'File_submission', '2025-06-10 09:00:00', '2025-06-10 11:30:00', 150, 2, NULL);

-- Quiz
INSERT INTO Quiz (test_id) VALUES
(1), (2), (6), (7), (3);

-- File_submission
INSERT INTO File_submission (test_id, path) VALUES
(4, '/submissions/'),
(5, '/submissions/'),
(8, '/submissions/'),
(9, '/submissions/'),
(10, '/submissions/');

-- Question
INSERT INTO Question (question_type, question_content, max_score) VALUES
('multiple_choice', 'What is a primary key?', 1.5),
('true_false', 'A foreign key can be NULL.', 1.0),
('multiple_choice', 'Which is not a linear data structure?', 2.0),
('essay', 'Explain KVL with example.', 5.0),
('multiple_choice', 'First law of thermodynamics is about?', 1.0);

-- Choice
INSERT INTO Choice (question_id, choice_content, is_true) VALUES
(1, 'Unique identifier', 1), (1, 'Can be duplicate', 0), (1, 'Always integer', 0),
(2, 'True', 1), (2, 'False', 0),
(3, 'Array', 0), (3, 'Stack', 0), (3, 'Tree', 1),
(5, 'Conservation of energy', 1), (5, 'Conservation of mass', 0);

-- Test_Question
INSERT INTO Test_Question (test_id, question_id, custom_score) VALUES
(1, 1, NULL), (1, 2, NULL), (2, 3, 2.5), (3, 4, NULL), (5, 5, NULL);

-- Attempt (đã sửa thời gian)
INSERT INTO Attempt (attempt_index, start_time, end_time, timer, test_id, student_id) VALUES
(1, '2025-03-15 09:05:00', '2025-03-15 10:20:00', 4500, 1, 1),
(1, '2025-03-20 10:02:00', '2025-03-20 10:28:00', 1560, 2, 3),
(1, '2025-03-15 09:10:00', '2025-03-15 10:25:00', 4500, 1, 2),
(2, '2025-03-15 09:15:00', '2025-03-15 10:30:00', 4500, 1, 1),
(1, '2025-03-25 08:05:00', '2025-03-25 08:40:00', 2100, 5, 4);

-- Student_answer
INSERT INTO Student_answer (attempt_id, question_id, choice_id, answer_text, score_awarded) VALUES
(1, 1, 1, NULL, NULL),
(1, 2, 4, NULL, NULL),
(2, 3, 8, NULL, NULL),
(3, 1, 1, NULL, NULL),
(3, 2, 4, NULL, NULL),
(4, 1, 2, NULL, NULL),
(4, 2, 5, NULL, NULL),
(5, 5, 9, NULL, NULL);

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