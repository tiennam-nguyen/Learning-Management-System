USE elearning;

DELIMITER //

DROP FUNCTION IF EXISTS fn_student_GPA_score //

-- ============================================================
-- HÀM: fn_student_GPA_score
-- MÔ TẢ: Tính điểm GPA của một sinh viên theo công thức:
--         GPA = SUM(max_score_trong_test * tín_chỉ_môn_học)
--               / SUM(tín_chỉ_môn_học)
--
--        Với mỗi bài test mà sinh viên có ít nhất 1 lần làm,
--        lấy điểm cao nhất (max score) nhân với số tín chỉ của
--        môn học tương ứng (qua chuỗi: Attempt → Test → Class → Subject).
--        Sau đó chia tổng tích đó cho tổng tín chỉ.
--
-- THAM SỐ: p_student_id INT  -- ID của sinh viên cần tính GPA
-- TRẢ VỀ:  DECIMAL(5,2)      -- Điểm GPA; NULL nếu input không hợp lệ
--                               hoặc sinh viên chưa làm bài thi nào
-- ============================================================
CREATE FUNCTION fn_student_GPA_score(p_student_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_test_id       INT;
    DECLARE v_credit        INT;
    DECLARE v_max_score     DECIMAL(7,2);

    DECLARE v_total_weighted DECIMAL(15,4) DEFAULT 0;
    DECLARE v_total_credit   INT           DEFAULT 0;

    DECLARE v_done INT DEFAULT 0;

    -- Cursor duyệt qua từng bài test (distinct) mà sinh viên đã có attempt,
    -- kèm theo số tín chỉ của môn học tương ứng.
    DECLARE cur_tests CURSOR FOR
        SELECT DISTINCT a.test_id, s.credit
        FROM Attempt a
        JOIN Test    t  ON a.test_id   = t.test_id
        JOIN Class   cl ON t.class_id  = cl.class_id
        JOIN Subject s  ON cl.subject_id = s.subject_id
        WHERE a.student_id = p_student_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    -- ── Kiểm tra tham số đầu vào ──────────────────────────────
    IF p_student_id IS NULL OR p_student_id <= 0 THEN
        RETURN NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Student WHERE id = p_student_id) THEN
        RETURN NULL;
    END IF;

    -- ── Duyệt từng test, tích lũy (max_score * credit) ────────
    OPEN cur_tests;

    test_loop: LOOP
        FETCH cur_tests INTO v_test_id, v_credit;

        IF v_done = 1 THEN
            LEAVE test_loop;
        END IF;

        -- Lấy điểm cao nhất của sinh viên trong bài test này
        SET v_max_score = fn_MaxScore_Student_Test(p_student_id, v_test_id);

        -- Chỉ tính những test mà sinh viên thực sự có điểm
        IF v_max_score IS NOT NULL THEN
            SET v_total_weighted = v_total_weighted + (v_max_score * v_credit);
            SET v_total_credit   = v_total_credit   + v_credit;
        END IF;

    END LOOP test_loop;

    CLOSE cur_tests;

    -- ── Tính GPA cuối ──────────────────────────────────────────
    IF v_total_credit = 0 THEN
        -- Sinh viên chưa có điểm hợp lệ nào
        RETURN NULL;
    END IF;

    RETURN ROUND(v_total_weighted / v_total_credit, 2);
END //

DELIMITER ;

-- ============================================================
-- KIỂM TRA
-- ============================================================
-- Tính GPA cho tất cả sinh viên
SELECT
    s.id              AS student_id,
    s.s_mssv          AS mssv,
    CONCAT(u.firstName, ' ', COALESCE(u.middleName, ''), ' ', u.lastName)
                      AS full_name,
    fn_student_GPA_score(s.id) AS GPA
FROM Student s
JOIN User u ON s.id = u.id
ORDER BY s.id;

-- Tính GPA cho sinh viên cụ thể (student_id = 1)
SELECT fn_student_GPA_score(1) AS GPA_student_1;
SELECT fn_student_GPA_score(3) AS GPA_student_3;
