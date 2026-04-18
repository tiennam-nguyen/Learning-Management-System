-- ==========================================
-- SCRIPT CRUD NHÓM 2: QUẢN LÝ BÀI KIỂM TRA (TEST)
-- ==========================================

DELIMITER //

-- ==========================================
-- 1. THÊM BÀI KIỂM TRA MỚI (Create Test)
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
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLERS)
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
    
    -- Bước 2.1: Chuẩn hóa dữ liệu đầu vào (Input Sanitization)
    SET p_test_name = TRIM(p_test_name);
    IF p_test_name = '' OR p_class_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tên bài kiểm tra và Class ID không được để trống!';
    END IF;

    -- Bước 2.2: Ràng buộc logic thời gian (Time Constraint Validation)
    IF p_test_start IS NOT NULL AND p_test_end IS NOT NULL THEN
        IF p_test_start >= p_test_end THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Thời gian bắt đầu phải diễn ra trước thời gian kết thúc!';
        END IF;
    END IF;

    IF p_test_timer <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Thời gian làm bài (timer) phải lớn hơn 0!';
    END IF;

    -- Bước 2.3: Ràng buộc Toàn vẹn Tham chiếu (Foreign Key Constraint)
    IF NOT EXISTS (SELECT 1 FROM Class WHERE class_id = p_class_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    INSERT INTO Test (test_name, test_start, test_end, test_timer, class_id, chapter_id)
    VALUES (p_test_name, p_test_start, p_test_end, p_test_timer, p_class_id, p_chapter_id);

    COMMIT;
END //

-- ==========================================
-- 2. CẬP NHẬT BÀI KIỂM TRA (Update Test)
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

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLERS)
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
    
    -- Bước 2.1: Ràng buộc Tồn tại (Existence Check)
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- Bước 2.2: Chuẩn hóa và xác thực ràng buộc thời gian (Time Logic Validation)
    SET p_test_name = TRIM(p_test_name);
    IF p_test_name = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tên bài kiểm tra không được để trống!';
    END IF;

    IF p_test_start IS NOT NULL AND p_test_end IS NOT NULL THEN
        IF p_test_start >= p_test_end THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Thời gian bắt đầu phải diễn ra trước thời gian kết thúc!';
        END IF;
    END IF;

    -- Bước 2.3: Ràng buộc Nghiệp vụ (Business Rule) - Chặn cập nhật cấu hình khi đang có giao dịch thi diễn ra
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = p_test_id AND end_time IS NULL) THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Đang có sinh viên làm bài, không thể thay đổi thông số đề thi!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
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
-- 3. XÓA BÀI KIỂM TRA (Delete Test)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_DeleteTest//

CREATE PROCEDURE sp_DeleteTest(
    IN p_test_id INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLERS)
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
    
    -- Bước 2.1: Ràng buộc Tồn tại (Existence Check)
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- Bước 2.2: Ràng buộc Nghiệp vụ và Lịch sử (Audit Trail / Business Rule)
    -- Chặn thao tác xóa (Hard Delete) nếu đã phát sinh dữ liệu lượt thi nhằm bảo vệ tính toàn vẹn của điểm số
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi Không Thể Xóa: Bài kiểm tra này đã có sinh viên làm bài. Để bảo vệ dữ liệu điểm, từ chối lệnh xóa!';
    END IF;

    -- ==========================================
    -- 3. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;
    
    DELETE FROM Test WHERE test_id = p_test_id;

    COMMIT;
END //

DELIMITER ;