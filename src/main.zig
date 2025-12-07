// 標準ライブラリとかのimport
const std = @import("std");
const builtin = @import("builtin");

// jokのimport
const jok = @import("jok");
const j2d = jok.j2d;
const physfs = jok.physfs;

var rng: std.Random.DefaultPrng = undefined; // 乱数生成器
var sheet: *j2d.SpriteSheet = undefined; // スプライト。使う画像をあらかじめ読み込んでおく
var batchpool: j2d.BatchPool(64, false) = undefined; // 描画を高速化するのに使うっぽい
var scene: *j2d.Scene = undefined; // 描画先

// ジグソーパズルとして分割する画像。
// 画像を追加するときはここを修正する。
const JigsawPicture = struct {
    name: [*:0]const u8,
    rows: u32,
    cols: u32,
    pieceWidth: u32,
    pieceHeight: u32,
};
const pictures = [_]JigsawPicture{
    .{
        .name = "images/programming_master",
        .rows = 8,
        .cols = 8,
        .pieceWidth = 128,
        .pieceHeight = 70,
    },
};

// パズルのピース
const Piece = struct {
    picture: *j2d.Scene.Object,
    currentPos: jok.Point,
    correctPos: jok.Point,
};

// ゲームの状態
const GamePhase = enum {
    initial,
    playing,
};
const GameState = struct {
    phase: GamePhase,
    picture: JigsawPicture,
    pieces: []Piece,
    draggingPieceIndex: ?usize,
};
var state = GameState{
    .phase = .initial,
    .picture = undefined,
    .pieces = &[_]Piece{},
    .draggingPieceIndex = null,
};

pub fn init(ctx: jok.Context) !void {
    std.log.info("game init", .{});
    try ctx.window().setTitle("じぐじぐじぐそー: クリックでゲームを開始します");

    if (!builtin.cpu.arch.isWasm()) {
        try physfs.mount("assets", "", true);
    }

    // パズル画像からランダムなものを読み込む
    rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const puzzlePic = pictures[rng.random().uintLessThan(usize, pictures.len)];
    sheet = try j2d.SpriteSheet.fromPicturesInDir(
        ctx,
        puzzlePic.name,
        2560.0,
        1920.0,
        .{},
    );
    state.picture = puzzlePic;

    batchpool = try @TypeOf(batchpool).init(ctx);
    scene = try j2d.Scene.create(ctx.allocator());

    const margin: u32 = 64;

    // 各ピースのスプライトから2Dオブジェクトを作り、正解の位置に移動する。
    state.pieces = try ctx.allocator().alloc(Piece, puzzlePic.rows * puzzlePic.cols);
    var r: u32 = 0;
    while (r < puzzlePic.rows) : (r += 1) {
        var c: u32 = 0;
        while (c < puzzlePic.cols) : (c += 1) {
            const filename = try std.fmt.allocPrint(ctx.allocator(), "r{d:0>2}_c{d:0>2}", .{ r, c });
            defer ctx.allocator().free(filename);
            const pos = jok.Point{
                .x = @floatFromInt(margin + c * puzzlePic.pieceWidth),
                .y = @floatFromInt(margin + r * puzzlePic.pieceHeight),
            };
            const obj = try j2d.Scene.Object.create(ctx.allocator(), .{
                .sprite = sheet.getSpriteByName(filename).?,
                .render_opt = .{ .pos = pos },
            }, null);
            const piece = Piece{
                .picture = obj,
                .currentPos = pos,
                .correctPos = pos,
            };
            const idx = r * puzzlePic.cols + c;
            state.pieces[idx] = piece;
            try scene.root.addChild(piece.picture);
        }
    }

    // パズル画像のサイズに合わせてウィンドウサイズを変更
    const window = ctx.window();
    try window.setSize(.{
        .width = margin * 2 + puzzlePic.pieceWidth * puzzlePic.cols,
        .height = margin * 2 + puzzlePic.pieceHeight * puzzlePic.rows,
    });
}

pub fn event(ctx: jok.Context, e: jok.Event) !void {
    switch (state.phase) {
        .initial => {
            switch (e) {
                .mouse_button_down => {
                    shufflePieces(ctx);
                    state.phase = .playing;
                    try ctx.window().setTitle("じぐじぐじぐそー: ピースをドラッグしてパズルを完成させよう！");
                },
                else => {},
            }
        },
        .playing => {
            switch (e) {
                .mouse_button_down => |m| {
                    if (state.draggingPieceIndex == null) {
                        if (findPieceIndexAt(m.pos)) |index| {
                            state.draggingPieceIndex = index;
                            movePieceCenterTo(index, m.pos);

                            // ドラッグ中のピースは一番上に描画されるようにする
                            state.pieces[index].picture.removeSelf();
                            try scene.root.addChild(state.pieces[index].picture);
                        }
                    }
                },
                .mouse_motion => |m| {
                    if (state.draggingPieceIndex) |index| {
                        movePieceCenterTo(index, m.pos);
                    }
                },
                .mouse_button_up => {
                    if (state.draggingPieceIndex != null) {
                        state.draggingPieceIndex = null;
                    }
                },
                else => {},
            }
        },
    }
}

fn shufflePieces(ctx: jok.Context) void {
    var i: u32 = 0;
    while (i < state.pieces.len) : (i += 1) {
        state.pieces[i].currentPos = jok.Point{
            .x = @floatFromInt(rng.random().intRangeAtMost(u32, 0, ctx.window().getSize().width - state.picture.pieceWidth)),
            .y = @floatFromInt(rng.random().intRangeAtMost(u32, 0, ctx.window().getSize().height - state.picture.pieceHeight)),
        };
    }
}

fn findPieceIndexAt(pos: jok.Point) ?usize {
    var i = state.pieces.len;
    while (i > 0) {
        i -= 1;
        var rect = jok.Rectangle{
            .x = state.pieces[i].currentPos.x,
            .y = state.pieces[i].currentPos.y,
            .width = @floatFromInt(state.picture.pieceWidth),
            .height = @floatFromInt(state.picture.pieceHeight),
        };
        if (rect.containsPoint(pos)) {
            return i;
        }
    }
    return null;
}

fn movePieceCenterTo(pieceIndex: usize, pos: jok.Point) void {
    state.pieces[pieceIndex].currentPos = .{
        .x = pos.x - @as(f32, @floatFromInt(state.picture.pieceWidth)) / 2.0,
        .y = pos.y - @as(f32, @floatFromInt(state.picture.pieceHeight)) / 2.0,
    };
}

pub fn update(ctx: jok.Context) !void {
    _ = ctx;
}

pub fn draw(ctx: jok.Context) !void {
    try ctx.renderer().clear(.rgb(128, 128, 128));
    var b = try batchpool.new(.{ .depth_sort = .back_to_forth });
    defer b.submit();

    // もとのピースの配置が分かるようにグリッドを表示
    for (state.pieces) |p| {
        const rect = jok.Rectangle{
            .x = p.correctPos.x,
            .y = p.correctPos.y,
            .width = @floatFromInt(state.picture.pieceWidth),
            .height = @floatFromInt(state.picture.pieceHeight),
        };
        const color = jok.Color{ .r = 240, .g = 240, .b = 240 };
        try b.rect(rect, color, .{});
    }

    // ピースの描画
    for (state.pieces) |p| {
        p.picture.setRenderOptions(.{
            .pos = p.currentPos,
        });
    }
    try b.scene(scene);
}

pub fn quit(ctx: jok.Context) void {
    sheet.destroy();
    batchpool.deinit();
    scene.destroy(true);
    ctx.allocator().free(state.pieces);
}
