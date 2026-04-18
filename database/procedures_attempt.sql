DELIMITER //

DROP PROCEDURE IF EXISTS sp_StartAttempt//

CREATE PROCEDURE sp_StartAttempt(
    IN p_test_id INT,
    IN p_student_id INT
)
BEGIN
    DECLARE v_attempt_index INT DEFAULT 1;
    DECLARE v_current_attempts INT DEFAULT 0;
    DECLARE v_test_timer INT;
    DECLARE v_max_attempts INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLER)
    -- ==========================================
    -- Bắt các ngoại lệ SQL chung và cắt chuỗi an toàn để tránh lỗi 'Data too long'
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- ==========================================
    -- 2. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;

    -- Ràng buộc dữ liệu: Đảm bảo các tham số định danh không bị rỗng
    IF p_test_id IS NULL OR p_student_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Test ID và Student ID không được để trống!';
    END IF;

    -- Bước 2.1: Truy xuất thông số cấu hình của bài kiểm tra (Thời gian, Giới hạn lượt thi)
    SELECT test_timer, max_attempts INTO v_test_timer, v_max_attempts 
    FROM Test 
    WHERE test_id = p_test_id;

    -- Ràng buộc toàn vẹn: Đảm bảo bài kiểm tra thực sự tồn tại
    IF v_test_timer IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bài kiểm tra không tồn tại!';
    END IF;

    -- Bước 2.2: Ngăn chặn Race Condition (Chống mở nhiều tab thi cùng lúc)
    -- Sử dụng Row-level Lock (FOR UPDATE) để đảm bảo tính độc quyền của giao dịch
    IF EXISTS (
        SELECT 1 FROM Attempt 
        WHERE test_id = p_test_id AND student_id = p_student_id AND end_time IS NULL 
        FOR UPDATE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bạn đang có một lượt làm bài chưa kết thúc!';
    END IF;

    -- Bước 2.3: Thống kê số lượt thi hiện tại của sinh viên trong hệ thống
    SELECT COALESCE(MAX(attempt_index), 0) INTO v_current_attempts
    FROM Attempt
    WHERE test_id = p_test_id AND student_id = p_student_id;

    -- Bước 2.4: Ràng buộc nghiệp vụ - Kiểm soát số lần làm bài tối đa (Max Attempts)
    IF v_max_attempts IS NOT NULL AND v_current_attempts >= v_max_attempts THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bạn đã sử dụng hết số lượt làm bài cho phép!';
    END IF;

    -- Bước 2.5: Khởi tạo lượt làm bài mới (Tự động tăng Attempt Index)
    SET v_attempt_index = v_current_attempts + 1;

    INSERT INTO Attempt (attempt_index, timer, test_id, student_id, score)
    VALUES (v_attempt_index, v_test_timer, p_test_id, p_student_id, 0);

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_SubmitAnswer//

CREATE PROCEDURE sp_SubmitAnswer(
    IN p_attempt_id INT,
    IN p_question_id INT,
    IN p_choice_id INT
)
BEGIN
    DECLARE v_end_time DATETIME;
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
    -- 2. THỰC THI GIAO DỊCH (TRANSACTION)
    -- ==========================================
    START TRANSACTION;

    -- Bước 2.1: Chuẩn hóa và kiểm tra dữ liệu đầu vào (Validation)
    IF p_attempt_id IS NULL OR p_question_id IS NULL OR p_choice_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Dữ liệu truyền vào không được để trống!';
    END IF;

    -- Bước 2.2: Ràng buộc trạng thái bài thi (Row-level Lock)
    -- Khóa dòng dữ liệu Attempt để kiểm tra, ngăn chặn hành vi gian lận hoặc nộp trễ
    SELECT end_time INTO v_end_time
    FROM Attempt 
    WHERE attempt_id = p_attempt_id
    FOR UPDATE;

    IF v_end_time IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Bài thi này đã được nộp hoặc kết thúc, không thể lưu thêm đáp án!';
    END IF;

    -- (Ghi chú kiến trúc: Logic kiểm tra timeout dựa trên start_time + timer có thể được 
    -- bổ sung ở đây nếu bảng Attempt có cột start_time. Hiện tại chặn dựa trên end_time).

    -- Bước 2.3: Xử lý logic UPSERT (Thêm mới hoặc Cập nhật)
    -- Dùng FOR UPDATE để khóa câu trả lời hiện tại, chống xung đột ghi (Write Conflict)
    IF EXISTS (
        SELECT 1 FROM Student_answer 
        WHERE attempt_id = p_attempt_id AND question_id = p_question_id 
        FOR UPDATE
    ) THEN
        -- Xử lý trường hợp sinh viên thay đổi đáp án
        UPDATE Student_answer 
        SET choice_id = p_choice_id
        WHERE attempt_id = p_attempt_id AND question_id = p_question_id;
    ELSE
        -- Xử lý trường hợp sinh viên chọn đáp án lần đầu tiên
        INSERT INTO Student_answer (attempt_id, question_id, choice_id)
        VALUES (p_attempt_id, p_question_id, p_choice_id);
    END IF;

    COMMIT;
END //

DELIMITER ;