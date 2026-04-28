DELIMITER //

DROP FUNCTION IF EXISTS fn_MaxScore_Student_Test //

#hàm tìm max score của 1 học sinh trong 1 bài test, nếu không có attempt nào trả về NULL
CREATE FUNCTION fn_MaxScore_Student_Test(p_student_id INT, p_test_id INT)
RETURNS DECIMAL(7,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_max_score DECIMAL(7,2) DEFAULT NULL;
    DECLARE v_current_score DECIMAL(7,2);
    DECLARE v_done INT DEFAULT 0;
    
    DECLARE cur_attempts CURSOR FOR
        SELECT score
        FROM Attempt
        WHERE student_id = p_student_id AND test_id = p_test_id;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    
    #kiểm tra tồn tại không
    IF p_student_id IS NULL OR p_student_id <= 0 OR p_test_id IS NULL OR p_test_id <= 0 THEN
        RETURN NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Student WHERE id = p_student_id) THEN
        RETURN NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Test WHERE test_id = p_test_id) THEN
        RETURN NULL;
    END IF;

    OPEN cur_attempts;
    
    #logic tìm max
    score_loop: LOOP
        FETCH cur_attempts INTO v_current_score;
        
        IF v_done = 1 THEN
            LEAVE score_loop;
        END IF;
        
        -- IF logic to find maximum score
        IF v_current_score IS NOT NULL THEN
            IF v_max_score IS NULL OR v_current_score > v_max_score THEN
                SET v_max_score = v_current_score;
            END IF;
        END IF;
        
    END LOOP score_loop;
    
    CLOSE cur_attempts;
    
    RETURN v_max_score;
END 

DELIMITER ;

-- Sample test queries
SELECT fn_MaxScore_Student_Test(1, 1) AS Max_Score_Student_1_Test_1;
SELECT fn_MaxScore_Student_Test(3, 2) AS Max_Score_Student_3_Test_2;
