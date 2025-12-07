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
};
const pictures = [_]JigsawPicture{
    .{ .name = "images/programming_master", .rows = 8, .cols = 8 },
};

pub fn init(ctx: jok.Context) !void {
    std.log.info("game init", .{});

    if (!builtin.cpu.arch.isWasm()) {
        try physfs.mount("assets", "", true);
    }

    // パズル画像からランダムなものを読み込む
    rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const pic = pictures[rng.random().uintLessThan(usize, pictures.len)];
    sheet = try j2d.SpriteSheet.fromPicturesInDir(
        ctx,
        pic.name,
        2560.0,
        1920.0,
        .{},
    );

    batchpool = try @TypeOf(batchpool).init(ctx);
    scene = try j2d.Scene.create(ctx.allocator());
}

pub fn event(ctx: jok.Context, e: jok.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: jok.Context) !void {
    _ = ctx;
}

pub fn draw(ctx: jok.Context) !void {
    _ = ctx;
}

pub fn quit(ctx: jok.Context) void {
    _ = ctx;
    sheet.destroy();
    batchpool.deinit();
    scene.destroy(true);
}
