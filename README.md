# 📘 Hệ thống Quản lý Học tập (E-Learning Management System)
**Bài tập lớn số 2 - Môn Hệ Cơ sở dữ liệu**

Dự án này là một ứng dụng web mô phỏng hệ thống E-learning, cho phép quản lý khóa học, sinh viên, giảng viên và các hoạt động tương tác trong lớp học. 

---

## 🛠 Công nghệ sử dụng (Tech Stack)
* **Backend:** Python (Flask Framework).
* **Database:** MySQL 8.4 LTS.
* **Frontend:** HTML5, CSS3, JavaScript.
* **Thư viện kết nối:** `mysql-connector-python`, `python-dotenv`.

---

## 📂 Cấu trúc thư mục (Project Structure)
```text
Learning-Management-System/
├── database/               # Chứa các file script SQL (Bảng, Data, Trigger, Procedure, Function)
├── static/                 # Chứa CSS, JS, hình ảnh (Frontend)
├── templates/              # Chứa các file giao diện HTML (Frontend)
├── venv/                   # Môi trường ảo Python (Đã ignore)
├── .env                    # Cấu hình biến môi trường kết nối DB (Đã ignore)
├── .gitignore              # Chặn các file rác đẩy lên Git
├── app.py                  # File chạy chính của ứng dụng (Backend)
└── requirements.txt        # Danh sách các thư viện Python cần cài đặt
```

---

## 🚀 Hướng dẫn thiết lập (Setup Instructions)

### 1. Chuẩn bị Cơ sở dữ liệu (MySQL)
Để ứng dụng hoạt động chính xác và không gặp lỗi thiếu tham chiếu, Cơ sở dữ liệu cần được thiết lập theo đúng thứ tự.
1. Cài đặt **MySQL Server 8.4 LTS**.
2. Sử dụng MySQL Workbench hoặc Extension trên VS Code để kết nối.
3. Tạo database mới bằng lệnh: `CREATE DATABASE elearning;` và chọn DB đó: `USE elearning;`.
4. **Thực thi các script SQL trong thư mục `database/` theo ĐÚNG THỨ TỰ sau** *(có thể thêm dòng `USE elearning;` lên đầu mỗi file nếu cần)*:
   - **Bước 1 - Khởi tạo:** Chạy file `elearning.sql` (Tạo khung xương các bảng và chèn dữ liệu mẫu).
   - **Bước 2 - Tạo Hàm (Functions):** Chạy lần lượt các file `elearning_function.sql`, `function_gpa.sql`, và `Function_2.4.1.sql`.
   - **Bước 3 - Tạo Thủ tục (Procedures):** Chạy lần lượt các file `Procedures_Users_2_1.sql` và `Procedures_Cau2_3.sql`.
   - **Bước 4 - Tạo Trigger:** Chạy file `Triggers_DerivedAttr_2_2_2.sql`.

### 2. Thiết lập môi trường Python
1. **Clone dự án:**
```bash
git clone [https://github.com/tiennam-nguyen/Learning-Management-System.git](https://github.com/tiennam-nguyen/Learning-Management-System.git)
cd Learning-Management-System
```
2. **Tạo môi trường ảo:** `python -m venv venv`.
3. **Kích hoạt môi trường ảo:**
   * **Windows:** `venv\Scripts\activate`
   * **Mac/Linux:** `source venv/bin/activate`
4. **Cài đặt thư viện:** `pip install -r requirements.txt`.

### 3. Cấu hình biến môi trường (.env)
Tạo file `.env` tại thư mục gốc và nhập thông tin kết nối MySQL của riêng bạn (file này tuyệt đối không đẩy lên Git):
```env
DB_HOST=127.0.0.1
DB_USER=root
DB_PASSWORD=mật_khẩu_của_bạn
DB_NAME=elearning
```

### 4. Khởi chạy ứng dụng
Chạy lệnh sau trong Terminal:
```bash
python app.py
```
Mở trình duyệt và truy cập `http://127.0.0.1:5000` để trải nghiệm ứng dụng.

---

## 👥 Phân công nhiệm vụ (Nhóm 7 - Lớp L03)
* **Lê Nam Tiến (2413472):** Database Core (Thiết kế Schema, ràng buộc, dữ liệu mẫu và nhóm Trigger nghiệp vụ).
* **Nguyễn Phạm Phương Toàn (2413534):** Stored Procedures & Trigger (Thủ tục CRUD cho User và Trigger tính thuộc tính dẫn xuất).
* **Ngô Quý Chính (2410405):** Logic & UI (Function tính toán và Giao diện web danh sách thống kê, xử lý lỗi update/delete).
* **Nguyễn Tiến Nam (2412188):** Query, UI & Code Management (Thủ tục truy vấn phức tạp, Giao diện tương tác và quản lý source code GitHub).
* **Nguyễn Quang Bảo (2410276):** Logic & UI (Function tính điểm/tham số và Giao diện quản lý chương, bài học, tài liệu của Giảng viên).

---

## ⚠️ Lưu ý quan trọng
* **Validate dữ liệu:** Ứng dụng tích hợp kiểm tra tính hợp lệ ở cả Frontend lẫn Backend, mọi thủ tục Thêm/Sửa/Xóa đều ném lỗi (SIGNAL SQLSTATE) cụ thể từ Database lên UI.
* **Logic Data:** Hệ thống ưu tiên xử lý dữ liệu trực tiếp bằng cách gọi các Procedure/Function và Trigger từ Database thay vì xử lý thô ở Python.
