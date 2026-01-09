import { JPEG } from "https://code4fukui.github.io/JPEG/JPEG.js";
import { PNG } from "https://code4fukui.github.io/PNG/PNG.js";

export class ImageDataUtil {
  static crop(img, x, y, w, h) {
    const data = new Uint8Array(w * h * 4);
    const res = {
      width: w,
      height: h,
      data,
    };
    for (let i = 0; i < h; i++) {
      for (let j = 0; j < w; j++) {
        const src = (x + j + (y + i) * img.width) * 4;
        const dst = (j + i * res.width) * 4;
        for (let k = 0; k < 4; k++) res.data[dst + k] = img.data[src + k];
      }
    }
    return res;
  }
  static decodeImage(bin) {
    try {
      return PNG.decode(bin);
    } catch (e) {
      return JPEG.decode(bin);
    }
  }
  static encodeImage(imgd, ext) {
    if (ext == "jpg") {
      return JPEG.encode(imgd);
    } else if (ext == "png") {
      return PNG.encode(imgd);
    }
  }  
};

