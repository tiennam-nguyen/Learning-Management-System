-- ==========================================
-- SCRIPT CRUD NHÓM 3: QUẢN LÝ LỚP HỌC & ĐĂNG KÝ
-- ==========================================

DELIMITER //

-- ==========================================
-- 1. THÊM LỚP HỌC MỚI (Create Class)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateClass//

CREATE PROCEDURE sp_CreateClass(
    IN p_class_name VARCHAR(100),
    IN p_subject_id INT,
    IN p_semester_id INT,
    IN p_status_id INT,
    IN p_lecturer_id INT
)
BEGIN
    DECLARE v_status_name VARCHAR(50);
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. CHUẨN HÓA VÀ KIỂM TRA DỮ LIỆU (VALIDATION)
    -- ==========================================
    
    -- Bước 2.1: Chuẩn hóa và kiểm tra dữ liệu đầu vào (Input Validation)
    SET p_class_name = TRIM(p_class_name);
    IF p_class_name = '' OR p_subject_id IS NULL OR p_semester_id IS NULL OR p_status_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tên lớp, Môn học, Học kỳ và Trạng thái không được để trống!';
    END IF;

    -- Bước 2.2: Ràng buộc Khóa ngoại (Foreign Key Constraints) - Kiểm tra chủ động
    IF NOT EXISTS (SELECT 1 FROM Subject WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Môn học không tồn tại trong hệ thống!';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Semester WHERE semester_id = p_semester_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Học kỳ không tồn tại!';
    END IF;
    
    IF p_lecturer_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Lecturer WHERE id = p_lecturer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giảng viên không tồn tại!';
    END IF;

    -- Bước 2.3: Ràng buộc Toàn vẹn (Unique Constraint) - Chống trùng lặp dữ liệu lớp học
    IF EXISTS (
        SELECT 1 FROM Class 
        WHERE class_name = p_class_name AND semester_id = p_semester_id AND subject_id = p_subject_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tên lớp học này đã tồn tại trong học kỳ hiện tại!';
    END IF;

    -- Bước 2.4: Ràng buộc Nghiệp vụ (Business Rule) - Điều kiện mở lớp (Active)
    SELECT status_display INTO v_status_name FROM Status WHERE status_id = p_status_id;
    IF v_status_name IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Trạng thái không hợp lệ!';
    END IF;
    
    IF LOWER(v_status_name) = 'active' AND p_lecturer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Không thể mở lớp (Active) khi chưa phân công Giảng viên!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Bước 3.1: Lưu thông tin khởi tạo Lớp học vào cơ sở dữ liệu
    INSERT INTO Class (class_name, subject_id, semester_id, status_id, lecturer_id)
    VALUES (p_class_name, p_subject_id, p_semester_id, p_status_id, p_lecturer_id);

    COMMIT;
END //

-- ==========================================
-- 2. CẬP NHẬT LỚP HỌC (Update Class)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_UpdateClass//

CREATE PROCEDURE sp_UpdateClass(
    IN p_class_id INT,
    IN p_class_name VARCHAR(100),
    IN p_subject_id INT,
    IN p_semester_id INT,
    IN p_status_id INT,
    IN p_lecturer_id INT
)
BEGIN
    DECLARE v_status_name VARCHAR(50);
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA RÀNG BUỘC (VALIDATION)
    -- ==========================================
    
    -- Bước 2.1: Kiểm tra tính tồn tại của thực thể
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- Bước 2.2: Ràng buộc Nghiệp vụ (Business Rule) - Yêu cầu Giảng viên cho lớp Active
    SELECT status_display INTO v_status_name FROM Status WHERE status_id = p_status_id;
    
    IF LOWER(v_status_name) = 'active' AND p_lecturer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Không thể chuyển trạng thái lớp sang Active khi chưa có Giảng viên!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Bước 3.1: Cập nhật thông tin Lớp học
    UPDATE Class 
    SET 
        class_name = p_class_name,
        subject_id = p_subject_id,
        semester_id = p_semester_id,
        status_id = p_status_id,
        lecturer_id = p_lecturer_id
    WHERE class_id = p_class_id;

    COMMIT;
END //

-- ==========================================
-- 3. XÓA LỚP HỌC (Delete Class)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_DeleteClass//

CREATE PROCEDURE sp_DeleteClass(
    IN p_class_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA RÀNG BUỘC (VALIDATION)
    -- ==========================================
    
    -- Bước 2.1: Ràng buộc Tồn tại
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- Bước 2.2: Ràng buộc Toàn vẹn Tham chiếu (Referential Integrity) - Chặn xóa khi có sinh viên đăng ký
    IF EXISTS (SELECT 1 FROM Enrollment WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Không thể xóa! Lớp học này đang có sinh viên đăng ký. Vui lòng chuyển trạng thái lớp sang Closed (Đã đóng).';
    END IF;

    -- Bước 2.3: Ràng buộc Nghiệp vụ (Business Rule) - Chặn xóa khi đã phát sinh dữ liệu bài thi
    IF EXISTS (SELECT 1 FROM Test WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Không thể xóa! Lớp học này đã có dữ liệu bài kiểm tra. Hãy xóa bài kiểm tra trước hoặc đóng lớp.';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Bước 3.1: Thực thi lệnh xóa (Hard Delete) an toàn
    DELETE FROM Class WHERE class_id = p_class_id;

    COMMIT;
END //


-- ==========================================
-- 4. HỦY ĐĂNG KÝ HỌC PHẦN (Remove Student)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_RemoveStudentFromClass//

CREATE PROCEDURE sp_RemoveStudentFromClass(
    IN p_class_id INT,
    IN p_student_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. KIỂM TRA RÀNG BUỘC (VALIDATION)
    -- ==========================================
    
    -- Bước 2.1: Ràng buộc Tồn tại - Xác thực thông tin đăng ký học phần
    IF NOT EXISTS (SELECT 1 FROM Enrollment WHERE class_id = p_class_id AND student_id = p_student_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Sinh viên không có trong danh sách lớp này!';
    END IF;

    -- Bước 2.2: Ràng buộc Nghiệp vụ (Business Rule) - Bảo vệ dữ liệu lịch sử làm bài (Audit Trail)
    -- Thực hiện phép kết nối (JOIN) để rà soát dữ liệu điểm số liên đới
    IF EXISTS (
        SELECT 1 
        FROM Attempt a
        JOIN Test t ON a.test_id = t.test_id
        WHERE t.class_id = p_class_id AND a.student_id = p_student_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Không thể xóa! Sinh viên này đã có dữ liệu làm bài kiểm tra trong lớp. Chỉ có thể khóa tài khoản hoặc đổi trạng thái môn học.';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    -- Bước 3.1: Hủy bỏ đăng ký học phần của sinh viên
    DELETE FROM Enrollment 
    WHERE class_id = p_class_id AND student_id = p_student_id;

    COMMIT;
END //

DELIMITER ;