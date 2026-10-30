# Đấu Tướng (Mount Blade Mobile)

Game đấu tướng 3D thời cổ cho điện thoại, đánh và đỡ theo 4 hướng kiểu Mount & Blade.
Bản này là **bản thử cảm giác đánh đỡ**: nhân vật dựng bằng khối hình có khớp tay chân (chưa phải model 3D thật),
đấu trường dùng texture và bầu trời thật từ Poly Haven (CC0, xem `assets/CREDITS.md`), âm thanh tạm tạo bằng code (tiếng binh khí va nhau, chém trúng, vung vũ khí).

- Godot 4.6, GDScript, renderer Compatibility (nhẹ, chạy được trên nhiều máy Android).
- Chơi với bot: 1 vs 1 đến 1 vs 4, bot dễ hoặc khó.

## Chạy thử

1. Mở Godot 4.6, chọn *Import* và trỏ tới thư mục này.
2. Bấm Play. Trên PC dùng chuột như ngón tay, hoặc bàn phím:
   - `WASD`: đi. `Space`: lăn né. `Q` / `E`: xoay người (hoặc kéo chuột ở nửa trên bên phải màn hình).
   - Giữ `I` / `J` / `K` / `L`: gồng bổ trên / trái / đâm / phải; nhả phím để chém.
   - Giữ phím mũi tên: đỡ theo hướng đó.

## Điều khiển trên điện thoại

- **Tay trái**: joystick di chuyển, theo hướng camera.
  Di chuyển có quán tính, đi ngang và đi lùi chậm hơn đi thẳng, xoay người chậm lại khi đang chém (chỉnh trong `config/characters/`).
- **Điều khiển**, chọn trong menu hoặc nút trên cùng khi đang đánh:
  1. *Tự xoay* (mặc định, như Bannerlord): kéo ngang chỗ trống bên phải màn hình để xoay camera, nhân vật quay theo
     hướng camera với tốc độ xoay có giới hạn. Chấm giữa màn hình là chỗ đang nhìn, chuyển đỏ khi có địch trong tầm chém.
  2. *Khoá địch gần*: nhân vật tự quay mặt về địch gần nhất, camera bám sau lưng. Bot luôn dùng kiểu này.
  3. *Tự chỉnh*: chọn hướng mặt, kiểu chém (nút CHÉM hoặc vuốt cả vùng như bản cũ), cách đỡ khi vuốt,
     trợ ngắm (đang chém thì tự quay nhẹ về địch gần tâm), độ nhạy xoay, khoảng cách camera, cỡ nút.
- **Tay phải**: nút **CHÉM** sát góc phải dưới: giữ và kéo về hướng muốn chém (nhân vật giơ vũ khí lấy đà theo hướng đó),
  nhả tay để chém; bấm không kéo là bổ. Lên = bổ từ trên, xuống = đâm, trái/phải = chém ngang.
  Nhả nút khi đang chém dở hoặc đang thu vũ khí thì game nhớ lệnh và chém tiếp ngay khi rảnh (chém liên hoàn).
- Nút **ĐỠ** bên trái nút CHÉM: giữ và kéo về phía đòn đang đến. Bật *Tự đỡ đúng hướng* trong *Tự chỉnh*
  (như "Block direction: Automatic" của Bannerlord) thì chỉ cần giữ, nhân vật tự đỡ về phía đòn đang tới.
  Vừa chém xong, hoặc vũ khí vừa bị đỡ dội lại, vẫn giơ đỡ được ngay; chỉ khi bị chém trúng mới phải chờ.
  Kiểu vuốt cả vùng (trong *Tự chỉnh*) đỡ bằng nút ĐỠ hoặc nét gấp khúc `^` `<` `>` `v`, giữ ngón tay là giữ thế đỡ.
- Đỡ về phía mình **thấy** vũ khí địch đang giơ. Game tự đổi hướng khi hai bên đối mặt
  (A chém từ bên phải của A thì B phải đỡ bên trái của B).
- Giơ đỡ đúng hướng sát lúc đòn tới là **đỡ hoàn hảo**: người chém bị khựng lâu.
- Đứng quá sát thì trúng cán, chuôi nên chỉ còn nửa sát thương; đúng tầm lưỡi mới đau nhất (điểm ngọt như M&B2).
- Như Mount & Blade 2, đánh cận chiến không tốn thể lực: chém, đỡ bao nhiêu cũng được, đỡ không bị phá thế.
  Muốn bật lại thể lực thì đặt `use_stamina = true` trong `config/combat_rules.tres`.
  Đòn từ sau lưng hoặc bên sườn không đỡ được.
- Chém trúng địch đầu tiên trong tầm và cung chém; ngoài tầm thì hụt.
- Bị chém trúng (như M&B2): người giật theo hướng lưỡi vũ khí, xô lùi nửa bước, máu phụt theo hướng chém và
  văng xuống đất, có tiếng rên. Người chơi trúng đòn thì viền màn hình chớp đỏ, máu thấp thì viền đỏ mờ luôn hiện.
- Chết: khuỵu gối rồi đổ theo hướng đòn, vũ khí văng khỏi tay, vũng máu loang dần, tiếng hét và tiếng thân ngã.
  Dòng báo kiểu Bannerlord: "Gây 36 sát thương." dưới thanh máu, "Bạn đã hạ ..." ở góc phải; bảng kết thúc
  hiện sau 2,5 giây cho thấy người cuối cùng ngã.
