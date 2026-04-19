USE elearning;

-- ==========================================
-- MODULE: DATABASE ENHANCEMENT / HARDENING
-- Mục tiêu:
--   - Bổ sung constraint & index
--   - Tối ưu hiệu năng truy vấn
--   - Hỗ trợ soft delete
--   - Cải thiện bảo mật & kiểm soát dữ liệu
-- ==========================================


-- ==========================================
-- 1. TEST & ATTEMPT IMPROVEMENT
-- ==========================================

-- Thêm giới hạn số lần làm bài (default = 1)
ALTER TABLE Test 
ADD COLUMN max_attempts INT DEFAULT 1;

-- Lưu thời điểm bắt đầu làm bài (phục vụ tracking / timeout)
ALTER TABLE Attempt 
ADD COLUMN start_time DATETIME DEFAULT CURRENT_TIMESTAMP;


-- ==========================================
-- 2. USER SECURITY ENHANCEMENT
-- ==========================================

-- is_active: bật/tắt tài khoản
-- salt: hỗ trợ hash password an toàn hơn
ALTER TABLE User_acc 
ADD COLUMN is_active BOOLEAN DEFAULT TRUE,
ADD COLUMN salt VARCHAR(64) NOT NULL DEFAULT '';


-- ==========================================
-- 3. PERFORMANCE OPTIMIZATION
-- ==========================================

-- Index phục vụ query theo test + student (rất thường dùng)
CREATE INDEX idx_attempt_test_student 
ON Attempt(test_id, student_id);

-- Đảm bảo mỗi câu hỏi chỉ có 1 câu trả lời trong 1 attempt
ALTER TABLE Student_answer 
ADD UNIQUE KEY uk_attempt_question (attempt_id, question_id);


-- ==========================================
-- 4. SOFT DELETE SUPPORT
-- ==========================================

-- Thêm cờ is_deleted cho các bảng chính
-- → tránh xóa vật lý, giữ dữ liệu phục vụ audit/log
ALTER TABLE Class 
ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;

ALTER TABLE Test 
ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;

ALTER TABLE Question 
ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;

ALTER TABLE Post 
ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;

ALTER TABLE Comment 
ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;


-- ==========================================
-- 5. MASTER DATA INITIALIZATION
-- ==========================================

-- Khởi tạo các role mặc định trong hệ thống
INSERT INTO Role (role_name) 
VALUES ('Admin'), ('Lecturer'), ('Student');