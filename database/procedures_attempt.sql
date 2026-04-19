DELIMITER //

DROP PROCEDURE IF EXISTS sp_StartAttempt//
CREATE PROCEDURE sp_StartAttempt(
    IN p_test_id INT,
    IN p_student_id INT,
    OUT p_new_attempt_id INT
)
BEGIN
    DECLARE v_test_timer INT;
    DECLARE v_max_attempts INT;
    DECLARE v_current_attempts INT;
    DECLARE v_error_msg VARCHAR(512);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    IF p_test_id IS NULL OR p_student_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Test ID và Student ID không được để trống!';
    END IF;

    START TRANSACTION;

    -- Lấy cấu hình bài thi
    SELECT test_timer, max_attempts INTO v_test_timer, v_max_attempts 
    FROM Test WHERE test_id = p_test_id AND is_deleted = FALSE;

    IF v_test_timer IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- Chặn mở tab thi thứ 2 khi tab 1 chưa nộp
    IF EXISTS (
        SELECT 1 FROM Attempt 
        WHERE test_id = p_test_id AND student_id = p_student_id AND end_time IS NULL 
        FOR UPDATE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bạn đang có một lượt làm bài chưa kết thúc!';
    END IF;

    -- Đếm số lượt đã thi để chặn nếu vượt quá max_attempts
    SELECT COUNT(*) INTO v_current_attempts
    FROM Attempt WHERE test_id = p_test_id AND student_id = p_student_id;

    IF v_max_attempts IS NOT NULL AND v_current_attempts >= v_max_attempts THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Đã hết lượt làm bài!';
    END IF;

    -- Thực hiện Insert. KHÔNG CẦN truyền attempt_index nữa, Trigger sẽ tự lo!
    INSERT INTO Attempt (timer, test_id, student_id, score)
    VALUES (v_test_timer, p_test_id, p_student_id, 0);

    SET p_new_attempt_id = LAST_INSERT_ID();

    COMMIT;
END //
DROP PROCEDURE IF EXISTS sp_SubmitAnswer//
CREATE PROCEDURE sp_SubmitAnswer(
    IN p_attempt_id INT,
    IN p_question_id INT,
    IN p_choice_id INT
)
BEGIN
    DECLARE v_end_time DATETIME; -- Thời điểm kết thúc attempt
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Validate input
    IF p_attempt_id IS NULL OR p_question_id IS NULL OR p_choice_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Thiếu tham số!';
    END IF;

    START TRANSACTION;

    -- Lock attempt để đảm bảo không bị submit đồng thời
    SELECT end_time 
    INTO v_end_time 
    FROM Attempt 
    WHERE attempt_id = p_attempt_id 
    FOR UPDATE;

    -- Không cho ghi đáp án nếu đã submit bài
    IF v_end_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài thi đã nộp, không thể lưu đáp án!';
    END IF;

    -- UPSERT đáp án (tránh duplicate + hạn chế deadlock)
    INSERT INTO Student_answer (attempt_id, question_id, choice_id)
    VALUES (p_attempt_id, p_question_id, p_choice_id)
    ON DUPLICATE KEY UPDATE choice_id = p_choice_id;

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_SubmitTest//

CREATE PROCEDURE sp_SubmitTest(
    IN p_attempt_id INT
)
BEGIN
    DECLARE v_end_time DATETIME; -- Thời điểm đã submit hay chưa
    DECLARE v_total_q INT;       -- Tổng số câu hỏi
    DECLARE v_correct INT;       -- Số câu trả lời đúng
    DECLARE v_test_id INT;       -- Test tương ứng với attempt
    DECLARE v_error_msg VARCHAR(512);

    -- Handler lỗi SQL
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    START TRANSACTION;

    -- Lock attempt để tránh submit nhiều lần
    SELECT end_time, test_id 
    INTO v_end_time, v_test_id 
    FROM Attempt 
    WHERE attempt_id = p_attempt_id 
    FOR UPDATE;

    -- Chặn submit lại
    IF v_end_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Lượt thi này đã nộp trước đó!';
    END IF;

    -- Đếm tổng số câu hỏi hợp lệ của test
    SELECT COUNT(*) 
    INTO v_total_q 
    FROM Question 
    WHERE test_id = v_test_id 
      AND is_deleted = FALSE;
    
    IF v_total_q > 0 THEN
        -- Đếm số câu đúng dựa trên choice.is_true
        SELECT COUNT(*) 
        INTO v_correct
        FROM Student_answer sa
        JOIN Choice c ON sa.choice_id = c.choice_id
        WHERE sa.attempt_id = p_attempt_id 
          AND c.is_true = TRUE;

        -- Chốt bài: cập nhật thời gian nộp và tính điểm (scale 10)
        UPDATE Attempt 
        SET 
            end_time = NOW(), 
            score = (v_correct / v_total_q) * 10
        WHERE attempt_id = p_attempt_id;
    ELSE
        -- Trường hợp test không có câu hỏi
        UPDATE Attempt 
        SET end_time = NOW(), score = 0 
        WHERE attempt_id = p_attempt_id;
    END IF;

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_BulkSubmitAnswers//
CREATE PROCEDURE sp_BulkSubmitAnswers(
    IN p_attempt_id INT,
    IN p_json_answers JSON
)
BEGIN
    DECLARE v_end_time DATETIME; -- Kiểm tra trạng thái attempt
    
    START TRANSACTION;

    -- Lock attempt để đảm bảo chưa submit
    SELECT end_time 
    INTO v_end_time 
    FROM Attempt 
    WHERE attempt_id = p_attempt_id 
    FOR UPDATE;

    IF v_end_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Bài thi đã kết thúc!';
    END IF;

    -- Parse JSON array và insert/update hàng loạt (batch UPSERT)
    INSERT INTO Student_answer (attempt_id, question_id, choice_id)
    SELECT 
        p_attempt_id, 
        j.question_id, 
        j.choice_id
    FROM JSON_TABLE(p_json_answers, '$[*]' COLUMNS (
        question_id INT PATH '$.question_id',
        choice_id INT PATH '$.choice_id'
    )) AS j
    ON DUPLICATE KEY UPDATE choice_id = j.choice_id;

    COMMIT;
END //

DELIMITER ;