
DELIMITER //

-- =====================================================================================
-- TRIGGER: trg_AutoAttemptIndex_Insert
-- MÔ TẢ:   Tự động tính toán và gán số thứ tự lượt làm bài (attempt_index) cho sinh viên.
-- SỰ KIỆN: BEFORE INSERT trên bảng `Attempt`
-- XỬ LÝ:   1. Tìm lượt thi cao nhất hiện tại của sinh viên trong bài Test đó.
--          2. Nếu chưa thi, gán mặc định là 1. Nếu đã thi, cộng thêm 1 vào lượt thi cũ.
-- =====================================================================================
DROP TRIGGER IF EXISTS trg_AutoAttemptIndex_Insert//

CREATE TRIGGER trg_AutoAttemptIndex_Insert
BEFORE INSERT ON Attempt
FOR EACH ROW
BEGIN
    DECLARE v_next_index INT;
    
    -- [TÍNH TOÁN]: Tìm attempt_index lớn nhất. Dùng COALESCE để xử lý an toàn trường hợp NULL (chưa thi lần nào)
    SELECT COALESCE(MAX(attempt_index), 0) + 1 INTO v_next_index
    FROM Attempt
    WHERE test_id = NEW.test_id AND student_id = NEW.student_id;
    
    -- [CẬP NHẬT]: Gán giá trị vừa tính toán vào bản ghi chuẩn bị được Insert xuống Database
    SET NEW.attempt_index = v_next_index;
END//


-- =====================================================================================
-- TRIGGER: trg_AutoCalcTimer_Update
-- MÔ TẢ:   Tự động tính thời gian làm bài thực tế của sinh viên (tính bằng giây).
-- SỰ KIỆN: BEFORE UPDATE trên bảng `Attempt`
-- XỬ LÝ:   1. Phát hiện khoảnh khắc "Nộp bài" (end_time chuyển từ NULL sang có giá trị).
--          2. Tính toán khoảng thời gian từ lúc bắt đầu (start_time) đến lúc kết thúc (end_time).
-- =====================================================================================
DROP TRIGGER IF EXISTS trg_AutoCalcTimer_Update//

CREATE TRIGGER trg_AutoCalcTimer_Update
BEFORE UPDATE ON Attempt
FOR EACH ROW
BEGIN
    -- [KIỂM TRA]: Đảm bảo chỉ tính toán đúng một lần vào khoảnh khắc nộp bài 
    -- (Tránh tình trạng update nhầm nếu có lệnh UPDATE khác tác động lên bảng Attempt)
    IF NEW.end_time IS NOT NULL AND OLD.end_time IS NULL THEN
        
        -- [TÍNH TOÁN]: Lấy độ lệch thời gian bằng giây (SECOND) và gán tự động vào cột timer
        SET NEW.timer = TIMESTAMPDIFF(SECOND, NEW.start_time, NEW.end_time);
        
    END IF;
END//

DELIMITER ;