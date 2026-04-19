-- ==========================================
-- QUẢN LÝ LỚP HỌC & ĐĂNG KÝ
-- ==========================================

DELIMITER //

-- ==========================================
-- THÊM LỚP HỌC MỚI (Create Class)
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
    DECLARE v_status_name VARCHAR(50); -- Lưu tên trạng thái (Active, Closed...)
    DECLARE v_error_msg VARCHAR(512);  -- Lưu thông báo lỗi hệ thống

    -- Handler cho lỗi SQL tổng quát (rollback toàn bộ transaction)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- VALIDATION
    -- ==========================================
    
    -- Chuẩn hóa input + kiểm tra bắt buộc
    SET p_class_name = TRIM(p_class_name);
    IF p_class_name = '' OR p_subject_id IS NULL OR p_semester_id IS NULL OR p_status_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên lớp, Môn học, Học kỳ và Trạng thái không được để trống!';
    END IF;

    -- Kiểm tra tồn tại các khóa ngoại (chủ động thay vì để DB ném lỗi)
    IF NOT EXISTS (SELECT 1 FROM Subject WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Môn học không tồn tại trong hệ thống!';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Semester WHERE semester_id = p_semester_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Học kỳ không tồn tại!';
    END IF;
    
    IF p_lecturer_id IS NOT NULL 
       AND NOT EXISTS (SELECT 1 FROM Lecturer WHERE id = p_lecturer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Giảng viên không tồn tại!';
    END IF;

    -- Chống tạo trùng lớp theo (class_name + subject + semester)
    IF EXISTS (
        SELECT 1 FROM Class 
        WHERE class_name = p_class_name 
          AND semester_id = p_semester_id 
          AND subject_id = p_subject_id
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên lớp học này đã tồn tại trong học kỳ hiện tại!';
    END IF;

    -- Lấy trạng thái để kiểm tra business rule
    SELECT status_display INTO v_status_name 
    FROM Status 
    WHERE status_id = p_status_id;

    IF v_status_name IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Trạng thái không hợp lệ!';
    END IF;
    
    -- Rule: Class = Active bắt buộc phải có Lecturer
    IF LOWER(v_status_name) = 'active' AND p_lecturer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Không thể mở lớp (Active) khi chưa phân công Giảng viên!';
    END IF;

    START TRANSACTION;
    
    -- Insert lớp học
    INSERT INTO Class (class_name, subject_id, semester_id, status_id, lecturer_id)
    VALUES (p_class_name, p_subject_id, p_semester_id, p_status_id, p_lecturer_id);

    COMMIT;
END //

-- ==========================================
-- CẬP NHẬT LỚP HỌC (Update Class)
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

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Kiểm tra tồn tại class
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- Lấy trạng thái để kiểm tra rule
    SELECT status_display INTO v_status_name 
    FROM Status 
    WHERE status_id = p_status_id;
    
    -- Rule: Không được set Active nếu chưa có Lecturer
    IF LOWER(v_status_name) = 'active' AND p_lecturer_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Không thể chuyển trạng thái lớp sang Active khi chưa có Giảng viên!';
    END IF;

    START TRANSACTION;
    
    -- Update toàn bộ thông tin class
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
-- XÓA LỚP HỌC (Soft Delete Class)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_DeleteClass//

CREATE PROCEDURE sp_DeleteClass(
    IN p_class_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Kiểm tra tồn tại class
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- Chặn xóa nếu đã có sinh viên đăng ký
    IF EXISTS (SELECT 1 FROM Enrollment WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Không thể xóa! Lớp học này đang có sinh viên đăng ký. Vui lòng chuyển trạng thái lớp sang Closed (Đã đóng).';
    END IF;

    -- Chặn xóa nếu đã có dữ liệu test (bảo vệ dữ liệu nghiệp vụ)
    IF EXISTS (SELECT 1 FROM Test WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Không thể xóa! Lớp học này đã có dữ liệu bài kiểm tra. Hãy xóa bài kiểm tra trước hoặc đóng lớp.';
    END IF;

    START TRANSACTION;
    
    -- Soft delete bằng cờ is_deleted (không xóa vật lý)
    UPDATE Class 
    SET is_deleted = TRUE 
    WHERE class_id = p_class_id;

    COMMIT;
END //

-- ==========================================
-- HỦY ĐĂNG KÝ HỌC PHẦN (Remove Student)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_RemoveStudentFromClass//

CREATE PROCEDURE sp_RemoveStudentFromClass(
    IN p_class_id INT,
    IN p_student_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Kiểm tra student có đăng ký lớp hay không
    IF NOT EXISTS (
        SELECT 1 
        FROM Enrollment 
        WHERE class_id = p_class_id 
          AND student_id = p_student_id
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Sinh viên không có trong danh sách lớp này!';
    END IF;

    -- Chặn xóa nếu đã có dữ liệu làm bài (bảo toàn lịch sử)
    IF EXISTS (
        SELECT 1 
        FROM Attempt a
        JOIN Test t ON a.test_id = t.test_id
        WHERE t.class_id = p_class_id 
          AND a.student_id = p_student_id
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Không thể xóa! Sinh viên này đã có dữ liệu làm bài kiểm tra trong lớp. Chỉ có thể khóa tài khoản hoặc đổi trạng thái môn học.';
    END IF;

    START TRANSACTION;
    
    -- Xóa đăng ký học phần
    DELETE FROM Enrollment 
    WHERE class_id = p_class_id 
      AND student_id = p_student_id;

    COMMIT;
END //

DELIMITER ;