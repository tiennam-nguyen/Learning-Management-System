-- ==========================================
-- DANH MỤC CƠ SỞ (BASE CATALOGS)
-- Bao gồm: Faculty (Khoa), Subject (Môn học), Semester (Học kỳ)
-- ==========================================

DELIMITER //

-- ==========================================
-- QUẢN LÝ KHOA (FACULTY)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateFaculty//
CREATE PROCEDURE sp_CreateFaculty(IN p_faculty_name VARCHAR(100))
BEGIN
    DECLARE v_error_msg VARCHAR(512); -- Lưu thông báo lỗi hệ thống

    -- Handler lỗi SQL tổng quát (rollback toàn bộ transaction)
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET v_error_msg = SUBSTRING(v_error_msg, 1, 128);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END;

    -- Chuẩn hóa và validate input
    SET p_faculty_name = TRIM(p_faculty_name);
    IF p_faculty_name = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên Khoa không được để trống!';
    END IF;

    START TRANSACTION;

    -- Tạo mới Faculty
    INSERT INTO Faculty (faculty_name) 
    VALUES (p_faculty_name);

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_DeleteFaculty//
CREATE PROCEDURE sp_DeleteFaculty(IN p_faculty_id INT)
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

    -- Chặn xóa nếu còn Subject phụ thuộc (bảo toàn referential integrity)
    IF EXISTS (SELECT 1 FROM Subject WHERE faculty_id = p_faculty_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Toàn vẹn: Không thể xóa Khoa đang có Môn học trực thuộc!';
    END IF;

    START TRANSACTION;

    -- Xóa vật lý Faculty
    DELETE FROM Faculty 
    WHERE faculty_id = p_faculty_id;

    COMMIT;
END //

-- ==========================================
-- QUẢN LÝ MÔN HỌC (SUBJECT)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateSubject//
CREATE PROCEDURE sp_CreateSubject(
    IN p_subject_name VARCHAR(100),
    IN p_faculty_id INT
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

    -- Chuẩn hóa + validate input
    SET p_subject_name = TRIM(p_subject_name);

    IF p_subject_name = '' OR p_faculty_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Tên môn học và ID Khoa không được để trống!';
    END IF;

    -- Kiểm tra tồn tại Faculty (tránh lỗi FK runtime)
    IF NOT EXISTS (SELECT 1 FROM Faculty WHERE faculty_id = p_faculty_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Khoa không tồn tại trong hệ thống!';
    END IF;

    START TRANSACTION;

    -- Tạo mới Subject
    INSERT INTO Subject (subject_name, faculty_id) 
    VALUES (p_subject_name, p_faculty_id);

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_DeleteSubject//
CREATE PROCEDURE sp_DeleteSubject(IN p_subject_id INT)
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

    -- Chặn xóa nếu Subject đã được sử dụng trong Class
    IF EXISTS (SELECT 1 FROM Class WHERE subject_id = p_subject_id) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Toàn vẹn: Không thể xóa Môn học đã được mở Lớp!';
    END IF;

    START TRANSACTION;

    -- Xóa vật lý Subject
    DELETE FROM Subject 
    WHERE subject_id = p_subject_id;

    COMMIT;
END //

-- ==========================================
-- QUẢN LÝ HỌC KỲ (SEMESTER)
-- ==========================================
DROP PROCEDURE IF EXISTS sp_CreateSemester//
CREATE PROCEDURE sp_CreateSemester(
    IN p_semester_start DATE,
    IN p_semester_end DATE
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

    -- Validate input ngày tháng
    IF p_semester_start IS NULL OR p_semester_end IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi: Ngày bắt đầu và kết thúc không được để trống!';
    END IF;

    -- Rule: start < end (đã có CHECK constraint nhưng validate sớm để trả message rõ ràng)
    IF p_semester_start >= p_semester_end THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Lỗi Ràng buộc: Ngày bắt đầu học kỳ phải diễn ra trước ngày kết thúc!';
    END IF;

    START TRANSACTION;

    -- Tạo mới Semester
    INSERT INTO Semester (semester_start, semester_end) 
    VALUES (p_semester_start, p_semester_end);

    COMMIT;
END //

DELIMITER ;