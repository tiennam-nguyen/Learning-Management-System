-- ==========================================
-- Vị trí chạy: Chạy SAU khi chạy file elearning.sql (khởi tạo bảng gốc) 
--              và TRƯỚC khi chạy các file thủ tục (procedures_...).
-- ==========================================
USE elearning;

-- ==========================================
-- PHẦN 1: NÂNG CẤP CẤU TRÚC BẢNG (ALTER TABLES)
-- ==========================================

-- 1. Bảng Test: Thêm giới hạn số lần làm bài (Phục vụ sp_StartAttempt)
ALTER TABLE Test 
ADD COLUMN max_attempts INT DEFAULT 1;

-- 2. Bảng Attempt: Thêm thời gian bắt đầu làm bài (Phục vụ tính toán thời gian thi)
ALTER TABLE Attempt 
ADD COLUMN start_time DATETIME DEFAULT CURRENT_TIMESTAMP;

-- 3. Bảng User_acc: Thêm trạng thái hoạt động (Phục vụ tính năng Khóa tài khoản / Soft Delete)
ALTER TABLE User_acc 
ADD COLUMN is_active BOOLEAN DEFAULT TRUE;


-- ==========================================
-- PHẦN 2: KHỞI TẠO DỮ LIỆU MẪU BẮT BUỘC (SEED DATA)
-- ==========================================

-- Chèn dữ liệu danh mục Phân quyền (Role) để tránh lỗi Khóa ngoại khi tạo User
-- (Hệ thống sẽ tự động gán ID: 1 cho Admin, 2 cho Lecturer, 3 cho Student)
INSERT INTO Role (role_name) VALUES ('Admin');
INSERT INTO Role (role_name) VALUES ('Lecturer');
INSERT INTO Role (role_name) VALUES ('Student');