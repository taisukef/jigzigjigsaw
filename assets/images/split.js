import { ImageDataUtil } from "./ImageDataUtil.js";
import { EXT } from "https://code4fukui.github.io/EXT/EXT.js";

/*
    画像を縦 rows 行 × 横 cols 列に分割して保存する。
    画像サイズが rows, cols で割り切れない場合は Error を投げる。
*/
const splitImageGrid = async (imagePath, rows, cols) => {
  const ext = EXT.get(imagePath);
  const output_dir = imagePath.substring(0, imagePath.lastIndexOf("."));
  await Deno.mkdir(output_dir, { recursive: true });

  const bin = await Deno.readFile(imagePath);
  const img = ImageDataUtil.decodeImage(bin, ext);
  const { width, height } = img;
  
  if (width % cols != 0 || height % rows != 0) {
    throw new Error("画像サイズ ({width}x{height}) が cols={cols}, rows={rows} で割り切れない");
  }

  const tile_width = width / cols;
  const tile_height = height / rows;

  const fix2 = (n) => n < 10 ? "0" + n : n;
  for (let row = 0; row < rows; row++) {
    for (let col = 0; col < cols; col++) {
      const x = col * tile_width;
      const y = row * tile_height;
      const tile = ImageDataUtil.crop(img, x, y, tile_width, tile_height);
      
      const tile_filename = `r${fix2(row)}_c${fix2(col)}.${ext}`;
      const tile_path = output_dir + "/" + tile_filename;
      const bin = ImageDataUtil.encodeImage(tile, ext);
      await Deno.writeFile(tile_path, bin);
    }
  }
};

if (Deno.args.length < 3) {
  console.log("split.js [image] [rows] [cols]");
  console.log(`画像をrows行 x cols列に分割する。
分割された画像は、元画像から拡張子を取り除いた名前のフォルダに保存される。
元画像の縦幅がrowsで割り切れないか、横幅がcolsで割り切れない場合、エラー。`);
  Deno.exit(1);
}
const [fn, rows, cols] = Deno.args;
splitImageGrid(fn, rows, cols);
