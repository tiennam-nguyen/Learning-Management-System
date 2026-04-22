USE elearning;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_GetStudentsByClass //
CREATE PROCEDURE sp_GetStudentsByClass(
    IN p_class_name_keyword VARCHAR(100)
)
BEGIN
    -- Truy vấn kết hợp từ 4 bảng, có WHERE (sử dụng LIKE) và ORDER BY
    SELECT 
        u.id AS UserID,
        s.s_mssv AS MSSV,
        CONCAT(u.lastName, ' ', COALESCE(u.middleName, ''), ' ', u.firstName) AS FullName,
        u.email AS Email,
        c.class_name AS ClassName
    FROM User u
    JOIN Student s ON u.id = s.id
    JOIN Enrollment e ON s.id = e.student_id
    JOIN Class c ON e.class_id = c.class_id
    WHERE c.class_name LIKE CONCAT('%', p_class_name_keyword, '%')
    ORDER BY u.lastName ASC, u.firstName ASC;
END //

DELIMITER ;

-- Tìm tất cả sinh viên học các lớp có chữ 'DB' (Ví dụ: DB-2025-01)
CALL elearning.sp_GetStudentsByClass('DB');

-- Tìm sinh viên học các lớp có chữ '2025'
CALL elearning.sp_GetStudentsByClass('2025');

DELIMITER //

DROP PROCEDURE IF EXISTS sp_GetStudentTestStatsByClass //
CREATE PROCEDURE sp_GetStudentTestStatsByClass(
    IN p_class_id INT,
    IN p_min_avg_score DECIMAL(7,2)
)
BEGIN
    -- Truy vấn kết hợp 4 bảng, có Aggregate Function, GROUP BY, HAVING, WHERE, ORDER BY
    SELECT 
        u.id AS UserID,
        s.s_mssv AS MSSV,
        CONCAT(u.lastName, ' ', COALESCE(u.middleName, ''), ' ', u.firstName) AS FullName,
        COUNT(a.attempt_id) AS TotalAttempts,
        SUM(a.timer) AS TotalTimeSeconds,
        AVG(a.score) AS AverageScore
    FROM User u
    JOIN Student s ON u.id = s.id
    JOIN Attempt a ON s.id = a.student_id
    JOIN Test t ON a.test_id = t.test_id
    WHERE t.class_id = p_class_id
    GROUP BY u.id, s.s_mssv, u.lastName, u.middleName, u.firstName
    HAVING AVG(a.score) >= p_min_avg_score
    ORDER BY AverageScore DESC, FullName ASC;
END //

DELIMITER ;

-- Xem thống kê của sinh viên trong lớp có ID = 1 (Lớp DB-2025-01), lấy các bạn có ĐTB >= 0
CALL elearning.sp_GetStudentTestStatsByClass(1, 0);

-- Xem thống kê lớp ID = 1, chỉ lọc các bạn có ĐTB >= 5.0
CALL elearning.sp_GetStudentTestStatsByClass(1, 5.0);