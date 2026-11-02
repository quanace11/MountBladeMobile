// Cầu nối TikTok LIVE -> game Đấu Tướng.
// Đọc bình luận, quà, tim trong LIVE của bạn rồi gửi cho game qua WebSocket, mỗi sự kiện một dòng JSON:
//   {"type":"comment","user":"abc","nick":"Tên","text":"1"}
//   {"type":"gift","user":"abc","nick":"Tên","gift":"Rose","coins":1}
//   {"type":"like","user":"abc","nick":"Tên","count":15}
//   {"type":"status","text":"..."}
//
// Chạy:  node bridge.mjs <tên_tiktok>            (đang LIVE)
//        node bridge.mjs --fake                  (giả lập người xem, không cần TikTok)
// Tuỳ chọn: --port 21213, --sign-key <khoá Euler Stream> (hoặc biến môi trường TIKTOK_SIGN_API_KEY).

import os from 'node:os';
import { WebSocketServer } from 'ws';

const args = process.argv.slice(2);
const opt = (name, def) => {
    const i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : def;
};
const fake = args.includes('--fake');
const port = Number(opt('--port', process.env.BRIDGE_PORT || 21213));
const signKey = opt('--sign-key', process.env.TIKTOK_SIGN_API_KEY);
const WITH_VALUE = ['--port', '--sign-key'];
const username = args.find((a, i) => !a.startsWith('--') && !WITH_VALUE.includes(args[i - 1]))?.replace(/^@/, '');

if (!fake && !username) {
    console.log('Cách dùng: node bridge.mjs <tên_tiktok_đang_live>   hoặc   node bridge.mjs --fake');
    process.exit(1);
}

// ---------------------------------------------------------------- WebSocket cho game

const wss = new WebSocketServer({ host: '0.0.0.0', port });
let lastStatus = '';

function send(obj) {
    const line = JSON.stringify(obj);
    for (const c of wss.clients) {
        if (c.readyState === 1) c.send(line);
    }
}

function status(text) {
    lastStatus = text;
    console.log('[cầu nối] ' + text);
    send({ type: 'status', text });
}

wss.on('connection', (ws, req) => {
    console.log(`[cầu nối] Game đã nối từ ${req.socket.remoteAddress}`);
    if (lastStatus) ws.send(JSON.stringify({ type: 'status', text: lastStatus }));
});

const lan = Object.values(os.networkInterfaces()).flat()
    .filter(a => a && a.family === 'IPv4' && !a.internal).map(a => a.address);
console.log(`[cầu nối] Chờ game nối tới ws://127.0.0.1:${port}`);
for (const ip of lan) console.log(`[cầu nối] Chơi trên điện thoại cùng wifi: điền ws://${ip}:${port} trong menu game`);

// ---------------------------------------------------------------- TikTok LIVE

const who = d => ({ user: String(d?.user?.uniqueId ?? d?.uniqueId ?? ''), nick: String(d?.user?.nickname ?? d?.nickname ?? d?.user?.uniqueId ?? '') });

async function runTikTok() {
    const { TikTokLiveConnection, WebcastEvent, ControlEvent } = await import('tiktok-live-connector');
    const conn = new TikTokLiveConnection(username, {
        signApiKey: signKey || undefined,
        processInitialData: false,
        enableExtendedGiftInfo: true,
    });

    conn.on(WebcastEvent.CHAT, d => {
        send({ type: 'comment', ...who(d), text: String(d.comment ?? '') });
    });

    conn.on(WebcastEvent.GIFT, d => {
        // Quà tặng liên tiếp (combo, gift.type 1) gửi nhiều sự kiện với repeatCount tăng dần;
        // chỉ tính một lần khi combo kết thúc. Quà khác tính ngay.
        const type = d.gift?.type ?? d.giftDetails?.giftType ?? d.extendedGiftInfo?.type;
        if (type === 1 && !d.repeatEnd) return;
        const each = Number(d.gift?.diamondCount ?? d.extendedGiftInfo?.diamond_count ?? d.giftDetails?.diamondCount ?? d.diamondCount ?? 0);
        const count = Math.max(1, Number(d.repeatCount ?? 1));
        const name = String(d.gift?.name ?? d.extendedGiftInfo?.name ?? d.giftDetails?.giftName ?? d.giftName ?? `quà #${d.giftId}`);
        send({ type: 'gift', ...who(d), gift: count > 1 ? `${name} x${count}` : name, coins: each * count });
    });

    conn.on(WebcastEvent.LIKE, d => {
        send({ type: 'like', ...who(d), count: Number(d.count ?? d.likeCount ?? 1) });
    });

    conn.on(WebcastEvent.STREAM_END, () => status('LIVE đã kết thúc'));
    conn.on(ControlEvent.DISCONNECTED, () => {
        status('Mất kết nối TikTok, thử lại sau 15 giây');
        setTimeout(connect, 15000);
    });
    conn.on(ControlEvent.ERROR, err => console.error('[TikTok] lỗi:', err?.message ?? err));

    async function connect() {
        try {
            status(`Đang vào LIVE của @${username}...`);
            const st = await conn.connect();
            status(`Đã vào LIVE của @${username} (phòng ${st.roomId})`);
        } catch (err) {
            status(`Chưa vào được LIVE của @${username}: ${err?.message ?? err}. Thử lại sau 30 giây`);
            setTimeout(connect, 30000);
        }
    }
    connect();
}

// ---------------------------------------------------------------- Giả lập người xem

function runFake() {
    status('Giả lập người xem (không có TikTok)');
    const gifts = [['Hoa hồng', 1], ['Hoa hồng', 1], ['Kem', 1], ['Tim', 5], ['Mũ', 10], ['Bánh', 20], ['Sư tử', 299]];
    let n = 0;
    setInterval(() => {
        n++;
        const user = `nguoixem${1 + Math.floor(Math.random() * 40)}`;
        const r = Math.random();
        if (r < 0.35) send({ type: 'comment', user, nick: user, text: Math.random() < 0.5 ? '1' : '2' });
        else if (r < 0.55) {
            const [gift, coins] = gifts[Math.floor(Math.random() * gifts.length)];
            send({ type: 'gift', user, nick: user, gift, coins });
        } else if (r < 0.85) send({ type: 'like', user, nick: user, count: 1 + Math.floor(Math.random() * 15) });
        else send({ type: 'comment', user, nick: user, text: 'hay quá' });
    }, 1200);
}

if (fake) runFake();
else runTikTok().catch(err => {
    console.error('Không nạp được tiktok-live-connector. Chạy "npm install" trong thư mục tools/tiktok_bridge trước.', err?.message ?? err);
    process.exit(1);
});
