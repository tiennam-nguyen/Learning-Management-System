-- ==========================================
-- QUESTION BANK (NGÂN HÀNG CÂU HỎI)
-- Bao gồm:
--   - Question: Câu hỏi trong bài kiểm tra
--   - Choice: Các lựa chọn/đáp án của câu hỏi
-- ==========================================

DELIMITER //

-- ==========================================
-- 6.1. QUESTION MANAGEMENT (QUẢN LÝ CÂU HỎI)
-- ==========================================

DROP PROCEDURE IF EXISTS sp_CreateQuestion//

CREATE PROCEDURE sp_CreateQuestion(
    IN p_test_id INT,
    IN p_question_type VARCHAR(50),
    IN p_question_content TEXT
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
    IF p_test_id IS NULL OR TRIM(p_question_content) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: ID Bài kiểm tra và nội dung câu hỏi không được trống!';
    END IF;

    -- VALIDATION: kiểm tra tồn tại test
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- BUSINESS RULE: khóa đề thi nếu đã có attempt
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = p_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Nghiệp vụ: Đề thi đã có người làm, không thể thêm câu hỏi!';
    END IF;

    -- ==========================================
    -- TRANSACTION: tạo câu hỏi
    -- ==========================================
    START TRANSACTION;

    INSERT INTO Question (test_id, question_type, question_content)
    VALUES (p_test_id, TRIM(p_question_type), TRIM(p_question_content));

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_UpdateQuestion//

CREATE PROCEDURE sp_UpdateQuestion(
    IN p_question_id INT,
    IN p_question_type VARCHAR(50),
    IN p_question_content TEXT
)
BEGIN
    DECLARE v_test_id INT;
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
    -- VALIDATION: nội dung câu hỏi
    -- ==========================================
    IF TRIM(p_question_content) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Nội dung câu hỏi không được để trống!';
    END IF;

    -- VALIDATION: tồn tại câu hỏi + lấy test_id
    SELECT test_id INTO v_test_id 
    FROM Question 
    WHERE question_id = p_question_id;

    IF v_test_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Câu hỏi không tồn tại!';
    END IF;

    -- BUSINESS RULE: không cho sửa nếu đã có attempt
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = v_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Nghiệp vụ: Đề thi đã sử dụng, không thể sửa câu hỏi!';
    END IF;

    -- ==========================================
    -- TRANSACTION: cập nhật câu hỏi
    -- ==========================================
    START TRANSACTION;

    UPDATE Question 
    SET question_type = TRIM(p_question_type),
        question_content = TRIM(p_question_content)
    WHERE question_id = p_question_id;

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_DeleteQuestion//

CREATE PROCEDURE sp_DeleteQuestion(
    IN p_question_id INT
)
BEGIN
    DECLARE v_test_id INT;
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
    -- VALIDATION: tồn tại + chưa bị xóa
    -- ==========================================
    SELECT test_id INTO v_test_id 
    FROM Question 
    WHERE question_id = p_question_id AND is_deleted = FALSE;

    IF v_test_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Câu hỏi không tồn tại hoặc đã bị xóa!';
    END IF;

    -- BUSINESS RULE: không cho xóa nếu đã có điểm
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = v_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi An toàn: Không thể xóa câu hỏi của bài thi đã có kết quả!';
    END IF;

    -- ==========================================
    -- SOFT DELETE
    -- ==========================================
    START TRANSACTION;

    UPDATE Question 
    SET is_deleted = TRUE 
    WHERE question_id = p_question_id;

    COMMIT;
END //


-- ==========================================
-- 6.2. CHOICE MANAGEMENT (QUẢN LÝ ĐÁP ÁN)
-- ==========================================

DROP PROCEDURE IF EXISTS sp_CreateChoice//

CREATE PROCEDURE sp_CreateChoice(
    IN p_question_id INT,
    IN p_choice_content TEXT,
    IN p_is_true BOOLEAN
)
BEGIN
    DECLARE v_test_id INT;
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
    -- VALIDATION: dữ liệu đầu vào
    -- ==========================================
    IF p_question_id IS NULL OR TRIM(p_choice_content) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Dữ liệu đáp án không hợp lệ!';
    END IF;

    -- VALIDATION: tồn tại question + lấy test_id
    SELECT test_id INTO v_test_id 
    FROM Question 
    WHERE question_id = p_question_id;

    IF v_test_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Câu hỏi không tồn tại!';
    END IF;

    -- BUSINESS RULE: khóa nếu đề đã có attempt
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = v_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Nghiệp vụ: Không thể thêm đáp án khi đề đang hoạt động!';
    END IF;

    -- ==========================================
    -- TRANSACTION: tạo đáp án
    -- ==========================================
    START TRANSACTION;

    INSERT INTO Choice (question_id, choice_content, is_true)
    VALUES (p_question_id, TRIM(p_choice_content), COALESCE(p_is_true, FALSE));

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_UpdateChoice//

CREATE PROCEDURE sp_UpdateChoice(
    IN p_choice_id INT,
    IN p_choice_content TEXT,
    IN p_is_true BOOLEAN
)
BEGIN
    DECLARE v_test_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- VALIDATION: nội dung
    IF TRIM(p_choice_content) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Nội dung đáp án không được để trống!';
    END IF;

    -- JOIN: lấy test_id từ Choice -> Question
    SELECT q.test_id INTO v_test_id 
    FROM Choice c
    JOIN Question q ON c.question_id = q.question_id
    WHERE c.choice_id = p_choice_id;

    IF v_test_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Đáp án không tồn tại!';
    END IF;

    -- BUSINESS RULE
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = v_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Nghiệp vụ: Không thể sửa đáp án của bài thi đã có điểm!';
    END IF;

    -- TRANSACTION
    START TRANSACTION;

    UPDATE Choice 
    SET choice_content = TRIM(p_choice_content),
        is_true = COALESCE(p_is_true, FALSE)
    WHERE choice_id = p_choice_id;

    COMMIT;
END //


DROP PROCEDURE IF EXISTS sp_DeleteChoice//

CREATE PROCEDURE sp_DeleteChoice(
    IN p_choice_id INT
)
BEGIN
    DECLARE v_test_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- JOIN: lấy test_id
    SELECT q.test_id INTO v_test_id 
    FROM Choice c
    JOIN Question q ON c.question_id = q.question_id
    WHERE c.choice_id = p_choice_id;

    IF v_test_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Đáp án không tồn tại!';
    END IF;

    -- BUSINESS RULE: cấm xóa nếu đã có lịch sử làm bài
    IF EXISTS (SELECT 1 FROM Attempt WHERE test_id = v_test_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi An toàn: Không thể xóa đáp án của bài thi đã có lịch sử!';
    END IF;

    -- ==========================================
    -- HARD DELETE (xóa vật lý)
    -- ==========================================
    START TRANSACTION;

    DELETE FROM Choice 
    WHERE choice_id = p_choice_id;

    COMMIT;
END //

DELIMITER ;