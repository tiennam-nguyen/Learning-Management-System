DELIMITER //

DROP PROCEDURE IF EXISTS sp_EnrollStudentInClass//

CREATE PROCEDURE sp_EnrollStudentInClass(
    IN p_student_id INT,
    IN p_class_id INT
)
BEGIN
    DECLARE v_status_display VARCHAR(50); -- Tên trạng thái lớp (Active, Closed, ...)
    DECLARE v_status_id INT;              -- ID trạng thái lớp
    DECLARE v_error_msg VARCHAR(512);     -- Biến lưu message lỗi hệ thống

    -- ==========================================
    -- ERROR HANDLER
    -- ==========================================
    
    -- Duplicate key (1062): đã đăng ký trước đó
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Sinh viên đã tham gia lớp này rồi!';
    END;

    -- SQL exception chung: rollback + truncate message
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- TRANSACTION
    -- ==========================================
    START TRANSACTION;

    -- ==========================================
    -- VALIDATION: dữ liệu đầu vào
    -- ==========================================
    IF p_student_id IS NULL OR p_class_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tham số đầu vào không hợp lệ!';
    END IF;

    -- VALIDATION: tồn tại student
    IF NOT EXISTS (
        SELECT 1 
        FROM Student 
        WHERE id = p_student_id
    ) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Sinh viên không tồn tại!';
    END IF;

    -- ==========================================
    -- LOCK + VALIDATION: lấy trạng thái lớp
    -- ==========================================
    -- FOR UPDATE: tránh race condition khi nhiều user đăng ký cùng lúc
    SELECT status_id 
    INTO v_status_id 
    FROM Class 
    WHERE class_id = p_class_id 
    FOR UPDATE;

    IF v_status_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- ==========================================
    -- BUSINESS RULE: kiểm tra trạng thái lớp
    -- ==========================================
    -- Status là bảng danh mục → không cần lock
    SELECT status_display 
    INTO v_status_display 
    FROM Status 
    WHERE status_id = v_status_id;

    IF LOWER(v_status_display) != 'active' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Lớp học hiện không mở đăng ký!';
    END IF;

    -- ==========================================
    -- INSERT: ghi nhận đăng ký
    -- ==========================================
    -- Không cần check EXISTS → rely vào UNIQUE/PK + handler 1062
    INSERT INTO Enrollment (student_id, class_id)
    VALUES (p_student_id, p_class_id);

    COMMIT;

END //

DELIMITER ;