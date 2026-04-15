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
├── database/               # Chứa các file script SQL
│   ├── elearning.sql       # Script khởi tạo bảng và dữ liệu mẫu
│   └── queries_tv3.sql     # Các Procedure của Thành viên 3
├── static/                 # Chứa CSS, JS, hình ảnh (Frontend)
├── templates/              # Chứa các file giao diện HTML (Frontend)
├── venv/                   # Môi trường ảo Python (Đã ignore)
├── .env                    # Cấu hình bí mật cá nhân (Đã ignore)
├── .gitignore              # Chặn các file rác đẩy lên Git
├── app.py                  # File chạy chính của ứng dụng (Backend)
└── requirements.txt        # Danh sách các thư viện cần cài đặt
```

---

## 🚀 Hướng dẫn thiết lập (Setup Instructions)

### 1. Chuẩn bị Cơ sở dữ liệu (MySQL)
1. Cài đặt **MySQL Server 8.4 LTS**.
2. Sử dụng MySQL Workbench hoặc Extension trên VS Code để kết nối.
3. Tạo database mới: `CREATE DATABASE elearning;`.
4. Mở file `database/elearning.sql`, thêm dòng `USE elearning;` lên đầu và thực thi (Execute) để khởi tạo bảng.
   *(Lưu ý: Bảng phải có sẵn dữ liệu mẫu trước khi chạy ứng dụng).*

### 2. Thiết lập môi trường Python
1. **Clone dự án:** `git clone https://github.com/tiennam-nguyen/Learning-Management-System.git`.
2. **Tạo môi trường ảo:** `python -m venv venv`.
3. **Kích hoạt môi trường ảo:**
   * Windows: `venv\Scripts\activate`
   * Mac/Linux: `source venv/bin/activate`
4. **Cài đặt thư viện:** `pip install -r requirements.txt`.

### 3. Cấu hình biến môi trường (.env)
Tạo file `.env` tại thư mục gốc và nhập thông tin MySQL của riêng bạn (file này tuyệt đối không đẩy lên Git):
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
Mở trình duyệt và truy cập `http://127.0.0.1:5000` để xem kết quả.

---

## 🧬 Quy trình làm việc với Git (Branching Strategy)
Để tránh xung đột code, nhóm thống nhất làm việc trên các nhánh (branch) riêng:
1. **Cập nhật code mới:** `git pull origin main`.
2. **Tạo nhánh tính năng:** `git checkout -b feat/ten-chuc-nang-ten-sv`.
3. **Làm việc & Commit:** `git add .` -> `git commit -m "Mô tả công việc"`.
4. **Push nhánh lên GitHub:** `git push origin feat/ten-chuc-nang-ten-sv`.
5. **Tạo Pull Request:** Yêu cầu Thành viên 3 kiểm tra trước khi gộp vào `main`.

---

## 👥 Phân công nhiệm vụ (Tasks Allocation)
* **Thành viên 1:** Database Core (Thiết lập bảng, ràng buộc, dữ liệu mẫu).
* **Thành viên 2:** CRUD Master (Thủ tục Thêm/Sửa/Xóa và Trigger dẫn xuất).
* **Thành viên 3:** Query & UI (Thủ tục truy vấn phức tạp, quản lý Repo).
* **Thành viên 4:** Logic & UI (Hàm tính toán, giao diện Thêm/Sửa/Xóa).
* **Thành viên 5:** Logic & UI (Hàm tính toán, giao diện danh sách tìm kiếm).

---

## ⚠️ Lưu ý quan trọng
* **Validate dữ liệu:** Mọi thủ tục Thêm/Sửa/Xóa phải kiểm tra tính hợp lệ và xuất thông báo lỗi cụ thể.
* **Kết nối CSDL:** Ứng dụng phải thực sự gọi các Procedure/Function từ Database.
* **Hạn chót báo cáo:** Chủ nhật 23/11/2025 (Tuần chẵn) hoặc 07/12/2025 (Tuần lẻ).

---
*Dự án được thực hiện bởi Nhóm 7 - Lớp L03.*
