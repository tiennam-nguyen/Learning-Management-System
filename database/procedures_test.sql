-- ==========================================
-- TEST MANAGEMENT (QUẢN LÝ BÀI KIỂM TRA)
-- ==========================================

DELIMITER //

-- ==========================================
-- 1. CREATE TEST (TẠO BÀI KIỂM TRA)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateTest//

CREATE PROCEDURE sp_CreateTest(
    IN p_test_name VARCHAR(255),
    IN p_test_start DATETIME,
    IN p_test_end DATETIME,
    IN p_test_timer INT,
    IN p_class_id INT,
    IN p_chapter_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- ERROR HANDLER: rollback + trả lỗi ngắn gọn
    -- ==========================================
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- VALIDATION: dữ liệu đầu vào
    -- ==========================================
    
    -- Chuẩn hóa + check dữ liệu bắt buộc
    SET p_test_name = TRIM(p_test_name);
    IF p_test_name = '' OR p_class_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên bài kiểm tra và Class ID không được để trống!';
    END IF;

    -- VALIDATION: logic thời gian
    IF p_test_start IS NOT NULL AND p_test_end IS NOT NULL THEN
        IF p_test_start >= p_test_end THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Lỗi: Thời gian bắt đầu phải trước thời gian kết thúc!';
        END IF;
    END IF;

    -- VALIDATION: thời gian làm bài
    IF p_test_timer <= 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Timer phải lớn hơn 0!';
    END IF;

    -- VALIDATION: khóa ngoại (class)
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- ==========================================
    -- TRANSACTION: tạo bài kiểm tra
    -- ==========================================
    START TRANSACTION;
    
    INSERT INTO Test (test_name, test_start, test_end, test_timer, class_id, chapter_id)
    VALUES (p_test_name, p_test_start, p_test_end, p_test_timer, p_class_id, p_chapter_id);

    COMMIT;
END //

-- ==========================================
-- 2. UPDATE TEST (CẬP NHẬT BÀI KIỂM TRA)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_UpdateTest//

CREATE PROCEDURE sp_UpdateTest(
    IN p_test_id INT,
    IN p_test_name VARCHAR(255),
    IN p_test_start DATETIME,
    IN p_test_end DATETIME,
    IN p_test_timer INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
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
    
    -- Check tồn tại
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- Chuẩn hóa + check tên
    SET p_test_name = TRIM(p_test_name);
    IF p_test_name = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên bài kiểm tra không được để trống!';
    END IF;

    -- VALIDATION: logic thời gian
    IF p_test_start IS NOT NULL AND p_test_end IS NOT NULL THEN
        IF p_test_start >= p_test_end THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Lỗi: Thời gian bắt đầu phải trước thời gian kết thúc!';
        END IF;
    END IF;

    -- BUSINESS RULE: chặn update khi đang có attempt chưa kết thúc
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = p_test_id AND end_time IS NULL) THEN
         SIGNAL SQLSTATE '45000' 
         SET MESSAGE_TEXT = 'Lỗi: Đang có sinh viên làm bài, không thể thay đổi cấu hình!';
    END IF;

    -- ==========================================
    -- TRANSACTION: cập nhật bài kiểm tra
    -- ==========================================
    START TRANSACTION;
    
    UPDATE Test 
    SET 
        test_name = p_test_name,
        test_start = p_test_start,
        test_end = p_test_end,
        test_timer = p_test_timer
    WHERE test_id = p_test_id;

    COMMIT;
END //

-- ==========================================
-- 3. DELETE TEST (XÓA BÀI KIỂM TRA)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_DeleteTest//

CREATE PROCEDURE sp_DeleteTest(
    IN p_test_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
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
    
    -- Check tồn tại
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- BUSINESS RULE: không cho xóa nếu đã có attempt
    -- (bảo toàn dữ liệu điểm & lịch sử làm bài)
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra đã có dữ liệu làm bài, không thể xóa!';
    END IF;

    -- ==========================================
    -- SOFT DELETE
    -- ==========================================
    START TRANSACTION;
    
    UPDATE Test 
    SET is_deleted = TRUE 
    WHERE test_id = p_test_id;

    COMMIT;
END //

DELIMITER ;