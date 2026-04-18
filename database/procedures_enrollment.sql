DELIMITER //

DROP PROCEDURE IF EXISTS sp_EnrollStudentInClass//

CREATE PROCEDURE sp_EnrollStudentInClass(
    IN p_student_id INT,
    IN p_class_id INT
)
BEGIN
    DECLARE v_status_display VARCHAR(50);
    DECLARE v_status_id INT;
    DECLARE v_error_msg VARCHAR(512);

    -- ==========================================
    -- 1. BỘ XỬ LÝ LỖI (ERROR HANDLERS)
    -- ==========================================
    
    -- Bắt lỗi vi phạm ràng buộc Toàn vẹn (Duplicate Entry - Mã 1062)
    -- Ngăn chặn hành vi đăng ký trùng lặp một học phần nhiều lần
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Sinh viên đã tham gia lớp này rồi!';
    END;

    -- Bắt các ngoại lệ SQL chung và cắt chuỗi an toàn để tránh lỗi tràn bộ đệm 'Data too long'
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

    -- Bước 2.1: Chuẩn hóa và kiểm tra dữ liệu đầu vào (Input Validation)
    IF p_student_id IS NULL OR p_class_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tham số đầu vào không được để trống!';
    END IF;

    -- Bước 2.2: Ràng buộc Toàn vẹn Tham chiếu (Referential Integrity) - Xác thực Sinh viên
    IF NOT EXISTS (SELECT 1 FROM Student WHERE id = p_student_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Sinh viên không tồn tại trong hệ thống!';
    END IF;

    -- Bước 2.3: Ràng buộc Tồn tại và Ngăn chặn Race Condition (FOR UPDATE)
    -- Tối ưu hóa hiệu suất (Lock Contention): Chỉ áp dụng Row-level Lock trên bảng Class
    SELECT status_id INTO v_status_id 
    FROM Class 
    WHERE class_id = p_class_id 
    FOR UPDATE;

    IF v_status_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học không tồn tại trong hệ thống!';
    END IF;

    -- Bước 2.4: Ràng buộc Nghiệp vụ (Business Rule) - Trạng thái hoạt động của lớp
    -- Truy xuất dữ liệu từ bảng danh mục Status (Không dùng Lock để tăng tốc độ truy vấn)
    SELECT status_display INTO v_status_display 
    FROM Status 
    WHERE status_id = v_status_id;

    IF LOWER(v_status_display) != 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Lớp học hiện không mở đăng ký!';
    END IF;

    -- Bước 2.5: Thực thi ghi nhận đăng ký học phần (Insert)
    -- Ghi chú kiến trúc: Việc kiểm tra trùng lặp (Zero-cost validation) được giao phó 
    -- hoàn toàn cho cấu trúc Handler 1062 phía trên, tối ưu chi phí so với việc dùng IF EXISTS.
    INSERT INTO Enrollment (student_id, class_id)
    VALUES (p_student_id, p_class_id);

    COMMIT;

END //

DELIMITER ;