# Đấu Tướng (Mount Blade Mobile)

Game đấu tướng 3D thời cổ cho điện thoại, đánh và đỡ theo 4 hướng kiểu Mount & Blade.
Bản này là **bản thử cảm giác đánh đỡ**: nhân vật dựng bằng khối hình có khớp tay chân (chưa phải model 3D thật),
đấu trường dùng texture và bầu trời thật từ Poly Haven (CC0, xem `assets/CREDITS.md`), chưa có âm thanh.

- Godot 4.6, GDScript, renderer Compatibility (nhẹ, chạy được trên nhiều máy Android).
- Chơi với bot: 1 vs 1 đến 1 vs 4, bot dễ hoặc khó.

## Chạy thử

1. Mở Godot 4.6, chọn *Import* và trỏ tới thư mục này.
2. Bấm Play. Trên PC dùng chuột như ngón tay, hoặc bàn phím:
   - `WASD`: đi.
   - Giữ `I` / `J` / `K` / `L`: gồng bổ trên / trái / đâm / phải; nhả phím để chém.
   - Giữ phím mũi tên: đỡ theo hướng đó.

## Điều khiển trên điện thoại

- **Tay trái**: joystick di chuyển. Nhân vật tự quay mặt về địch gần nhất; không có chọn mục tiêu.
  Di chuyển có quán tính, đi ngang và đi lùi chậm hơn đi thẳng, xoay người chậm lại khi đang chém (chỉnh trong `config/characters/`).
- **Tay phải**, chọn kiểu trong menu hoặc nút trên cùng khi đang đánh:
  - *Nút CHÉM + ĐỠ* (mặc định): giữ nút CHÉM và kéo theo hướng muốn chém (nhân vật giơ vũ khí lấy đà theo hướng đó), nhả tay để chém.
    Lên = bổ từ trên, xuống = đâm, trái/phải = chém ngang. Chạm nhanh nút CHÉM là chém ngang từ phải (đổi trong `config/input/touch.tres`).
    Giữ nút ĐỠ và kéo về phía đòn đang đến.
  - *Vuốt gấp khúc*: cả nửa phải màn hình là vùng vuốt. Kéo thẳng rồi nhả là chém; một nét có góc gấp `^` đỡ trên, `<` đỡ trái, `>` đỡ phải, `v` đỡ đâm. Giữ ngón tay là giữ thế đỡ.
- Đỡ về phía mình **thấy** vũ khí địch đang giơ. Game tự đổi hướng khi hai bên đối mặt
  (A chém từ bên phải của A thì B phải đỡ bên trái của B).
- Giơ đỡ đúng hướng sát lúc đòn tới là **đỡ hoàn hảo**: người chém bị khựng lâu.
- Đỡ tốn thể lực; hết thể lực thì bị phá thế. Đòn từ sau lưng hoặc bên sườn không đỡ được.
- Chém trúng địch đầu tiên trong tầm và cung chém; ngoài tầm thì hụt.

## Cấu trúc

```
config/            Toàn bộ số liệu (.tres, chỉnh trong Inspector của Godot)
  characters/      Tướng: máu, thể lực, tốc độ, vũ khí, màu áo
  weapons/         Đao, giáo, kiếm + khiên: tầm, sát thương, thời gian gồng/chém/thu
  ai/              Bot dễ / khó: phản xạ, tỉ lệ đỡ sai, đỡ hoàn hảo, đánh lừa
  matches/         Kịch bản 1v1 .. 1v4
  quality/         Preset đồ họa thấp / vừa / cao
  input/           Bố cục và ngưỡng cảm ứng
  visual/          Tư thế tay cầm vũ khí, đấu trường (texture, số nhà/cây/đá, hàng rào)
  combat_rules.tres, game_config.tres, audio.tres
src/
  core/            Autoload (ConfigDB, EventBus, Game), MatchRunner ghép các tầng, QualityManager
  data/            Class Resource mô tả dữ liệu config
  sim/             Logic thuần, không Node 3D: MatchSim, FighterSim, CombatResolver, FighterCommand
  input/           TouchController, GestureParser, KeyboardController, PlayerCommandSource
  ai/              BotBrain, AttackTokenManager (lượt tấn công khi 1 vs nhiều)
  view/            FighterView, CameraRig, VfxPool, ArenaBuilder
  audio/           AudioDirector
  ui/              Menu, HUD, lớp vẽ joystick/nút
  net/             CommandSource: chỗ cắm nguồn lệnh mạng khi làm PvP
assets/            texture, bầu trời, shader (giáp lá, nền, đồi, cờ, áo choàng)
scenes/            main_menu.tscn, match.tscn
tests/             Test tự động cho luật đánh đỡ và chạy thử cả game
```

Luồng dữ liệu một chiều: người chơi / bot tạo `FighterCommand` mỗi tick (30 tick/giây),
`MatchSim` cập nhật `MatchState` và trả về sự kiện, `MatchRunner` phát sự kiện qua `EventBus`
cho hình ảnh, âm thanh, UI. Không tầng nào ghi ngược vào sim.

## Test

```
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd     # luật đánh đỡ, vuốt, bot
godot --headless --path . -s tests/smoke_match.gd   # mở menu, vào trận 1 vs 3, chạy tới hết trận
```

## Xuất APK Android

Cần cài Android SDK, JDK 17 và export templates của Godot 4.6 (Editor > Manage Export Templates).
Sau đó Project > Export > Android (đã có sẵn preset, chỉ xuất arm64) > Export Project.

## Còn thiếu

- Model 3D và animation thật (đang dùng khối hình có khớp). Khi có model, chỉ cần thay `FighterView`;
  sim và config giữ nguyên.
- Âm thanh: khung `AudioDirector` đã nghe sự kiện, chỉ cần gán file vào `config/audio.tres`.
- Ánh sáng bake sẵn (LightmapGI) cho đấu trường.