- Bị chém trúng khi đang gồng hoặc đang vung thì khựng và mất đòn (như Mount & Blade). Hai người chém trúng nhau
  cùng lúc thì cả hai đòn đều tính.
- Lao tới khi chém thì đòn mạnh hơn (tối đa ×1,35), vừa lùi vừa chém thì yếu hơn (tối thiểu ×0,8), như Mount & Blade.
- Bot đánh kiểu Mount & Blade: thấy bạn giơ đỡ thì chém vào phía không đỡ, chém ngay khi bạn hở (vừa chém hụt,
  đang khựng), chém xong lùi lại giữ khoảng cách. Đánh hội đồng: tối đa 2 bot ra đòn cùng lúc, và bot chỉ ra đòn khi
  không có ai đứng chắn giữa nó và bạn, nên đứng sao cho địch dồn thành một hàng là chỉ phải đỡ một người.
- Đỡ được thì có chớp sáng, tia lửa và tiếng binh khí va nhau; vũ khí người chém bị dội ngược lại.
  Bị chém trúng thì máu bắn, giáp chớp và tiếng phập.

## Model 3D

Tướng của người chơi dùng model `assets/models/tuongtrang/tuongtrang.scn` (khai báo ở `config/models/tuongtrang.tres`,
gắn vào `player_model` trong `config/game_config.tres`). Model cần khung xương chuẩn UE5 (`pelvis`, `spine_02..04`,
`upperarm_r`, `lowerarm_r`, `hand_r`, `thigh_l`, `calf_l`, `foot_l`...), không cần hoạt cảnh: `SkinnedRig` uốn xương
theo đúng các khớp mà thân dựng bằng khối đang dùng. Vũ khí, khiên vẫn dựng bằng khối. Ảnh màu và ảnh pháp tuyến
khai trong `albedo` / `normal` của file `.tres`; `height` là chiều cao model trong file để phóng cho cao 1,8 m.

Thêm model mới (xuất từ Character Creator: Target *Unreal (UE5 Skeleton)*, *Character only*, ảnh 2048, *Embed Texture*):
1. Chép file `.fbx` vào `assets/models/<tên>/`, mở Godot một lần để nhập (ảnh nhúng được tách ra `<tên>_0.png`, `_1.png`).
2. Gói thành cảnh gọn: `godot --headless --path . -s tools/pack_model.gd -- res://assets/models/<tên>/<tên>.fbx res://assets/models/<tên>/<tên>.scn`
   (bỏ hình biến dạng mặt và hoạt cảnh, tạo lại LOD; file fbx 58 MB còn 1,5 MB). File `.fbx` gốc không đưa lên repo.
3. Tạo `config/models/<tên>.tres` như `tuongtrang.tres` và trỏ `player_model` tới nó.

Model cũ `tuong` (Tripo) vẫn còn: bản rig mất ảnh màu nên `tools/bake_textured_model.gd` ghép lưới có ảnh
(`tuongdau.fbx`) vào khung xương của bản rig thành `tuong_textured.scn`.

## Cấu trúc

```
config/            Toàn bộ số liệu (.tres, chỉnh trong Inspector của Godot)
  characters/      Tướng: máu, thể lực, tốc độ, vũ khí, màu áo
  weapons/         Đao, giáo, kiếm + khiên: tầm, sát thương, thời gian gồng/chém/thu
  ai/              Bot dễ / khó: phản xạ, tỉ lệ đỡ sai, đỡ hoàn hảo, đánh lừa
  matches/         Kịch bản 1v1 .. 1v4
  quality/         Preset đồ họa thấp / vừa / cao
  input/           Bố cục và ngưỡng cảm ứng
  visual/          Tư thế tay cầm vũ khí, đấu trường (texture, số nhà/cây/đá; bãi không rào, rộng bán kính 60 m)
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

## Cài thử trên điện thoại (không cần gỡ lỗi USB)

Mỗi lần push, GitHub Actions (`.github/workflows/build.yml`) tự build:

- **APK**: trang [Releases](https://github.com/quanace11/MountBladeMobile/releases), mỗi nhánh một bản thử
  (`build-main`, `build-<tên nhánh>`). Mở bằng trình duyệt trên điện thoại, tải `DauTuong.apk`, cho phép
  "Cài ứng dụng không rõ nguồn gốc" cho trình duyệt rồi cài. Không cần bật chế độ nhà phát triển.
- **Web** (nhánh main): https://quanace11.github.io/MountBladeMobile/ , mở thẳng trên trình duyệt điện thoại.
  Cần bật một lần: *Settings > Pages > Source: GitHub Actions*.

APK được ký bằng khóa debug cố định trong `.github/android/debug.keystore`, nên bản mới cài đè lên bản cũ được.

## Xuất APK Android

Cần cài Android SDK, JDK 17 và export templates của Godot 4.6 (Editor > Manage Export Templates).
Sau đó Project > Export > Android (đã có sẵn preset, chỉ xuất arm64) > Export Project.

## Còn thiếu

- Model 3D và animation thật (đang dùng khối hình có khớp). Khi có model, chỉ cần thay `FighterView`;
  sim và config giữ nguyên.
- Âm thanh: khung `AudioDirector` đã nghe sự kiện, chỉ cần gán file vào `config/audio.tres`.
- Ánh sáng bake sẵn (LightmapGI) cho đấu trường.
