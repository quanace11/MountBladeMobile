# Cầu nối TikTok LIVE

Chương trình nhỏ chạy trên máy tính: vào LIVE TikTok của bạn, đọc **bình luận, quà, tim** rồi gửi cho game
Đấu Tướng qua WebSocket. Game không tự nối thẳng tới TikTok được, nên cần cầu nối này.

Dùng thư viện không chính thức [tiktok-live-connector](https://github.com/zerodytrash/TikTok-Live-Connector)
(không phải API chính thức của TikTok, TikTok đổi gì thì có thể phải cập nhật thư viện).

## Cài

1. Cài [Node.js](https://nodejs.org) bản 18 trở lên.
2. Mở terminal trong thư mục này rồi chạy `npm install`.

## Chạy

```
node bridge.mjs ten_tiktok_cua_ban
```

Phải đang LIVE thì mới vào được. Chưa LIVE thì cầu nối cứ 30 giây thử lại một lần.

Sau đó mở game, mục **TIKTOK LIVE** trong menu, bấm **VÀO LIVE**.

- Game chạy trên **cùng máy tính** (LIVE bằng TikTok LIVE Studio): để địa chỉ mặc định `ws://127.0.0.1:21213`.
- Game chạy trên **điện thoại**: điện thoại và máy tính cùng wifi, điền địa chỉ cầu nối in ra lúc chạy,
  ví dụ `ws://192.168.1.10:21213`.

Thử không cần TikTok: `node bridge.mjs --fake` giả lập người xem bình luận, tặng quà, thả tim.
Hoặc trong trận bấm phím 1-6 (xem bên dưới).

### Tuỳ chọn

- `--port 21213`: đổi cổng.
- `--sign-key <khoá>` (hoặc biến môi trường `TIKTOK_SIGN_API_KEY`): thư viện dùng máy chủ ký của
  [Euler Stream](https://www.eulerstream.com) để vào LIVE. Không có khoá vẫn chạy được nhưng bị giới hạn số lần,
  nếu hay báo lỗi khi vào LIVE thì tạo khoá miễn phí ở trang đó.

## Luật trong game

- Bình luận `1` (hoặc `xanh`): vào phe **Xanh**, phe của bạn. Bình luận `2` (hoặc `do`, `đỏ`): vào phe **Đỏ**.
  Vào phe là được một lính yếu, xếp cuối hàng chờ.
- **Quà** tính theo xu (số kim cương của quà x số lần tặng liên tiếp). Quà nhiều xu xếp lên đầu hàng.
  Mỗi phe tối đa 3 lính trên sân; quà từ 10 xu ra trận ngay (tối đa 6 lính); từ 10 xu là Lính tinh, từ 100 xu là Tướng.
  Tặng quà mà chưa chọn phe thì vào phe đang ít người hơn.
- **Tim** hồi máu cho bạn: 10 tim = 3 máu, mỗi giây hồi tối đa 4 máu.
- Bạn chết thì phe Đỏ thắng ván, hạ **Tướng Đỏ** thì phe Xanh thắng. Hiện bảng điểm 8 giây rồi sang ván mới.

Mọi con số trên chỉnh trong `config/live.tres`.

### Phím thử trên PC (trong trận LIVE)

`1` / `2`: người xem giả vào phe Xanh / Đỏ. `3` / `4` / `5`: quà 1 / 10 / 100 xu cho phe Đỏ (giữ Shift: phe Xanh).
`6`: 20 tim.
